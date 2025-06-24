import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:string_similarity/string_similarity.dart';

/// Represents a matched product with details from REWE.
class ProductMatch {
  final String name;
  final String? imageUrl;
  final double similarity;
  final double price;

  ProductMatch({
    required this.name,
    this.imageUrl,
    required this.similarity,
    required this.price,
  });
}

class ReweService {
  // URL template for the REWE search page.
  static const String _searchUrlTemplate =
      'https://www.rewe.de/suche/produkte?search={query}';

  Future<List<Map<String, dynamic>>> _fetchProductsFromHtml(
      String recognizedName) async {
    final query = Uri.encodeComponent(recognizedName);
    final url = _searchUrlTemplate.replaceFirst('{query}', query);
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return [];

    // Parse the HTML
    final doc = html_parser.parse(response.body);
    final mainBlock = doc.querySelector('main#spr-search');
    if (mainBlock == null) return [];

    final productElements =
    mainBlock.querySelectorAll('article[data-product-tile]');

    final products = <Map<String, dynamic>>[];
    for (var el in productElements) {
      final nameEl = el.querySelector('.spr-product-information__title-link');
      final imgEl = el.querySelector('.spr-product-image img');
      final priceEl = el.querySelector('.spr-price__value');

      final name = nameEl?.text.trim();
      String? img;
      if (imgEl != null) {
        img = imgEl.attributes['src'] ?? imgEl.attributes['data-src'];
      }
      double? price;
      if (priceEl != null) {
        final priceText = priceEl.text.trim().replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), '');
        price = double.tryParse(priceText);
      }

      if (name != null && name.isNotEmpty) {
        products.add({'name': name, 'imageUrl': img, 'price': price});
      }
    }
    return products;
  }

  Future<ProductMatch?> matchProduct(
      String recognizedName, {
        double threshold = 0.7,
      }) async {
    final scraped = await _fetchProductsFromHtml(recognizedName);
    if (scraped.isEmpty) return null;

    final tokens = recognizedName
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2)
        .toList();

    String? bestName;
    String? bestImg;
    double bestScore = 0.0;
    double bestPrice = 0.0;

    for (var p in scraped) {
      final prodName = p['name']!;
      final lower = prodName.toLowerCase();
      final matchCount = tokens.where((t) => lower.contains(t)).length;
      final tokenScore = tokens.isEmpty ? 0 : matchCount / tokens.length;
      final fuzzy = StringSimilarity.compareTwoStrings(
        recognizedName.toLowerCase(),
        lower,
      );
      final combined = 0.6 * fuzzy + 0.4 * tokenScore;
      if (combined > bestScore) {
        bestScore = combined;
        bestName = prodName;
        bestImg = p['imageUrl'];
        bestPrice = p['price'];
      }
    }

    if (bestName != null && bestScore >= threshold) {
      return ProductMatch(
        name: bestName,
        imageUrl: bestImg,
        similarity: bestScore,
        price: bestPrice,
      );
    }
    return null;
  }
}