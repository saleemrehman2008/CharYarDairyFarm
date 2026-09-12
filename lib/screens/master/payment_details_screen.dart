import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/db.dart';
import '../../services/log_service.dart';
import '../../services/photo_store.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/photo.dart';
import '../../widgets/ui.dart';

/// Where a customer paying by transfer should send the money.
///
/// A bank account typed wrong sends somebody's money to a stranger, so this
/// is one of the few places worth a QR: the customer scans it instead of
/// copying digits. The QR itself has to come from the bank or the wallet —
/// no app can invent a valid one.
class PaymentDetailsScreen extends StatefulWidget {
  const PaymentDetailsScreen({super.key});

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  late final _bank = TextEditingController();
  late final _jazz = TextEditingController();
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _bank.dispose();
    _jazz.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await Db.farmSettings.set({
        'bankAccount': _bank.text.trim(),
        'jazzcashNumber': _jazz.text.trim(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      await Log.write(
        context.read<Session>().actor,
        LogKind.user,
        'updated the farm\'s payment details',
      );
      if (mounted) toast(context, 'Saved');
    } catch (e) {
      if (mounted) toast(context, 'Could not save it. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickQr() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final photo = await Photos.prepare(File(picked.path));
      await Db.farmSettings.set({
        'bankQr': photo.full,
      }, SetOptions(merge: true));
      if (mounted) toast(context, 'QR saved');
    } catch (e) {
      if (mounted) toast(context, 'Could not save the QR. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearQr() async {
    final ok = await confirm(
      context,
      title: 'Remove the QR?',
      body: 'Customers will see the account number only.',
      confirmLabel: 'Remove',
    );
    if (!ok || !mounted) return;
    await Db.farmSettings.set({'bankQr': ''}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FarmStore>().settings;
    if (!_loaded) {
      _bank.text = settings.bankAccount;
      _jazz.text = settings.jazzcashNumber;
      _loaded = true;
    }

    return FarmScaffold(
      title: 'Payment details',
      showBack: true,
      body: PageBody(
        children: [
          Text(
            'What a customer sees when they choose bank transfer or JazzCash '
            'at checkout. Leave a field empty and that way of paying tells '
            'them to ring the farm instead.',
            style: T.meta,
          ),
          const SizedBox(height: 14),

          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Field(
                  label: 'Bank account',
                  controller: _bank,
                  hint: 'Title, bank and number, as you want it read',
                  maxLines: 2,
                ),
                const SizedBox(height: T.gap),
                Field(
                  label: 'JazzCash / EasyPaisa number',
                  controller: _jazz,
                  keyboardType: TextInputType.phone,
                  hint: '03XX XXXXXXX',
                ),
                const SizedBox(height: 16),
                PrimaryButton(label: 'Save', busy: _busy, onPressed: _save),
              ],
            ),
          ),
          const SizedBox(height: T.pad),

          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Kicker('QR code'),
                const SizedBox(height: 6),
                Text(
                  'Take the QR out of your bank or JazzCash app and put the '
                  'picture here. A scanned code cannot be mistyped, which is '
                  'the whole point of it.',
                  style: T.meta,
                ),
                const SizedBox(height: 12),
                if (settings.bankQr.isNotEmpty)
                  Center(child: FarmPhotoView(data: settings.bankQr, size: 190))
                else
                  Center(child: FarmPhotoView(data: '', size: 120)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GhostButton(
                        label: settings.bankQr.isEmpty
                            ? 'Add the QR'
                            : 'Replace it',
                        icon: Icons.qr_code_2,
                        onPressed: _busy ? null : _pickQr,
                      ),
                    ),
                    if (settings.bankQr.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      GhostButton(
                        label: 'Remove',
                        compact: true,
                        danger: true,
                        onPressed: _busy ? null : _clearQr,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
