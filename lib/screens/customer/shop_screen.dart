import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/cart.dart';
import '../../state/customer_store.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../util/money.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/ui.dart';
import '../shared/products_screen.dart' show ProductPhoto;

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key, required this.onGoToCart});

  final VoidCallback onGoToCart;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CustomerStore>();
    final cart = context.watch<Cart>();
    final user = context.watch<Session>().user;
    final products = store.products;

    return PageBody(
      children: [
        if (user != null && !user.canOrder) ...[
          RegCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(child: Kicker('Your account')),
                    Tag('Pending', tone: TagTone.warn),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Have a look around. The farm master approves new accounts '
                  'before the first order can be placed.',
                  style: T.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: T.gap),
        ],

        _UdhaarBanner(store: store),
        const SizedBox(height: T.pad),

        if (products.isEmpty)
          const EmptyNote('The shop is empty right now. Please check back.')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: T.gap,
              mainAxisSpacing: T.gap,
              mainAxisExtent: 250,
            ),
            itemCount: products.length,
            itemBuilder: (_, i) => _ProductTile(product: products[i]),
          ),

        if (!cart.isEmpty) ...[
          const SizedBox(height: T.pad),
          PrimaryButton(
            label: 'Go to checkout · ${rs(cart.total(products))}',
            onPressed: onGoToCart,
          ),
        ],
      ],
    );
  }
}

/// Udhaar state banner at the top of the shop.
class _UdhaarBanner extends StatelessWidget {
  const _UdhaarBanner({required this.store});

  final CustomerStore store;

  @override
  Widget build(BuildContext context) {
    final u = store.udhaar;
    final (tone, body) = switch (store.udhaarStatus) {
      UdhaarStatus.approved => (
        TagTone.good,
        'You owe ${rs(u?.balance ?? 0)} of your ${rs(u?.limit ?? 0)} limit. '
            'Billed when the farm closes the month.',
      ),
      UdhaarStatus.pending => (
        TagTone.warn,
        'Your request is with the co-founders. Pay cash or bank transfer until '
            'it is approved.',
      ),
      UdhaarStatus.rejected => (
        TagTone.bad,
        'Monthly credit was not approved. You can still order and pay on '
            'delivery.',
      ),
      UdhaarStatus.none => (
        TagTone.neutral,
        'Buy through the month and settle one bill at month end. Open the '
            'Udhaar tab to register.',
      ),
    };

    return RegCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Kicker('Monthly udhaar')),
              Tag(store.udhaarStatus.label, tone: tone),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: T.body),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    final qtyInCart = cart.qtyOf(product.id);

    return RegCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: LayoutBuilder(
              builder: (_, c) => ProductPhoto(
                url: product.photoUrl,
                width: c.maxWidth,
                height: c.maxHeight,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.name,
            style: T.cardTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text('${rs(product.price)} / ${product.unit}', style: T.meta),
          const Spacer(),
          Row(
            children: [
              _Step(
                icon: Icons.remove,
                onTap: qtyInCart > 0
                    ? () => context.read<Cart>().remove(product)
                    : null,
              ),
              Expanded(
                child: Center(
                  child: Text(qty(qtyInCart), style: T.bodyMid),
                ),
              ),
              _Step(
                icon: Icons.add,
                onTap: () => context.read<Cart>().add(product),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 44 px tap target — the prototype's 32 px steppers are too small on a phone.
class _Step extends StatelessWidget {
  const _Step({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      width: T.tap,
      height: T.tap,
      alignment: Alignment.center,
      decoration: BoxDecoration(border: T.hair),
      child: Icon(icon, size: 18, color: onTap == null ? T.n400 : T.accent700),
    ),
  );
}
