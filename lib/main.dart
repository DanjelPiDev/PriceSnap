import 'package:flutter/material.dart';
import 'package:price_snap/screens/shopping_cart.dart';

import 'package:intl/date_symbol_data_local.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de');
  runApp(const PriceSnapApp());
}

class PriceSnapApp extends StatelessWidget {
  const PriceSnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PriceSnap',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}
