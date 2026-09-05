import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../models/product.dart';
import '../utils/image_utils.dart';
import '../theme.dart';
import '../widgets/promo_badge.dart';

class ProductDetailScreen extends StatelessWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHero(context),
                    const SizedBox(height: 10),
                    _buildPriceCard(context),
                    const SizedBox(height: 8),
                    _buildInfoCard(context),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      color: context.appCard,
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back, size: 20, color: context.appTextSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('รายละเอียดสินค้า',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: context.appTextPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      color: context.appCard,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        children: [
          // รูปสินค้า
          _ProductImage(imageUrl: getDirectImageUrl(product.imageUrl) ?? "", size: 120),
          const SizedBox(height: 14),

          // ชื่อสินค้า
          Text(
            product.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.appTextPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),

          // SKU + Barcode row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(product.sku,
                  style: TextStyle(fontSize: 14, color: context.appTextHint)),
              if (product.barcode.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.barcode_reader, size: 13, color: context.appTextSecondary),
                      const SizedBox(width: 4),
                      Text(product.barcode,
                          style: TextStyle(fontSize: 13, color: context.appTextSecondary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }

  
  
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildPriceCard(BuildContext context) {

    return Column(
      children: [
        // Normal Price Card
        
        if (((product.promoPrice != null && product.promoPrice! > 0) || product.promoQty > 0) || (product.memberPrice != null))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if ((product.promoPrice != null && product.promoPrice! > 0) || product.promoQty > 0)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.shade400, Colors.red.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (product.promoQty == 2 && product.promoTotal == product.normalPrice) ...[
                            const Text('ซื้อ 1 แถม 1', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('฿${product.promoTotal}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            Text('(เฉลี่ย ฿${(product.promoTotal / 2).toStringAsFixed(2)}/ชิ้น)', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                              child: Text('ประหยัด ฿${product.normalPrice}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ] else if (product.promoQty > 0) ...[
                            Builder(
                              builder: (context) {
                                String title = 'ซื้อ ${product.promoQty} ชิ้น';
                                if (product.promoQty == 3 && product.promoTotal == (product.normalPrice * 2)) {
                                  title = '2 แถม 1';
                                } else if (product.promoQty == 2 && product.promoTotal > product.normalPrice) {
                                  title = 'ซื้อคู่';
                                }
                                return Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));
                              }
                            ),
                            const SizedBox(height: 4),
                            Text('฿${product.promoTotal}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            Text('(เฉลี่ย ฿${(product.promoTotal / product.promoQty).toStringAsFixed(2)}/ชิ้น)', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                              child: Text('ประหยัด ฿${(product.normalPrice * product.promoQty) - product.promoTotal} (${((((product.normalPrice * product.promoQty) - product.promoTotal) / (product.normalPrice * product.promoQty)) * 100).round()}%)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ] else if (product.promoPrice != null && product.promoPrice! > 0) ...[
                            const Text('ราคาโปรโมชั่น', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text('฿${product.promoPrice}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                              child: Text('ประหยัด ฿${product.normalPrice - product.promoPrice!} (${(((product.normalPrice - product.promoPrice!) / product.normalPrice) * 100).round()}%)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                          if (product.promoStart != null && product.promoEnd != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_month, size: 14, color: Colors.red.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_formatDate(product.promoStart)} - ${_formatDate(product.promoEnd)}',
                                    style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (((product.promoPrice != null && product.promoPrice! > 0) || product.promoQty > 0) && (product.memberPrice != null))
                  const SizedBox(width: 12),
                if (product.memberPrice != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ราคาสมาชิก', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('฿${product.memberPrice}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                            child: Text('ประหยัด ฿${product.normalPrice - product.memberPrice!} (${(((product.normalPrice - product.memberPrice!) / product.normalPrice) * 100).round()}%)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (((product.promoPrice != null && product.promoPrice! > 0) || product.promoQty > 0) || (product.memberPrice != null))
          const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ราคาปกติ', style: TextStyle(color: Colors.blue, fontSize: 13)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('฿${product.normalPrice}', style: const TextStyle(color: Colors.blue, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Text('/ ${product.unit}', style: TextStyle(fontSize: 13, color: Colors.blue.shade300, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Promo and Member Cards,
],
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    if (product.weight.isEmpty && !product.pointX2) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        children: [
          if (product.weight.isNotEmpty)
            _InfoRow(label: 'น้ำหนัก/ปริมาณ', value: product.weight, isLast: !product.pointX2),
          if (product.pointX2)
            const _InfoRow(
              label: 'รับคะแนน × 2',
              value: 'ใช่',
              valueColor: Colors.orange,
              icon: Icons.stars,
              isLast: true,
            ),
        ],
      ),
    );
  }
}

// ---- sub-widgets ----

class _ProductImage extends StatelessWidget {

  final String? imageUrl;
  final double size;
  const _ProductImage({this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          getDirectImageUrl(imageUrl!) ?? "",
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(context),
        ),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFFD1D5DB)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final IconData? icon;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isLast ? null : Border(
          bottom: BorderSide(color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6))),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: context.appTextHint, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (icon != null) ...[
            Icon(icon, size: 15, color: valueColor ?? context.appTextPrimary),
            const SizedBox(width: 4),
          ],
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? context.appTextPrimary)),
        ],
      ),
    );
  }
}
