// `Field` is hidden because cloud_firestore exports one of its own, and this
// screen wants the app's text field.
import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/db.dart';
import '../../services/log_service.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';

/// Who gets in as what, decided before they ever open the app.
///
/// An email listed here takes its role the moment that person signs in with
/// Google — nobody has to be watching for them, and no password is created,
/// stored or passed along. Everyone else arrives as a customer.
class TeamAccessScreen extends StatelessWidget {
  const TeamAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FarmStore>().settings;

    return FarmScaffold(
      title: 'Team access',
      showBack: true,
      body: PageBody(
        children: [
          Text(
            'Put someone\'s Gmail here and they arrive in the right place the '
            'first time they sign in. Anyone not listed is a customer.',
            style: T.meta,
          ),
          const SizedBox(height: T.pad),
          _EmailList(
            title: 'Co-founders',
            note: 'Full access to the books, approvals and month close.',
            field: 'autoCofounderEmails',
            emails: settings.cofounderEmails,
          ),
          const SizedBox(height: T.pad),
          _EmailList(
            title: 'Delivery staff',
            note:
                'The daily round, orders to drop off, and money collected. '
                'They cannot see the farm\'s accounts at all.',
            field: 'staffEmails',
            emails: settings.staffEmails,
          ),
          const SizedBox(height: T.pad),
          Text(
            'Removing an email does not remove the person — it only stops the '
            'next new sign-in taking that role. Change or block an existing '
            'account from Users & roles.',
            style: T.meta,
          ),
        ],
      ),
    );
  }
}

class _EmailList extends StatefulWidget {
  const _EmailList({
    required this.title,
    required this.note,
    required this.field,
    required this.emails,
  });

  final String title;
  final String note;
  final String field;
  final List<String> emails;

  @override
  State<_EmailList> createState() => _EmailListState();
}

class _EmailListState extends State<_EmailList> {
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final email = _email.text.trim().toLowerCase();
    if (!email.contains('@') || !email.contains('.')) {
      toast(context, 'That does not look like an email address.');
      return;
    }
    if (widget.emails.contains(email)) {
      toast(context, 'Already on the list.');
      return;
    }
    await _write(FieldValue.arrayUnion([email]), 'added $email to');
    _email.clear();
  }

  Future<void> _remove(String email) async {
    await _write(FieldValue.arrayRemove([email]), 'removed $email from');
  }

  Future<void> _write(FieldValue change, String what) async {
    final actor = context.read<Session>().actor;
    setState(() => _busy = true);
    try {
      await Db.farmSettings.set({
        widget.field: change,
      }, SetOptions(merge: true));
      await Log.write(
        actor,
        LogKind.user,
        '$what the ${widget.title.toLowerCase()} list',
      );
      if (mounted) toast(context, 'Saved');
    } catch (e) {
      if (mounted) toast(context, 'Could not save it. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => RegCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kicker(widget.title),
        const SizedBox(height: 6),
        Text(widget.note, style: T.meta),
        const SizedBox(height: 12),
        if (widget.emails.isEmpty)
          Text('Nobody listed yet.', style: T.meta)
        else
          for (final email in widget.emails)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: T.divider, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      email,
                      style: T.body,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : () => _remove(email),
                    icon: Icon(Icons.close, size: 16, color: T.n500),
                    tooltip: 'Remove',
                  ),
                ],
              ),
            ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Field(
                label: 'Add an email',
                controller: _email,
                hint: 'name@gmail.com',
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
              ),
            ),
            const SizedBox(width: 8),
            GhostButton(
              label: 'Add',
              icon: Icons.add,
              onPressed: _busy ? null : _add,
            ),
          ],
        ),
      ],
    ),
  );
}
