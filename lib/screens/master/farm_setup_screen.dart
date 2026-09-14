import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../services/links.dart';
import '../../services/sheet_sync.dart';
import '../../services/log_service.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';

/// Which parts of the farm are running. Master only.
///
/// Switching something off is not a permission change and not a delete: the
/// tab disappears from every phone on the farm — customer, rider and
/// co-founder alike — the notifications stop, and every record stays exactly
/// where it is. Switching it back on brings it all back untouched.
class FarmSetupScreen extends StatefulWidget {
  const FarmSetupScreen({super.key});

  @override
  State<FarmSetupScreen> createState() => _FarmSetupScreenState();
}

class _FarmSetupScreenState extends State<FarmSetupScreen> {
  bool _busy = false;

  Future<void> _set(Feature feature, bool on, Features current) async {
    final l = L.read(context);
    final session = context.read<Session>();

    // Switching a delivery channel off takes the rider with it if nothing is
    // left to deliver, which is a bigger change than the switch looks. Say so
    // before doing it rather than letting the round vanish unannounced.
    final next = current.with_(feature, on);
    if (!on && current.rider && !next.riderPossible) {
      final ok = await confirm(
        context,
        title: l.t('Switch the round off too?'),
        body: l.t(
          'With neither online orders nor khaata running there is nothing for '
          'the rider to take out, so the round, spot sales, the handover and '
          'the collection screens all go with it.\n\nNothing is deleted. It '
          'all comes back when you switch a delivery channel on again.',
        ),
        confirmLabel: l.t('Switch off'),
      );
      if (!ok) return;
    }

    setState(() => _busy = true);
    try {
      await Db.farmSettings.set({
        'features': next.ids,
        'featuresChangedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await Log.write(
        session.actor,
        LogKind.settings,
        '${on ? 'switched on' : 'switched off'} ${feature.id}',
        refType: 'settings',
        refId: 'farm',
      );
    } catch (e) {
      if (mounted) toast(context, l.t2('Could not save that. %s', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final f = context.watch<Session>().features;

    return FarmScaffold(
      title: l.t('What the farm runs'),
      showBack: true,
      body: PageBody(
        children: [
          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(l.t('Selling')),
                const SizedBox(height: 10),
                SwitchRow(
                  title: l.t('Online orders'),
                  note: l.t('Shop, cart, and orders going out to doors'),
                  value: f.orders,
                  enabled: !_busy,
                  onChanged: (v) => _set(Feature.orders, v, f),
                ),
                const Divider(height: 22),
                SwitchRow(
                  title: l.t('Khaata'),
                  note: l.t('Daily milk on account, billed once a month'),
                  value: f.khaata,
                  enabled: !_busy,
                  onChanged: (v) => _set(Feature.khaata, v, f),
                ),
              ],
            ),
          ),
          const SizedBox(height: T.gap),

          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(l.t('Out on the round')),
                const SizedBox(height: 10),
                SwitchRow(
                  title: l.t("The rider's work"),
                  note: l.t('Round, spot sale, handover, collection'),
                  value: f.rider,
                  enabled: !_busy && f.riderPossible,
                  why: l.t(
                    'Online orders and khaata are both off, so there is '
                    'nothing for a rider to take out. Switch one of them on '
                    'and this comes back by itself.',
                  ),
                  onChanged: (v) => _set(Feature.rider, v, f),
                ),
              ],
            ),
          ),
          const SizedBox(height: T.gap),

          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(l.t('The farm itself')),
                const SizedBox(height: 10),
                SwitchRow(
                  title: l.t('Cattle register'),
                  note: l.t('Animals, tags, milk yield, vet visits'),
                  value: f.cattle,
                  enabled: !_busy,
                  onChanged: (v) => _set(Feature.cattle, v, f),
                ),
                const Divider(height: 22),
                SwitchRow(
                  title: l.t('Books'),
                  note: l.t('Entries, accounts, reports, closing a period'),
                  value: true,
                  enabled: false,
                  why: l.t(
                    'The books always run. Everything else can be switched '
                    'off; the farm still has to know what it has.',
                  ),
                  onChanged: null,
                ),
              ],
            ),
          ),
          const SizedBox(height: T.gap),

          const _SheetCard(),
          const SizedBox(height: T.gap),

          RegCard(
            wash: T.accent100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.t('What switching off does'), style: T.cardTitle),
                const SizedBox(height: 8),
                Text(
                  l.t(
                    'The tab disappears from every phone on the farm and the '
                    'notifications stop. Nothing is deleted — every khaata, '
                    'order and bill stays exactly where it is, and comes back '
                    'untouched when you switch it on again.',
                  ),
                  style: T.body,
                ),
                const SizedBox(height: 8),
                Text(
                  l.t(
                    'Only you can see this screen. Co-founders, riders and '
                    'customers have no such setting.',
                  ),
                  style: T.meta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Google Sheet the farm's books are mirrored into.
///
/// Two things have to be true for it to work: the app has to know which sheet,
/// and Google has to have been asked once for permission to write to it. Both
/// are done here, and after that nobody presses anything again — the Sheet
/// keeps up with the app on its own.
class _SheetCard extends StatefulWidget {
  const _SheetCard();

  @override
  State<_SheetCard> createState() => _SheetCardState();
}

class _SheetCardState extends State<_SheetCard> {
  final _link = TextEditingController();
  bool _busy = false;
  bool? _allowed;

  @override
  void initState() {
    super.initState();
    SheetSync.authorised.then((ok) {
      if (mounted) setState(() => _allowed = ok);
    });
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  /// The id out of a pasted link, or out of a pasted id.
  ///
  /// A share link looks like
  /// `https://docs.google.com/spreadsheets/d/<id>/edit?usp=sharing`, and
  /// nobody should have to pick the middle out of that by hand.
  static String? _idFrom(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    final match = RegExp(r'/d/([a-zA-Z0-9-_]{20,})').firstMatch(text);
    if (match != null) return match.group(1);
    // Pasted on its own.
    if (RegExp(r'^[a-zA-Z0-9-_]{20,}$').hasMatch(text)) return text;
    return null;
  }

  Future<void> _saveLink() async {
    final l = L.read(context);
    final id = _idFrom(_link.text);
    if (id == null) {
      toast(context, l.t('That does not look like a Google Sheet link.'));
      return;
    }

    setState(() => _busy = true);
    try {
      await Db.farmSettings.set({
        'sheetId': id,
        'lastSyncAt': FieldValue.delete(),
      }, SetOptions(merge: true));
      _link.clear();
      if (mounted) toast(context, l.t('Sheet linked.'));
    } catch (e) {
      if (mounted) toast(context, l.t2('Could not save that. %s', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _allow() async {
    final l = L.read(context);
    setState(() => _busy = true);
    try {
      final ok = await SheetSync.requestAccess();
      if (!mounted) return;
      setState(() => _allowed = ok);
      toast(
        context,
        ok
            ? l.t('Allowed. The Sheet will keep up on its own now.')
            : l.t2('Google did not allow it. %s', SheetSync.lastError ?? ''),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow() async {
    final l = L.read(context);
    final store = context.read<FarmStore>();
    setState(() => _busy = true);
    try {
      final ok = await SheetSync.push(await store.sheetBooks(), force: true);
      if (!mounted) return;
      toast(
        context,
        ok
            ? l.t('Written to the Sheet.')
            : l.t2('Could not write. %s', SheetSync.lastError ?? ''),
      );
    } catch (e) {
      if (mounted) toast(context, l.t2('Could not write. %s', e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final settings = context.watch<Session>().settings;
    final linked = settings.sheetId.isNotEmpty;
    final synced = settings.lastSyncAt;

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Kicker(l.t('Google Sheet'))),
              Tag(
                !linked
                    ? l.t('not linked')
                    : _allowed == false
                    ? l.t('needs permission')
                    : synced == null
                    ? l.t('waiting')
                    : l.t('live'),
                tone: !linked || _allowed == false
                    ? TagTone.warn
                    : synced == null
                    ? TagTone.neutral
                    : TagTone.good,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l.t(
              'A second copy of the books, kept up to date by itself. Every '
              'change in the app reaches the Sheet a few seconds later — '
              'there is nothing to press.',
            ),
            style: T.body,
          ),
          const SizedBox(height: 12),

          if (!linked) ...[
            Field(
              label: l.t('Paste the sheet link'),
              controller: _link,
              hint: 'https://docs.google.com/spreadsheets/d/…',
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: l.t('Link this sheet'),
              icon: Icons.link,
              busy: _busy,
              onPressed: _saveLink,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    synced == null
                        ? l.t('Nothing written to it yet.')
                        : l.t2('Last written %s', fmtStamp(synced)),
                    style: T.meta,
                  ),
                ),
                GhostButton(
                  label: l.t('Open'),
                  icon: Icons.open_in_new,
                  compact: true,
                  onPressed: () => Links.open(settings.sheetUrl),
                ),
              ],
            ),
            if (settings.syncError.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(settings.syncError, style: T.meta.copyWith(color: T.alert)),
            ],
            const SizedBox(height: 12),
            if (_allowed == false)
              PrimaryButton(
                label: l.t('Allow the app to write to it'),
                icon: Icons.lock_open,
                busy: _busy,
                onPressed: _allow,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: GhostButton(
                      label: l.t('Write it now'),
                      icon: Icons.sync,
                      onPressed: _busy ? null : _syncNow,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GhostButton(
                      label: l.t('Use another sheet'),
                      danger: true,
                      onPressed: _busy
                          ? null
                          : () async {
                              await Db.farmSettings.set({
                                'sheetId': '',
                              }, SetOptions(merge: true));
                            },
                    ),
                  ),
                ],
              ),
          ],

          const SizedBox(height: 12),
          Text(
            l.t(
              'The Sheet needs to be shared so that anyone with the link can '
              'edit it. The app writes its own tabs — Summary, Entries, '
              'Periods, Co-founders, Khaata, Deliveries, Cattle — and rewrites '
              'them each time. Any other tab you build is left alone.',
            ),
            style: T.meta,
          ),
        ],
      ),
    );
  }
}
