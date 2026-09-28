import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // รูปสินค้า
          Center(
            child: _ProductImage(imageUrl: product.imageUrl, size: 250),
          ),
          const SizedBox(height: 32),

          // SKU + Barcode row (Chips)
          Row(
            children: [
              GestureDetector(
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: product.sku));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('คัดลอกรหัส SKU แล้ว'), duration: Duration(seconds: 2)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2, size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Text('SKU: ${product.sku}',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              if (product.barcode.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: product.barcode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('คัดลอกรหัสบาร์โค้ดแล้ว'), duration: Duration(seconds: 2)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code, size: 14, color: context.appTextSecondary),
                        const SizedBox(width: 6),
                        Text(product.barcode,
                            style: TextStyle(fontSize: 12, color: context.appTextSecondary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ]
            ],
          ),
          const SizedBox(height: 16),

          // ชื่อสินค้า
          Text(
            product.name,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: context.appTextPrimary,
              height: 1.35,
              letterSpacing: -0.5,
            ),
          ),
          if (product.promoStart != null && product.promoEnd != null) ...[
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final isMember = product.memberOnly;
                final primaryColor = isMember ? Colors.blue.shade600 : Colors.red.shade500;
                final bgColor = isMember ? Colors.blue.shade50 : Colors.red.shade50;
                
                int? daysLeft;
                try {
                  final endDate = DateTime.parse(product.promoEnd!);
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final end = DateTime(endDate.year, endDate.month, endDate.day);
                  daysLeft = end.difference(today).inDays;
                } catch (_) {}

                Widget dateCol(String title, String date, IconData icon) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 16, color: primaryColor.withOpacity(0.7)),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(fontSize: 12, color: primaryColor.withOpacity(0.8))),
                          Text(date, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor)),
                        ],
                      ),
                    ],
                  );
                }

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time_filled, color: primaryColor, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            'ระยะเวลาโปรโมชั่น',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const Spacer(),
                          if (daysLeft != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: daysLeft < 0 ? Colors.grey : (daysLeft <= 3 ? Colors.orange.shade700 : primaryColor),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                daysLeft < 0 
                                    ? 'หมดโปรโมชั่น' 
                                    : (daysLeft == 0 ? 'วันสุดท้าย!' : 'เหลืออีก $daysLeft วัน'),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: dateCol('เริ่ม', _formatDate(product.promoStart), Icons.calendar_today)),
                            Container(width: 1, height: 30, color: primaryColor.withOpacity(0.2)),
                            Expanded(child: dateCol('สิ้นสุด', _formatDate(product.promoEnd), Icons.event_available)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
            ),
          ],
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
    bool hasPromo = (product.promoPrice != null && product.promoPrice! > 0) || product.promoQty > 0;
    bool hasMemberPromo = product.memberPrice != null;

    if (!hasPromo && !hasMemberPromo) {
      // Normal Price Only
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: kPrimary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kPrimary.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('ราคา ', style: TextStyle(fontSize: 18, color: context.appTextHint)),
            Text('฿${product.normalPrice}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: kPrimary)),
            Text(' / ${product.unit}', style: TextStyle(fontSize: 16, color: context.appTextHint)),
          ],
        ),
      );
    }

    String getSavingText() {
      if (product.promoQty > 0) {
        num totalNormal = product.normalPrice * product.promoQty;
        num savings = totalNormal - product.promoTotal;
        int percent = ((savings / totalNormal) * 100).round();
        return 'ประหยัด ฿$savings ($percent%)';
      } else if (product.promoPrice != null && product.promoPrice! > 0) {
        num savings = product.normalPrice - product.promoPrice!;
        int percent = ((savings / product.normalPrice) * 100).round();
        return 'ประหยัด ฿$savings ($percent%)';
      }
      return '';
    }

    // Has Promotions
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // If has normal promo
          if (hasPromo)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: product.memberOnly 
                      ? [Colors.blue.shade500, Colors.blue.shade700] 
                      : [Colors.red.shade500, Colors.red.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: (product.memberOnly ? Colors.blue : Colors.red).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          product.memberOnly ? '🌟 เฉพาะสมาชิก' : '🔥 โปรโมชั่นพิเศษ',
                          style: TextStyle(
                            color: product.memberOnly ? Colors.blue.shade700 : Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      // Strikethrough normal price
                      Text(
                        'ปกติ ฿${product.normalPrice}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Promo Price Display
                  if (product.isBuy1Get1) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('ซื้อ 1 แถม 1', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('฿${product.promoTotal}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.0)),
                            Text('เฉลี่ย ฿${(product.promoTotal / 2).toStringAsFixed(2)}/ชิ้น', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ] else if (product.promoQty > 0) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          product.isBuy2Get1 ? '2 แถม 1' : 'ซื้อคู่ถูกกว่า',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('฿${product.promoTotal}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.0)),
                            Text('เฉลี่ย ฿${(product.promoTotal / product.promoQty).toStringAsFixed(2)}/ชิ้น', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ] else if (product.promoPrice != null && product.promoPrice! > 0) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('฿${product.promoPrice}', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, height: 1.0)),
                        const SizedBox(width: 8),
                        Text('/ ${product.unit}', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  
                  // Savings banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        getSavingText(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (hasPromo && hasMemberPromo) const SizedBox(height: 16),

          if (hasMemberPromo)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade500, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '🌟 ราคาสมาชิก',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (!hasPromo)
                        Text(
                          'ปกติ ฿${product.normalPrice}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('฿${product.memberPrice}', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, height: 1.0)),
                      const SizedBox(width: 8),
                      Text('/ ${product.unit}', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'ประหยัด ฿${product.normalPrice - product.memberPrice!} (${(((product.normalPrice - product.memberPrice!) / product.normalPrice) * 100).round()}%)',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
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
      return GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(color: Colors.black87),
                    ),
                  ),
                  Center(
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.5,
                      maxScale: 4,
                      child: Image.network(
                        getDirectImageUrl(imageUrl!) ?? "",
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 100, color: Colors.white54),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 30),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.black.withOpacity(0.04)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              getDirectImageUrl(imageUrl!) ?? "",
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _placeholder(context),
            ),
          ),
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
