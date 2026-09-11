import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/user_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';

/// Master only: who may use the app, and as what.
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final users = context.watch<FarmStore>().users;

    return FarmScaffold(
      title: 'Users & roles',
      showBack: true,
      body: PageBody(
        children: [
          Text(
            'New Google sign-ins arrive as pending customers. Approve them to '
            'let them order, or make them a co-founder.',
            style: T.meta,
          ),
          const SizedBox(height: 14),
          if (users.isEmpty)
            const EmptyNote('No accounts yet.')
          else
            for (final u in users) _UserCard(key: ValueKey(u.uid), user: u),
        ],
      ),
    );
  }
}

class _UserCard extends StatefulWidget {
  const _UserCard({super.key, required this.user});

  final AppUser user;

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) toast(context, done);
    } catch (e) {
      if (mounted) toast(context, 'Could not do that. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final actor = context.read<Session>().actor;
    final isSelf = u.uid == actor.uid;
    final blocked = u.status == UserStatus.blocked;

    return Padding(
      padding: const EdgeInsets.only(bottom: T.gap),
      child: RegCard(
        dim: blocked,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.name,
                        style: T.cardTitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        u.email,
                        style: T.meta,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Tag(u.status.label, tone: _statusTone(u.status)),
              ],
            ),
            const SizedBox(height: 12),

            // The master's own role is not editable from here.
            if (u.role == Role.master || isSelf)
              Tag(u.role.label, tone: TagTone.accent)
            else
              Picker<Role>(
                label: 'Role',
                value: u.role == Role.investor ? Role.investor : Role.customer,
                items: const [
                  (Role.investor, 'Co-founder'),
                  (Role.customer, 'Customer'),
                ],
                onChanged: _busy
                    ? (_) {}
                    : (role) => _run(
                        () => UserRepo.setRole(actor, u, role),
                        '${u.name} is now a ${role.label.toLowerCase()}',
                      ),
              ),

            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (u.status == UserStatus.pending)
                  GhostButton(
                    label: 'Approve',
                    icon: Icons.check,
                    compact: true,
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => UserRepo.approve(actor, u),
                            '${u.name} approved',
                          ),
                  ),
                if (!isSelf && u.role != Role.master)
                  GhostButton(
                    label: blocked ? 'Unblock' : 'Block',
                    compact: true,
                    danger: !blocked,
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => UserRepo.setBlocked(
                              actor,
                              u,
                              blocked: !blocked,
                            ),
                            blocked
                                ? '${u.name} unblocked'
                                : '${u.name} blocked',
                          ),
                  ),
                GhostButton(
                  label: 'Reset',
                  compact: true,
                  onPressed: _busy || u.email.isEmpty
                      ? null
                      : () => _run(
                          () => UserRepo.sendReset(actor, u),
                          'Sign-in link sent to ${u.email}',
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static TagTone _statusTone(UserStatus s) => switch (s) {
    UserStatus.active => TagTone.good,
    UserStatus.pending => TagTone.warn,
    UserStatus.blocked => TagTone.bad,
  };
}
