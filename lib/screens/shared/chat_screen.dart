import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/words.dart';
import '../../models/models.dart';
import '../../services/chat_repo.dart';
import '../../state/chat_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/ui.dart';

/// The farm's own room.
///
/// The four of them run this place between them and until now every word
/// about it was in a WhatsApp group, mixed in with everything else. A figure
/// argued over on Tuesday is unfindable by Friday. This room holds farm talk
/// only, it sits next to the books it is about, and nothing said in it can
/// be edited or taken back afterwards — which is the same rule the ledger
/// runs on, and for the same reason.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.active = true});

  /// True while this is the tab on screen. The room is listened to all the
  /// time so the dot can appear, but nothing counts as read until the
  /// person is actually looking at it.
  final bool active;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _field = TextEditingController();
  final _focus = FocusNode();

  /// Who has been called out in what is currently typed, by id. Kept beside
  /// the text rather than parsed out of it at send time, because two people
  /// on a farm can be called Ahmed.
  final _tagged = <String, String>{};

  bool _sending = false;

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// The fragment being typed after an `@`, or null if the cursor is not in
  /// one. `@ra` while writing "ask @ra" is a fragment; "@Rafeeq said" is not,
  /// because the space ended it.
  String? get _fragment {
    final sel = _field.selection;
    if (!sel.isValid || !sel.isCollapsed) return null;
    final upto = _field.text.substring(0, sel.baseOffset);
    final at = upto.lastIndexOf('@');
    if (at < 0) return null;
    final frag = upto.substring(at + 1);
    if (frag.contains(' ') || frag.contains('\n')) return null;
    return frag;
  }

  void _put(FarmPerson who) {
    final sel = _field.selection;
    final upto = _field.text.substring(0, sel.baseOffset);
    final at = upto.lastIndexOf('@');
    if (at < 0) return;
    final rest = _field.text.substring(sel.baseOffset);
    final tag = '@${who.name} ';
    _tagged[who.name] = who.uid;
    _field.value = TextEditingValue(
      text: _field.text.substring(0, at) + tag + rest,
      selection: TextSelection.collapsed(offset: at + tag.length),
    );
    setState(() {});
    _focus.requestFocus();
  }

  Future<void> _send() async {
    final text = _field.text.trim();
    if (text.isEmpty || _sending) return;
    final session = context.read<Session>();

    // Only the names still standing in the text count. Tag somebody, change
    // your mind and delete it, and they should not be pinged.
    final mentions = [
      for (final e in _tagged.entries)
        if (text.contains('@${e.key}')) e.value,
    ];

    setState(() => _sending = true);
    _field.clear();
    _tagged.clear();
    try {
      await ChatRepo.say(by: session.actor, text: text, mentions: mentions);
    } catch (e) {
      if (mounted) {
        toast(context, 'Could not send that. $e');
        _field.text = text;
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final session = context.watch<Session>();
    final store = context.watch<ChatStore>();
    final me = session.user;
    final people = session.settings.founders
        .where((p) => p.uid != me?.uid)
        .toList();

    // Looking at the room is what marks it read. Done here rather than on
    // open, so a line that arrives while you are sitting on the tab does
    // not leave a dot behind when you walk away.
    if (widget.active && me != null && !store.loading) {
      final unread = store.unreadFor(me.uid, me.chatSeenAt);
      if (unread > 0) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => ChatRepo.markSeen(me.uid),
        );
      }
    }

    final frag = _fragment;
    final matches = frag == null
        ? const <FarmPerson>[]
        : people
              .where((p) => p.name.toLowerCase().contains(frag.toLowerCase()))
              .toList();

    return Column(
      children: [
        Expanded(
          child: store.error != null
              ? _Trouble(detail: store.error!)
              : store.loading
              ? const Center(child: CircularProgressIndicator())
              : store.messages.isEmpty
              ? _Empty(l: l)
              : ListView.builder(
                  // Built upside down: a chat is read from the bottom, and
                  // this way it opens there without a scroll jump.
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(T.pad, T.gap, T.pad, 6),
                  itemCount: store.messages.length,
                  itemBuilder: (_, i) {
                    final m = store.messages[i];
                    // Newest first in the list, so "the one before this" is
                    // the next index along.
                    final older = i + 1 < store.messages.length
                        ? store.messages[i + 1]
                        : null;
                    return _Line(
                      msg: m,
                      mine: m.byUid == (me?.uid ?? ''),
                      forMe: me != null && m.mentionsMe(me.uid),
                      names: people.map((p) => p.name).toList(),
                      showDay: older == null || !_sameDay(older.at, m.at),
                    );
                  },
                ),
        ),

        if (matches.isNotEmpty) _Mentions(people: matches, onPick: _put),

        _Composer(
          field: _field,
          focus: _focus,
          sending: _sending,
          onSend: _send,
          onChanged: (_) => setState(() {}),
          hint: l.t('Say something to the others'),
        ),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// One line said, with the day's date above it when the day changes.
class _Line extends StatelessWidget {
  const _Line({
    required this.msg,
    required this.mine,
    required this.forMe,
    required this.names,
    required this.showDay,
  });

  final ChatMsg msg;
  final bool mine;

  /// This line called me out by name — it gets an edge so it is findable
  /// scrolling back.
  final bool forMe;

  final List<String> names;
  final bool showDay;

  @override
  Widget build(BuildContext context) {
    final bubble = mine ? T.accent200 : T.surface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDay)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: T.raised,
                  borderRadius: BorderRadius.circular(T.pill),
                ),
                child: Text(fmtDateFull(msg.at), style: T.kicker),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            mainAxisAlignment: mine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(11, 8, 11, 7),
                  decoration: BoxDecoration(
                    color: bubble,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(T.radiusSm),
                      topRight: const Radius.circular(T.radiusSm),
                      bottomLeft: Radius.circular(mine ? T.radiusSm : 3),
                      bottomRight: Radius.circular(mine ? 3 : T.radiusSm),
                    ),
                    border: forMe
                        ? Border.all(color: T.accent, width: 1.4)
                        : Border.all(color: T.divider, width: 1),
                    boxShadow: T.shadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!mine)
                        Text(
                          msg.byName,
                          style: T.kicker.copyWith(color: T.accent700),
                        ),
                      if (!mine) const SizedBox(height: 2),
                      _Said(text: msg.text, names: names),
                      const SizedBox(height: 3),
                      Text(
                        fmtClock(msg.at),
                        style: T.meta.copyWith(fontSize: 10, color: T.n500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The words, with any `@Name` in them picked out.
///
/// Matched against the farm's list of people rather than against "@ up to
/// the next space", so an email address or a price written with an @ is
/// left as plain writing.
class _Said extends StatelessWidget {
  const _Said({required this.text, required this.names});

  final String text;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    var i = 0;

    // Longest first, so "@Ahmed Raza" is not cut short by "@Ahmed".
    final tags = [...names]..sort((a, b) => b.length.compareTo(a.length));

    while (i < text.length) {
      var hit = -1;
      var who = '';
      for (final n in tags) {
        final at = text.indexOf('@$n', i);
        if (at >= 0 && (hit < 0 || at < hit)) {
          hit = at;
          who = n;
        }
      }
      if (hit < 0) {
        spans.add(TextSpan(text: text.substring(i)));
        break;
      }
      if (hit > i) spans.add(TextSpan(text: text.substring(i, hit)));
      spans.add(
        TextSpan(
          text: '@$who',
          style: TextStyle(color: T.accent700, fontWeight: FontWeight.w600),
        ),
      );
      i = hit + who.length + 1;
    }

    return RichText(
      text: TextSpan(style: T.body.copyWith(fontSize: 14.5), children: spans),
    );
  }
}

/// The list that drops up when an `@` is being typed.
class _Mentions extends StatelessWidget {
  const _Mentions({required this.people, required this.onPick});

  final List<FarmPerson> people;
  final ValueChanged<FarmPerson> onPick;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxHeight: 190),
    decoration: BoxDecoration(
      color: T.surface,
      border: Border(top: BorderSide(color: T.divider)),
      boxShadow: T.shadow,
    ),
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        for (final p in people)
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: T.accent200,
              child: Text(
                p.name.isEmpty ? '?' : p.name.characters.first.toUpperCase(),
                style: T.bodyMid.copyWith(
                  fontSize: 12,
                  color: T.inkOn(T.accent200),
                ),
              ),
            ),
            title: Text(p.name, style: T.bodyMid),
            onTap: () => onPick(p),
          ),
      ],
    ),
  );
}

