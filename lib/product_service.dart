import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Chỉ đúng 4 trường theo đề: name, price, soluong, image
class Product {
  final String id;
  final String name;
  final num price;
  final int soluong;
  final String image; // URL hoặc chuỗi base64

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.soluong,
    required this.image,
  });

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Product(
      id: d.id,
      name: (m['name'] ?? '') as String,
      price: (m['price'] as num?) ?? 0,
      soluong: ((m['soluong'] as num?) ?? 0).toInt(),
      image: (m['image'] ?? '') as String,
    );
  }
}

class ProductService {
  final _col = FirebaseFirestore.instance.collection('products');

  Stream<List<Product>> watchProducts() => _col
      .snapshots()
      .map((s) => s.docs.map((d) => Product.fromDoc(d)).toList());

  Future<void> add(String name, num price, int soluong, String image) =>
      _col.add({
        'name': name,
        'price': price,
        'soluong': soluong,
        'image': image,
      });

  Future<void> update(
          String id, String name, num price, int soluong, String image) =>
      _col.doc(id).update({
        'name': name,
        'price': price,
        'soluong': soluong,
        'image': image,
      });

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Xuất toàn bộ dữ liệu ra JSON (để nộp file cơ sở dữ liệu)
  Future<String> exportJson() async {
    final snap = await _col.get();
    final list = snap.docs.map((d) {
      final m = d.data();
      return {
        'name': m['name'],
        'price': m['price'],
        'soluong': m['soluong'],
        'image': m['image'],
      };
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }
}

/// Hiển thị ảnh: hỗ trợ cả URL và base64
Widget productImage(String image, {double size = 56}) {
  Widget fallback(IconData icon) =>
      SizedBox(width: size, height: size, child: Icon(icon, size: size * 0.6));

  if (image.isEmpty) return fallback(Icons.image_not_supported);
  if (image.startsWith('http')) {
    return Image.network(image,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(Icons.broken_image));
  }
  try {
    return Image.memory(base64Decode(image),
        width: size, height: size, fit: BoxFit.cover);
  } catch (_) {
    return fallback(Icons.broken_image);
  }
}
