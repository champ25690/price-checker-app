import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../utils/image_utils.dart';
import '../theme.dart';
import 'promo_badge.dart';

class ProductListTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductListTile({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: context.appCard,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // รูปสินค้า
            _thumb(context),
            const SizedBox(width: 12),
            // ชื่อ + SKU + badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.appTextPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(product.sku,
                      style: TextStyle(fontSize: 13, color: context.appTextHint)),
                  if (product.promotion != null) ...[
                    const SizedBox(height: 5),
                    SmallPromoBadge(label: product.promotion!.label),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // ราคา
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                
                
                Builder(
                  builder: (context) {
                    bool hasPromo = (product.promoPrice != null && product.promoPrice! > 0) || product.promoQty > 0;
                    num displayPrice = (product.promoPrice != null && product.promoPrice! > 0) ? product.promoPrice! : product.price;
                    return Text(
                      '฿${displayPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: hasPromo ? Colors.red : kPrimary,
                      ),
                    );
                  }
                ),


                Text('/ ${product.unit}',
                    style: TextStyle(fontSize: 12, color: context.appTextHint)),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: context.appTextHint),
          ],
        ),
      ),
    );
  }

  Widget _thumb(BuildContext context) {
    String? badgeText;
    if (product.promoQty == 2 && product.promoTotal == product.price) {
      badgeText = '1 แถม 1';
    } else if (product.promoQty == 3 && product.promoTotal == (product.price * 2)) {
      badgeText = '2 แถม 1';
    } else if (product.promoQty == 2 && product.promoTotal > product.price) {
      badgeText = 'ซื้อคู่';
    } else if (product.promoPrice != null && product.promoPrice! > 0 && product.price > 0) {
      badgeText = '-${(((product.price - product.promoPrice!) / product.price) * 100).round()}%';
    } else if (product.promoQty > 0 && product.price > 0) {
      badgeText = '-${((((product.price * product.promoQty) - product.promoTotal) / (product.price * product.promoQty)) * 100).round()}%';
    }

    Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: product.imageUrl != null && product.imageUrl!.isNotEmpty
          ? Image.network(
          getDirectImageUrl(product.imageUrl!) ?? "",
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(context),
        )
          : _placeholder(context),
    );

    if (badgeText != null) {
      return Stack(
        children: [
          image,
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: const BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomRight: Radius.circular(6),
                ),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: context.appCard,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return image;
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6)),
      child: const Icon(Icons.inventory_2_outlined, size: 24, color: Color(0xFFD1D5DB)),
    );
  }
}
