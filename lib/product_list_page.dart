import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'bakery_theme.dart';
import 'product_service.dart';

/// Sản phẩm có số lượng <= ngưỡng này được coi là "sắp hết"
const int kLowStock = 5;

enum StockFilter { all, inStock, low, out }

enum SortMode { none, priceAsc, priceDesc, nameAsc, stockAsc }

String fmtMoney(num v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final left = s.length - i;
    buf.write(s[i]);
    if (left > 1 && left % 3 == 1) buf.write('.');
  }
  return '${buf}đ';
}

BoxDecoration _cardDecoration([double radius = 18]) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
            color: Color(0x1A6D4C41), blurRadius: 12, offset: Offset(0, 4)),
      ],
    );

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final _service = ProductService();
  final _searchCtrl = TextEditingController();
  String _keyword = '';
  StockFilter _stock = StockFilter.all;
  SortMode _sort = SortMode.none;
  double? _pMin; // null = không giới hạn
  double? _pMax;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _hasFilter =>
      _keyword.isNotEmpty ||
      _stock != StockFilter.all ||
      _sort != SortMode.none ||
      _pMin != null ||
      _pMax != null;

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      _keyword = '';
      _stock = StockFilter.all;
      _sort = SortMode.none;
      _pMin = null;
      _pMax = null;
    });
  }

  List<Product> _applyFilters(List<Product> all) {
    final kw = _keyword.trim().toLowerCase();
    final list = all.where((p) {
      if (kw.isNotEmpty && !p.name.toLowerCase().contains(kw)) return false;
      switch (_stock) {
        case StockFilter.inStock:
          if (p.soluong <= kLowStock) return false;
          break;
        case StockFilter.low:
          if (p.soluong < 1 || p.soluong > kLowStock) return false;
          break;
        case StockFilter.out:
          if (p.soluong > 0) return false;
          break;
        case StockFilter.all:
          break;
      }
      if (_pMin != null && p.price < _pMin!) return false;
      if (_pMax != null && p.price > _pMax!) return false;
      return true;
    }).toList();

    switch (_sort) {
      case SortMode.priceAsc:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortMode.priceDesc:
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case SortMode.nameAsc:
        list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case SortMode.stockAsc:
        list.sort((a, b) => a.soluong.compareTo(b.soluong));
        break;
      case SortMode.none:
        break;
    }
    return list;
  }

  // ---------- Thêm / Sửa ----------
  Future<void> _openForm({Product? product}) async {
    await showDialog(
      context: context,
      builder: (_) => _ProductForm(
        product: product,
        onSave: (name, price, soluong, image) async {
          if (product == null) {
            await _service.add(name, price, soluong, image);
          } else {
            await _service.update(product.id, name, price, soluong, image);
          }
        },
      ),
    );
  }

  // ---------- Xóa ----------
  Future<void> _confirmDelete(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa sản phẩm'),
        content: Text('Bạn có chắc muốn xóa "${p.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kRed),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (ok == true) await _service.delete(p.id);
  }

  // ---------- Xuất JSON ----------
  Future<void> _export() async {
    final json = await _service.exportJson();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Dữ liệu JSON'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: SingleChildScrollView(child: SelectableText(json)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép JSON')));
            },
            child: const Text('Sao chép'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
        ],
      ),
    );
  }

  // ---------- Bộ lọc ----------
  Widget _stockChip(String label, StockFilter value, int count) {
    final selected = _stock == value;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      showCheckmark: false,
      selectedColor: kCaramel,
      backgroundColor: kCream,
      side: BorderSide(color: selected ? kCaramel : const Color(0xFFE8D5BE)),
      labelStyle: TextStyle(
        color: selected ? Colors.white : kBrown,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => setState(() => _stock = value),
    );
  }

  Widget _sortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: kCream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8D5BE)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SortMode>(
          value: _sort,
          isDense: true,
          icon: const Icon(Icons.sort, color: kBrown),
          style: const TextStyle(color: kBrown, fontWeight: FontWeight.w600),
          items: const [
            DropdownMenuItem(value: SortMode.none, child: Text('Mặc định')),
            DropdownMenuItem(
                value: SortMode.priceAsc, child: Text('Giá tăng dần')),
            DropdownMenuItem(
                value: SortMode.priceDesc, child: Text('Giá giảm dần')),
            DropdownMenuItem(value: SortMode.nameAsc, child: Text('Tên A-Z')),
            DropdownMenuItem(
                value: SortMode.stockAsc, child: Text('Số lượng ít nhất')),
          ],
          onChanged: (v) => setState(() => _sort = v ?? SortMode.none),
        ),
      ),
    );
  }

  Widget _priceSlider(List<Product> all) {
    if (all.length < 2) return const SizedBox.shrink();
    double lo = all.first.price.toDouble();
    double hi = lo;
    for (final p in all) {
      final v = p.price.toDouble();
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    if (hi <= lo) return const SizedBox.shrink();

    double start = (_pMin ?? lo).clamp(lo, hi).toDouble();
    double end = (_pMax ?? hi).clamp(lo, hi).toDouble();
    if (start > end) {
      final t = start;
      start = end;
      end = t;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Khoảng giá',
                style: TextStyle(color: kBrown, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${fmtMoney(start)} – ${fmtMoney(end)}',
                style: const TextStyle(
                    color: kCaramel, fontWeight: FontWeight.w700)),
          ],
        ),
        RangeSlider(
          values: RangeValues(start, end),
          min: lo,
          max: hi,
          activeColor: kCaramel,
          inactiveColor: const Color(0xFFE8D5BE),
          onChanged: (v) => setState(() {
            _pMin = v.start <= lo ? null : v.start;
            _pMax = v.end >= hi ? null : v.end;
          }),
        ),
      ],
    );
  }

  Widget _filterPanel(List<Product> all) {
    final inStock = all.where((p) => p.soluong > kLowStock).length;
    final low =
        all.where((p) => p.soluong >= 1 && p.soluong <= kLowStock).length;
    final out = all.where((p) => p.soluong <= 0).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Tìm bánh theo tên...',
              prefixIcon: const Icon(Icons.search, color: kBrown),
              suffixIcon: _keyword.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _searchCtrl.clear();
                        _keyword = '';
                      }),
                    ),
              filled: true,
              fillColor: kCream,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => _keyword = v),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _stockChip('Tất cả', StockFilter.all, all.length),
              _stockChip('Còn hàng', StockFilter.inStock, inStock),
              _stockChip('Sắp hết', StockFilter.low, low),
              _stockChip('Hết hàng', StockFilter.out, out),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _sortDropdown(),
              if (_hasFilter)
                TextButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.filter_alt_off, size: 18),
                  label: const Text('Xóa bộ lọc'),
                  style: TextButton.styleFrom(foregroundColor: kRed),
                ),
            ],
          ),
          _priceSlider(all),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCream,
      appBar: AppBar(
        backgroundColor: kCream,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: const Row(
          children: [
            Icon(Icons.bakery_dining, color: kCaramel, size: 28),
            SizedBox(width: 8),
            Text('Tiệm Bánh Ngọt',
                style: TextStyle(
                    color: kBrown, fontWeight: FontWeight.w800, fontSize: 20)),
          ],
        ),
        actions: [
          IconButton(
              tooltip: 'Xuất JSON',
              icon: const Icon(Icons.data_object, color: kBrown),
              onPressed: _export),
          IconButton(
              tooltip: 'Đăng xuất',
              icon: const Icon(Icons.logout, color: kBrown),
              onPressed: () => FirebaseAuth.instance.signOut()),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kCaramel,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm bánh'),
      ),
      body: StreamBuilder<List<Product>>(
        stream: _service.watchProducts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: kCaramel));
          }
          final all = snapshot.data!;
          final filtered = _applyFilters(all);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _Banner(onAdd: () => _openForm())),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
                      child: Text('Thống kê nhanh',
                          style: TextStyle(
                              color: kBrown,
                              fontWeight: FontWeight.w800,
                              fontSize: 18)),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _StatsRow(all: all),
                    ),
                  ),
                  SliverToBoxAdapter(child: _filterPanel(all)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                      child: Row(
                        children: [
                          const Text('Danh sách bánh',
                              style: TextStyle(
                                  color: kBrown,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18)),
                          const Spacer(),
                          Text('${filtered.length}/${all.length} sản phẩm',
                              style: const TextStyle(color: kBrown)),
                        ],
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            const Icon(Icons.cookie_outlined,
                                size: 64, color: kHoney),
                            const SizedBox(height: 12),
                            Text(
                              all.isEmpty
                                  ? 'Chưa có bánh nào. Bấm "Thêm bánh" để tạo sản phẩm đầu tiên.'
                                  : 'Không có sản phẩm phù hợp với bộ lọc.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: kBrown),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 230,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.72,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final p = filtered[i];
                            return _ProductCard(
                              product: p,
                              onEdit: () => _openForm(product: p),
                              onDelete: () => _confirmDelete(p),
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ================= Banner =================
class _Banner extends StatelessWidget {
  final VoidCallback onAdd;
  const _Banner({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [kDarkBrown, kCaramel, kHoney],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x40D98324), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -24,
            child: Icon(Icons.cake,
                size: 150, color: Colors.white.withValues(alpha: 0.15)),
          ),
          Positioned(
            right: 90,
            bottom: -34,
            child: Icon(Icons.cookie,
                size: 120, color: Colors.white.withValues(alpha: 0.13)),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Icon(Icons.bakery_dining,
                size: 80, color: Colors.white.withValues(alpha: 0.2)),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Tươi ngon mỗi ngày',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 12),
                  const Text('Chào mừng đến Tiệm Bánh Ngọt',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1.2)),
                  const SizedBox(height: 8),
                  Text(
                    'Quản lý kho bánh: thêm bánh mới, cập nhật giá và số lượng chỉ với vài chạm.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 14,
                        height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onAdd,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: kDarkBrown,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm bánh mới'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= Thống kê =================
class _StatData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatData(this.icon, this.label, this.value, this.color);
}

class _StatsRow extends StatelessWidget {
  final List<Product> all;
  const _StatsRow({required this.all});

  @override
  Widget build(BuildContext context) {
    final totalQty = all.fold<int>(0, (s, p) => s + p.soluong);
    final value = all.fold<num>(0, (s, p) => s + p.price * p.soluong);
    final low = all.where((p) => p.soluong <= kLowStock).length;

    final items = <_StatData>[
      _StatData(Icons.cake, 'Loại bánh', '${all.length}', kCaramel),
      _StatData(Icons.inventory_2, 'Tổng số lượng', '$totalQty', kGreen),
      _StatData(Icons.payments, 'Giá trị tồn kho', fmtMoney(value), kBrown),
      _StatData(
          Icons.warning_amber_rounded, 'Sắp hết / hết hàng', '$low', kRed),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 640 ? 4 : 2;
        const gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final d in items) SizedBox(width: w, child: _StatCard(d)),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard(this.data);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(data.value,
                      style: TextStyle(
                          color: data.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 20)),
                ),
                Text(data.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kBrown, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= Thẻ sản phẩm (lưới) =================
class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    final out = p.soluong <= 0;
    final low = !out && p.soluong <= kLowStock;
    final badgeColor = out ? kRed : (low ? kOrange : kGreen);
    final badgeText =
        out ? 'Hết hàng' : (low ? 'Sắp hết: ${p.soluong}' : 'Còn ${p.soluong}');

    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onEdit,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _CardImage(image: p.image),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(badgeText,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: PopupMenuButton<String>(
                        tooltip: 'Tùy chọn',
                        padding: EdgeInsets.zero,
                        color: Colors.white,
                        onSelected: (v) {
                          if (v == 'edit') onEdit();
                          if (v == 'delete') onDelete();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [
                                Icon(Icons.edit, size: 18, color: kBrown),
                                SizedBox(width: 8),
                                Text('Sửa'),
                              ])),
                          PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete, size: 18, color: kRed),
                                SizedBox(width: 8),
                                Text('Xóa'),
                              ])),
                        ],
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.more_vert,
                              size: 18, color: kBrown),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: kBrown,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(fmtMoney(p.price),
                        style: const TextStyle(
                            color: kCaramel,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ảnh sản phẩm: hỗ trợ URL hoặc base64, giải mã một lần để lưới cuộn mượt
class _CardImage extends StatefulWidget {
  final String image;
  const _CardImage({required this.image});

  @override
  State<_CardImage> createState() => _CardImageState();
}

class _CardImageState extends State<_CardImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant _CardImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _decode();
  }

  void _decode() {
    _bytes = null;
    final s = widget.image;
    if (s.isNotEmpty && !s.startsWith('http')) {
      try {
        _bytes = base64Decode(s);
      } catch (_) {
        _bytes = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: const Color(0xFFFFEFD9),
      child: const Center(
          child: Icon(Icons.bakery_dining, size: 48, color: Color(0xFFE2B98A))),
    );
    if (widget.image.startsWith('http')) {
      return Image.network(widget.image,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder);
    }
    if (_bytes != null) {
      return Image.memory(_bytes!, fit: BoxFit.cover, gaplessPlayback: true);
    }
    return placeholder;
  }
}

// ================= Form thêm / sửa =================
class _ProductForm extends StatefulWidget {
  final Product? product;
  final Future<void> Function(String name, num price, int soluong, String image)
      onSave;

  const _ProductForm({this.product, required this.onSave});

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _soluong;
  late final TextEditingController _imageUrl;
  String _imageBase64 = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _price = TextEditingController(text: p?.price.toString() ?? '');
    _soluong = TextEditingController(text: p?.soluong.toString() ?? '');
    final img = p?.image ?? '';
    if (img.startsWith('http')) {
      _imageUrl = TextEditingController(text: img);
    } else {
      _imageUrl = TextEditingController();
      _imageBase64 = img;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _soluong.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      imageQuality: 60,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);
    if (b64.length > 700000) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ảnh quá lớn, hãy chọn ảnh nhỏ hơn')));
      return;
    }
    setState(() {
      _imageBase64 = b64;
      _imageUrl.clear();
    });
  }

  String get _currentImage =>
      _imageUrl.text.trim().isNotEmpty ? _imageUrl.text.trim() : _imageBase64;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        _name.text.trim(),
        num.parse(_price.text.trim()),
        int.parse(_soluong.text.trim()),
        _currentImage,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lưu thất bại: $e')));
    }
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: kBrown),
        filled: true,
        fillColor: kCream,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    final editing = widget.product != null;
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(
        children: [
          Icon(editing ? Icons.edit : Icons.add_circle, color: kCaramel),
          const SizedBox(width: 8),
          Text(editing ? 'Sửa bánh' : 'Thêm bánh mới',
              style:
                  const TextStyle(color: kBrown, fontWeight: FontWeight.w800)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _dec('Tên bánh (name)', Icons.cake),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nhập tên sản phẩm'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: _dec('Giá (price)', Icons.sell),
                  validator: (v) {
                    final n = num.tryParse(v?.trim() ?? '');
                    return (n == null || n <= 0) ? 'Giá phải là số > 0' : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _soluong,
                  keyboardType: TextInputType.number,
                  decoration: _dec('Số lượng (soluong)', Icons.inventory_2),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    return (n == null || n < 0)
                        ? 'Số lượng phải là số nguyên >= 0'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageUrl,
                  decoration: _dec('URL hình ảnh (hoặc chọn ảnh)', Icons.link),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      style: OutlinedButton.styleFrom(
                          foregroundColor: kBrown,
                          side: const BorderSide(color: kCaramel)),
                      icon: const Icon(Icons.photo),
                      label: const Text('Chọn ảnh'),
                    ),
                    const SizedBox(width: 12),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: productImage(_currentImage, size: 64)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Hủy')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kCaramel),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Lưu'),
        ),
      ],
    );
  }
}