/// The box you type in, and the one round button beside it.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.field,
    required this.focus,
    required this.sending,
    required this.onSend,
    required this.onChanged,
    required this.hint,
  });

  final TextEditingController field;
  final FocusNode focus;
  final bool sending;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: T.surface,
      border: Border(top: BorderSide(color: T.divider)),
    ),
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
    child: SafeArea(
      top: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: T.raised,
                borderRadius: BorderRadius.circular(T.pill),
                border: Border.all(color: T.divider),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: field,
                focusNode: focus,
                onChanged: onChanged,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: T.body.copyWith(fontSize: 14.5),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  hintText: hint,
                  hintStyle: T.body.copyWith(color: T.n500),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Round, raised, and the one strong colour on the screen — the
          // same object as every other button in the app, only circular.
          SizedBox(
            width: 46,
            child: Pressable(
              height: 46,
              radius: 23,
              onTap: sending ? null : onSend,
              gradient: T.cta,
              child: sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward_rounded,
                      size: 21,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.l});

  final L l;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 40, color: T.n400),
          const SizedBox(height: 12),
          Text(
            l.t('Nothing said here yet.'),
            style: T.cardTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            l.t(
              'This room is only for the people who run the farm. Write a '
              'name with an @ in front of it to call somebody out.',
            ),
            style: T.meta,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _Trouble extends StatelessWidget {
  const _Trouble({required this.detail});

  final String detail;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 36, color: T.n400),
          const SizedBox(height: 12),
          Text('The room did not open', style: T.cardTitle),
          const SizedBox(height: 6),
          Text(
            'This is nearly always the database rules not being published '
            'yet. The chat needs its own rule added.',
            style: T.meta,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            detail,
            style: T.meta.copyWith(fontSize: 10.5, color: T.n500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
