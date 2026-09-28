class Product {
  final num normalPrice;
  final num? promoPrice;
  final int promoQty;
  final num promoTotal;

  Product(this.normalPrice, this.promoPrice, this.promoQty, this.promoTotal);

  num get basePriceForPromo => (promoPrice != null && promoPrice! > 0) ? promoPrice! : normalPrice;
  bool get isBuy1Get1 => promoQty == 2 && promoTotal > 0 && promoTotal == basePriceForPromo;
}

void main() {
  var p1 = Product(12, null, 2, 20); // Normal pair
  print('P1 (12, null, 2, 20): base=${p1.basePriceForPromo}, 1แถม1=${p1.isBuy1Get1}');
  
  var p2 = Product(12, 0, 2, 20);
  print('P2 (12, 0, 2, 20): base=${p2.basePriceForPromo}, 1แถม1=${p2.isBuy1Get1}');
  
  var p3 = Product(12, 20, 2, 20); // If backend sends promoPrice=20 by mistake
  print('P3 (12, 20, 2, 20): base=${p3.basePriceForPromo}, 1แถม1=${p3.isBuy1Get1}');
}
