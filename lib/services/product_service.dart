import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class ProductService {
  static const String _baseUrl = 'https://vfsmfebitueibbipnamc.supabase.co/rest/v1/products';
  static const Map<String, String> _headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmc21mZWJpdHVlaWJiaXBuYW1jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkyOTIyMTIsImV4cCI6MjA5NDg2ODIxMn0.46MDJjbGK_LNhcoe-_Wuj-Kh2jLlYHYL7pQLoLB1gvU",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmc21mZWJpdHVlaWJiaXBuYW1jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkyOTIyMTIsImV4cCI6MjA5NDg2ODIxMn0.46MDJjbGK_LNhcoe-_Wuj-Kh2jLlYHYL7pQLoLB1gvU",
    "Content-Type": "application/json"
  };

  static bool isBarcode(String q) {
    if (q.contains(' ')) return false;
    if (q.length < 5 || q.length > 20) return false;
    final digitCount = q.replaceAll(RegExp(r'[^0-9]'), '').length;
    return digitCount >= 4;
  }
  
  static bool isSku(String q) => RegExp(r'^[A-Za-z0-9]{3}-[A-Za-z0-9]+$').hasMatch(q) || (q.length >= 6 && !q.contains(' '));

  static Future<List<Product>> searchByName(String query) async {
    final q = Uri.encodeComponent(query);
    final likeQ = Uri.encodeComponent('*$query*');
    // ค้นหาจากชื่อ (ilike), บาร์โค้ด (ilike), หรือ SKU (ilike) เพื่อให้ครอบคลุม
    final url = Uri.parse('$_baseUrl?select=*&or=(name.ilike.$likeQ,barcode.ilike.$likeQ,sku.ilike.$likeQ)');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Product.fromJson(json)).toList();
    }
    throw Exception('ค้นหาไม่สำเร็จ');
  }

  static Future<Product> searchByBarcode(String barcode) async {
    final url = Uri.parse('$_baseUrl?select=*&barcode=eq.$barcode');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (data.isNotEmpty) return Product.fromJson(data.first);
    }
    throw Exception('ไม่พบสินค้าบาร์โค้ด $barcode');
  }

  static Future<Product> searchBySku(String sku) async {
    final url = Uri.parse('$_baseUrl?select=*&sku=eq.$sku');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (data.isNotEmpty) return Product.fromJson(data.first);
    }
    throw Exception('ไม่พบสินค้า SKU $sku');
  }
}
