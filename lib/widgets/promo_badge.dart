import 'package:flutter/material.dart';
import '../theme.dart';

class PromoBadge extends StatelessWidget {
  final String label;
  final String? until;
  const PromoBadge({super.key, required this.label, this.until});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kPromo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_offer, size: 14, color: kPromoText),
          const SizedBox(width: 5),
          Text(
            until != null ? '$label · ถึง $until' : label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: kPromoText,
            ),
          ),
        ],
      ),
    );
  }
}

class SmallPromoBadge extends StatelessWidget {
  final String label;
  const SmallPromoBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: kPromo,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPromoText),
      ),
    );
  }
}
