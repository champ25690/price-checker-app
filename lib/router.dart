import 'package:go_router/go_router.dart';
import 'models/product.dart';
import 'screens/search_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/product_detail_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/scan',
      builder: (context, state) => const ScannerScreen(),
    ),
    GoRoute(
      path: '/product',
      builder: (context, state) {
        final product = state.extra as Product;
        return ProductDetailScreen(product: product);
      },
    ),
  ],
);
