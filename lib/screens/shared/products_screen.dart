import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/product_repo.dart';
import '../../state/farm_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/photo.dart';
import '../../widgets/ui.dart';

/// Rates and the shop catalogue. Every change is logged and synced.
class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key, this.asSubScreen = false});

  final bool asSubScreen;

  @override
  Widget build(BuildContext context) {
    const body = _ProductsBody();
    if (!asSubScreen) return body;
    return FarmScaffold(title: 'Products & rates', showBack: true, body: body);
  }
}

class _ProductsBody extends StatelessWidget {
  const _ProductsBody();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final products = store.shopProducts;

    return PageBody(
      children: [
        Text(
          'The rate you set here is what customers pay in the shop.',
          style: T.meta,
        ),
        const SizedBox(height: 14),
        if (products.isEmpty)
          const EmptyNote('No items in the shop yet. Add the first one below.')
        else
          for (final p in products)
            _ProductRow(key: ValueKey(p.id), product: p),
        const SizedBox(height: T.pad),
        const _AddItemCard(),
      ],
    );
  }
}

class _ProductRow extends StatefulWidget {
  const _ProductRow({super.key, required this.product});

  final Product product;

  @override
  State<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends State<_ProductRow> {
  late final _rate = TextEditingController(
    text: widget.product.price.round().toString(),
  );
  bool _busy = false;

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  Future<void> _saveRate() async {
    final price = num.tryParse(_rate.text.trim());
    if (price == null || price <= 0) {
      _rate.text = widget.product.price.round().toString();
      toast(context, 'A rate cannot be left empty — put the old one back.');
      return;
    }
    if (price == widget.product.price) return;
    try {
      await ProductRepo.setPrice(
        context.read<Session>().actor,
        widget.product,
        price,
      );
      if (mounted) {
        toast(context, '${widget.product.name} now ${rs(price)}');
      }
    } catch (e) {
      if (mounted) toast(context, 'Could not save the rate. $e');
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 82,
    );
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ProductRepo.uploadPhoto(
        context.read<Session>().actor,
        widget.product,
        File(picked.path),
      );
      if (mounted) toast(context, 'Photo updated');
    } catch (e) {
      if (mounted) toast(context, 'Could not upload the photo. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final ok = await confirm(
      context,
      title: 'Remove ${widget.product.name}?',
      body: 'It disappears from the shop. Past orders keep their record.',
      confirmLabel: 'Remove',
    );
    if (!ok || !mounted) return;
    try {
      await ProductRepo.remove(context.read<Session>().actor, widget.product);
      if (mounted) toast(context, '${widget.product.name} removed');
    } catch (e) {
      if (mounted) toast(context, 'Could not remove it. $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Padding(
      padding: const EdgeInsets.only(bottom: T.gap),
      child: RegCard(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _busy ? null : _pickPhoto,
              child: FarmPhotoView(data: p.photo, url: p.photoUrl, size: 88),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: T.cardTitle),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 96,
                        child: TextField(
                          controller: _rate,
                          keyboardType: TextInputType.number,
                          style: T.body,
                          onSubmitted: (_) => _saveRate(),
                          onTapOutside: (_) {
                            FocusScope.of(context).unfocus();
                            _saveRate();
                          },
                          decoration: const InputDecoration(prefixText: 'Rs '),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('/ ${p.unit}', style: T.meta),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GhostButton(
                    label: 'Remove',
                    compact: true,
                    danger: true,
                    onPressed: _remove,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddItemCard extends StatefulWidget {
  const _AddItemCard();

  @override
  State<_AddItemCard> createState() => _AddItemCardState();
}

class _AddItemCardState extends State<_AddItemCard> {
  final _name = TextEditingController();
  final _rate = TextEditingController();
  String _unit = Product.units.first;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    final price = num.tryParse(_rate.text.trim()) ?? 0;
    if (name.isEmpty || price <= 0) {
      toast(context, 'Add a name and a rate.');
      return;
    }
    final store = context.read<FarmStore>();
    setState(() => _busy = true);
    try {
      await ProductRepo.add(
        context.read<Session>().actor,
        name: name,
        price: price,
        unit: _unit,
        sortOrder: store.allProducts.length + 1,
      );
      _name.clear();
      _rate.clear();
      if (mounted) toast(context, '$name added to the shop');
    } catch (e) {
      if (mounted) toast(context, 'Could not add it. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => RegCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Kicker('Add item'),
        const SizedBox(height: 10),
        Field(label: 'Name', controller: _name, hint: 'Fresh milk'),
        const SizedBox(height: T.gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Field(
                label: 'Rate (Rs)',
                controller: _rate,
                keyboardType: TextInputType.number,
                hint: '0',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Picker<String>(
                label: 'Unit',
                value: _unit,
                items: [for (final u in Product.units) (u, u)],
                onChanged: (v) => setState(() => _unit = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        PrimaryButton(label: 'Add to shop', busy: _busy, onPressed: _add),
      ],
    ),
  );
}
