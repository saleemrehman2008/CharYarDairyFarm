import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/farm_store.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/photo.dart';
import '../../widgets/ui.dart';
import 'animal_form.dart';
import 'animal_screen.dart';

/// The cattle register: every animal the farm owns, by tag.
///
/// Master and co-founders only. It is a list of assets and of the money spent
/// keeping them alive, which is nobody else's business.
class CattleScreen extends StatefulWidget {
  const CattleScreen({super.key});

  @override
  State<CattleScreen> createState() => _CattleScreenState();
}

class _CattleScreenState extends State<CattleScreen> {
  Species? _species;
  bool _showGone = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final all = store.animals;

    final shown =
        all
            .where((a) => _showGone ? !a.status.isHere : a.status.isHere)
            .where((a) => _species == null || a.species == _species)
            .toList()
          ..sort(Animal.byTag);

    final counts = <Species, int>{};
    for (final a in store.herd) {
      counts[a.species] = (counts[a.species] ?? 0) + 1;
    }

    return FarmScaffold(
      title: 'Cattle register',
      showBack: true,
      floating: FloatingActionButton.extended(
        onPressed: () => _open(context, store, const AnimalFormScreen()),
        backgroundColor: T.accent700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add animal'),
      ),
      body: PageBody(
        padBottom: 90,
        children: [
          _HerdCard(store: store, counts: counts),

          if (store.dueChecks.isNotEmpty) ...[
            const SizedBox(height: T.pad),
            _DueCard(
              animals: store.dueChecks,
              onTap: (a) => _open(context, store, AnimalScreen(animal: a)),
            ),
          ],

          const SizedBox(height: 18),
          Segmented<bool>(
            value: _showGone,
            compact: true,
            options: const [(false, 'On the farm'), (true, 'Gone')],
            onChanged: (v) => setState(() => _showGone = v),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Chip(
                  label: 'All',
                  on: _species == null,
                  onTap: () => setState(() => _species = null),
                ),
                for (final s in Species.values)
                  if (all.any((a) => a.species == s))
                    _Chip(
                      label:
                          '${s.label}${counts[s] == null ? '' : ' ${counts[s]}'}',
                      on: _species == s,
                      onTap: () => setState(() => _species = s),
                    ),
              ],
            ),
          ),
          const SizedBox(height: T.pad),

          if (shown.isEmpty)
            EmptyNote(
              _showGone
                  ? 'Nothing has left the farm.'
                  : 'No animals registered yet. Add the first one.',
            )
          else
            for (final a in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: T.gap),
                child: _AnimalRow(
                  animal: a,
                  onTap: () => _open(context, store, AnimalScreen(animal: a)),
                ),
              ),
        ],
      ),
    );
  }

  void _open(BuildContext context, FarmStore store, Widget screen) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider<FarmStore>.value(
            value: store,
            child: screen,
          ),
        ),
      );
}

class _HerdCard extends StatelessWidget {
  const _HerdCard({required this.store, required this.counts});

  final FarmStore store;
  final Map<Species, int> counts;

  @override
  Widget build(BuildContext context) => RegCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Kicker('On the farm'),
        const SizedBox(height: 6),
        Text('${store.herd.length}', style: T.num30),
        const SizedBox(height: 4),
        Text(
          counts.isEmpty
              ? 'Nothing registered yet'
              : [
                  for (final e in counts.entries)
                    '${e.value} ${e.key.label.toLowerCase()}'
                        '${e.value == 1 ? '' : 's'}',
                ].join(' · '),
          style: T.meta,
        ),
        if (store.milkingCount > 0) ...[
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Text(
            '${store.milkingCount} milking · '
            '${qty(store.herdLitresPerDay)} L a day',
            style: T.bodyMid,
          ),
          const SizedBox(height: 2),
          Text(
            'From the last reading taken for each animal. Add a milk reading '
            'on an animal to keep this honest.',
            style: T.meta,
          ),
        ],
      ],
    ),
  );
}

/// Vaccinations and checks that have come round.
class _DueCard extends StatelessWidget {
  const _DueCard({required this.animals, required this.onTap});

  final List<Animal> animals;
  final ValueChanged<Animal> onTap;

  @override
  Widget build(BuildContext context) => RegCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Kicker('Coming due')),
            Tag('${animals.length}', tone: TagTone.warn),
          ],
        ),
        const SizedBox(height: 8),
        for (final a in animals)
          InkWell(
            onTap: () => onTap(a),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${a.label} · ${a.nextDueWhat ?? 'Check'}',
                      style: T.body,
                    ),
                  ),
                  Text(
                    fmtDate(a.nextDueOn!),
                    style: T.meta.copyWith(
                      color: a.overdue() ? T.alert : T.n600,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: T.n500),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _AnimalRow extends StatelessWidget {
  const _AnimalRow({required this.animal, required this.onTap});

  final Animal animal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => RegCard(
    padding: const EdgeInsets.all(10),
    onTap: onTap,
    dim: !animal.status.isHere,
    child: Row(
      children: [
        FarmPhotoView(data: animal.thumb, url: animal.photoUrl, size: 62),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(animal.tag, style: T.cardTitle),
                  if (animal.name.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        animal.name,
                        style: T.body,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Spacer(),
                  if (!animal.status.isHere)
                    Tag(animal.status.label, tone: TagTone.neutral)
                  else if (animal.overdue())
                    const Tag('Check due', tone: TagTone.bad)
                  else if (animal.isMilking)
                    Tag('${qty(animal.dailyLitres)} L', tone: TagTone.good),
                ],
              ),
              const SizedBox(height: 3),
              Text(animal.summary, style: T.meta),
              if (animal.motherTag != null)
                Text('Out of ${animal.motherTag}', style: T.meta),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, size: 18, color: T.n500),
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: on ? T.accent700 : Colors.transparent,
          border: Border.all(color: on ? T.accent700 : T.divider),
        ),
        child: Text(
          label,
          style: T.meta.copyWith(color: on ? Colors.white : T.n700),
        ),
      ),
    ),
  );
}
