import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../theme.dart';
import '../main.dart';
import '../widgets/product_list_tile.dart';
import '../widgets/promo_badge.dart';
import '../widgets/install_banner.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  static DateTime? lastInternalCopyTime;
  static void markInternalCopy() {
    lastInternalCopyTime = DateTime.now();
  }

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static List<Product> recentProducts = [];
  static const MethodChannel _scannerChannel =
      MethodChannel('price_checker_scanner');
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  List<Product> _results = [];
  bool _loading = false;
  String? _error;
  String _filter = 'all';
  String _sort = 'none'; // none | price_asc | price_desc | discount_desc // all | promo | new
  String _scannedBuffer = '';
  DateTime? _lastKeyPress;
  int _lastScanTriggerTime = 0;
  String _lastScanTriggerCode = '';

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _setupScannerChannel();
  }

  void _setupScannerChannel() {
    _scannerChannel.setMethodCallHandler((call) async {
      if (call.method == 'onBarcodeScanned') {
        if (!mounted || _loading) return false;
        if (SearchScreen.lastInternalCopyTime != null &&
            DateTime.now()
                    .difference(SearchScreen.lastInternalCopyTime!)
                    .inMilliseconds <
                600) {
          return false;
        }
        final raw = call.arguments?.toString() ?? '';
        final bc = raw.replaceAll('\r', '').replaceAll('\n', '').trim();
        if (bc.isEmpty) return false;

        final now = DateTime.now().millisecondsSinceEpoch;
        if (bc == _lastScanTriggerCode && (now - _lastScanTriggerTime) < 400) {
          return true;
        }
        _lastScanTriggerCode = bc;
        _lastScanTriggerTime = now;

        _debounce?.cancel();
        _focus.unfocus();
        SystemChannels.textInput.invokeMethod('TextInput.hide');

        final router = GoRouter.of(context);
        while (router.canPop()) {
          router.pop();
        }

        setState(() {
          _controller.text = bc;
        });
        _search(bc);
        return true;
      }
      return false;
    });
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (_focus.hasFocus) return false;

      final now = DateTime.now();
      if (_lastKeyPress == null || now.difference(_lastKeyPress!).inMilliseconds > 100) {
        _scannedBuffer = '';
      }
      _lastKeyPress = now;

      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (_scannedBuffer.isNotEmpty) {
          final barcode = _scannedBuffer.trim();
          _scannedBuffer = '';
          if (barcode.isNotEmpty) {
            final nowMs = now.millisecondsSinceEpoch;
            if (barcode == _lastScanTriggerCode &&
                (nowMs - _lastScanTriggerTime) < 400) {
              return true;
            }
            _lastScanTriggerCode = barcode;
            _lastScanTriggerTime = nowMs;
            setState(() {
              _controller.text = barcode;
            });
            _search(barcode);
          }
          return true;
        }
      } else if (event.character != null && event.character!.trim().isNotEmpty) {
        _scannedBuffer += event.character!;
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _scannerChannel.setMethodCallHandler(null);
    _controller.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  
  void _onSearchChanged(String query) {
    if (query.contains('\n')) {
      final bc = query.replaceAll('\r', '').replaceAll('\n', '').trim();
      _controller.text = bc;
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      if (bc.isNotEmpty) {
        _search(bc);
      }
      return;
    }
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // barcode → ไปหน้า detail เลย (ถ้าหาไม่เจอให้ fallback ไปค้นแบบชื่อ)
      if (ProductService.isBarcode(q)) {
        try {
          final product = await ProductService.searchByBarcode(q);
          if (mounted) {
            setState(() => _loading = false);
            await context.push('/product', extra: product);
            if (mounted) {
              _controller.clear();
              setState(() {
                _results = [];
              });
            }
          }
          return;
        } catch (_) {}
      }
      // SKU → ไปหน้า detail เลย
      if (ProductService.isSku(q)) {
        try {
          final product = await ProductService.searchBySku(q);
          if (mounted) {
            setState(() => _loading = false);
            await context.push('/product', extra: product);
            if (mounted) {
              _controller.clear();
              setState(() {
                _results = [];
              });
            }
          }
          return;
        } catch (_) {}
      }
      // ชื่อสินค้า → แสดงรายการ
      final list = await ProductService.searchByName(q);
      setState(() => _results = list);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Product> get _filtered {
    List<Product> list = _results;
    if (_filter == 'promo') {
      list = list.where((p) => (p.promoPrice != null && p.promoPrice! > 0) || p.promoQty > 0).toList();
    } else {
      list = List.from(list); // Make a copy before sorting
    }

    if (_sort == 'price_asc') {
      list.sort((a, b) {
        num priceA = (a.promoPrice != null && a.promoPrice! > 0) ? a.promoPrice! : a.price;
        num priceB = (b.promoPrice != null && b.promoPrice! > 0) ? b.promoPrice! : b.price;
        return priceA.compareTo(priceB);
      });
    } else if (_sort == 'price_desc') {
      list.sort((a, b) {
        num priceA = (a.promoPrice != null && a.promoPrice! > 0) ? a.promoPrice! : a.price;
        num priceB = (b.promoPrice != null && b.promoPrice! > 0) ? b.promoPrice! : b.price;
        return priceB.compareTo(priceA);
      });
    } else if (_sort == 'discount_desc') {
      list.sort((a, b) {
        num discountA = 0;
        if (a.promoPrice != null && a.promoPrice! > 0 && a.price > 0) {
          discountA = ((a.price - a.promoPrice!) / a.price) * 100;
        } else if (a.promoQty > 0 && a.price > 0) {
          discountA = (((a.price * a.promoQty) - a.promoTotal) / (a.price * a.promoQty)) * 100;
        }
        
        num discountB = 0;
        if (b.promoPrice != null && b.promoPrice! > 0 && b.price > 0) {
          discountB = ((b.price - b.promoPrice!) / b.price) * 100;
        } else if (b.promoQty > 0 && b.price > 0) {
          discountB = (((b.price * b.promoQty) - b.promoTotal) / (b.price * b.promoQty)) * 100;
        }
        return discountB.compareTo(discountA);
      });
    }
    
    return list;
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appCard,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const InstallBanner(),
            _buildHeader(),
            _buildSearchBar(),
            _buildFilterChips(),
            Expanded(
              child: Container(
                color: context.appBg,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: context.appCard,
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
      child: Row(
        children: [
          const SizedBox(width: 48), // Balance for settings button to center title
          Expanded(
            child: Text(
              'ตรวจสอบราคาสินค้า',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.appTextPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: context.appTextPrimary),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ตั้งค่า', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.appTextPrimary)),
                const SizedBox(height: 20),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (context, mode, _) {
                    final isDark = mode == ThemeMode.dark;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: context.appTextPrimary),
                      title: Text('โหมดมืด (Dark Mode)', style: TextStyle(color: context.appTextPrimary)),
                      trailing: Switch(
                        value: isDark,
                        activeColor: kPrimary,
                        onChanged: (val) {
                          themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                        },
                      ),
                    );
                  }
                ),
                const Divider(),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: context.appBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: context.appBorder),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: kPrimary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.code_rounded, size: 22, color: kPrimary),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'พัฒนาโดย champ สาขา 9544',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.appTextPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'หากมีปัญหาหรือข้อเสนอติดต่อ',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.appTextHint, fontSize: 12.5),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: kPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Line ID : champ25690',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: kPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'เวอร์ชัน 1.0.5',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.appTextHint, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: context.appCard,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.appBorder),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                style: TextStyle(fontSize: 15, color: context.appTextPrimary),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'ชื่อสินค้า, บาร์โค้ด, SKU...',
                  hintStyle: TextStyle(fontSize: 15, color: context.appTextHint),
                  prefixIcon: Icon(Icons.search, color: context.appTextHint, size: 20),
                  prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  suffixIcon: _ClearButton(
                    controller: _controller,
                    onClear: () {
                      _controller.clear();
                      _onSearchChanged('');
                    },
                  ),
                ),
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                onSubmitted: _search,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ปุ่มสแกนกล้อง
          GestureDetector(
            onTap: () async {
              final barcode = await context.push<String>('/scan');
              if (barcode != null && mounted) {
                _controller.text = barcode;
                _search(barcode);
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: kPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: context.appCard,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          _FilterChip(label: 'ทั้งหมด', value: 'all', current: _filter, onTap: (v) => setState(() => _filter = v)),
          const SizedBox(width: 8),
          _FilterChip(label: '🏷 มีโปรฯ', value: 'promo', current: _filter, onTap: (v) => setState(() => _filter = v)),
          const Spacer(),
          PopupMenuButton<String>(
            icon: Icon(Icons.sort, color: context.appTextSecondary, size: 22),
            tooltip: 'เรียงลำดับ',
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: context.appCard,
            elevation: 8,
            itemBuilder: (context) => [
              PopupMenuItem(value: 'none', child: Text('เรียงตามเริ่มต้น', style: TextStyle(color: context.appTextPrimary))),
              PopupMenuItem(value: 'discount_desc', child: Text('ลดเยอะสุด -> น้อยสุด', style: TextStyle(color: context.appTextPrimary))),
              PopupMenuItem(value: 'price_asc', child: Text('ราคาถูก -> แพง', style: TextStyle(color: context.appTextPrimary))),
              PopupMenuItem(value: 'price_desc', child: Text('ราคาแพง -> ถูก', style: TextStyle(color: context.appTextPrimary))),
            ],
          ),
        ],
      ),
    );
  }


  void _onProductTap(Product product) {
    setState(() {
      recentProducts.removeWhere((p) => p.sku == product.sku);
      recentProducts.insert(0, product);
      if (recentProducts.length > 5) {
        recentProducts.removeLast();
      }
    });
    context.push('/product', extra: product);
  }

  Widget _buildBody() {
    if (_loading) return _buildLoading();
    if (_error != null) return _buildError(_error!);
    if (_controller.text.isEmpty) return _buildEmpty();
    if (_filtered.isEmpty && _results.isNotEmpty) {
      return _buildNoPromo();
    }
    if (_filtered.isEmpty) return _buildNoResult();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Text(
            'ผลการค้นหา · ${_filtered.length} รายการ',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.appTextHint, letterSpacing: 0.4),
          ),
        ),
        Expanded(
          child: ListView.separated(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: _filtered.length,
            separatorBuilder: (_, __) => Divider(height: 0, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6))),
            itemBuilder: (_, i) => ProductListTile(
              product: _filtered[i],
              onTap: () => _onProductTap(_filtered[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (_, __) => const _ShimmerTile(),
    );
  }

  Widget _buildEmpty() {
    if (recentProducts.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14, 16, 14, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ประวัติการค้นหาล่าสุด',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.appTextHint),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      recentProducts.clear();
                    });
                  },
                  child: Text(
                    'ล้างประวัติ',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: recentProducts.length,
              separatorBuilder: (_, __) => Divider(height: 0, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6))),
              itemBuilder: (_, i) => ProductListTile(
                product: recentProducts[i],
                onTap: () => _onProductTap(recentProducts[i]),
              ),
            ),
          ),
        ],
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 56, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF444444) : const Color(0xFFE5E7EB))),
          SizedBox(height: 12),
          Text('พิมพ์ชื่อสินค้า บาร์โค้ด หรือ SKU',
              style: TextStyle(fontSize: 15, color: context.appTextHint)),
          SizedBox(height: 4),
          Text('หรือกดปุ่มกล้องเพื่อสแกน',
              style: TextStyle(fontSize: 14, color: context.appTextHint)),
        ],
      ),
    );
  }

  Widget _buildNoResult() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 56, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF444444) : const Color(0xFFE5E7EB))),
          const SizedBox(height: 12),
          Text('ไม่พบสินค้า "${_controller.text}"',
              style: TextStyle(fontSize: 15, color: context.appTextHint)),
        ],
      ),
    );
  }

  Widget _buildNoPromo() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_offer_outlined, size: 56, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF444444) : const Color(0xFFE5E7EB))),
          SizedBox(height: 12),
          Text('ไม่มีสินค้าที่มีโปรโมชั่น', style: TextStyle(fontSize: 15, color: context.appTextHint)),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF444444) : const Color(0xFFE5E7EB))),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: context.appTextSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _search(_controller.text),
              style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- sub-widgets ----

class _ClearButton extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClear;
  const _ClearButton({required this.controller, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        if (value.text.isEmpty) return const SizedBox.shrink();
        return IconButton(
          icon: Icon(Icons.clear, color: context.appTextHint, size: 20),
          onPressed: onClear,
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label, value, current;
  final void Function(String) onTap;
  const _FilterChip({required this.label, required this.value, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kPrimary : (isDark ? const Color(0xFF333333) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(25),
          boxShadow: active
              ? [BoxShadow(color: kPrimary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : context.appTextSecondary)),
      ),
    );
  }
}

class _ShimmerTile extends StatelessWidget {
  const _ShimmerTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.appCard,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(color: context.appBorder, borderRadius: BorderRadius.circular(8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 16, width: double.infinity, color: context.appBorder),
                const SizedBox(height: 8),
                Container(height: 14, width: 120, color: context.appBorder),
                const SizedBox(height: 12),
                Container(height: 18, width: 80, color: context.appBorder),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
