import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:parts/shop/models/product.dart';
import 'package:parts/shop/screens/cart_screen.dart';
import 'package:parts/shop/screens/coin_charging_screen.dart';
import 'package:parts/shop/screens/product_detail_screen.dart';
import 'package:parts/shop/services/cart_service.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({Key? key}) : super(key: key);

  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final CartService _cartService = CartService();
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'すべて';
  final List<String> _categories = ['すべて', '衣類', '靴', 'バッグ', 'アクセサリー'];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<List<Product>> _productsStream;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeProductsStream();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 検索の最適化
  void _onSearchChanged() {
    setState(() {});
  }

  void _initializeProductsStream() {
    _productsStream = _firestore
        .collection('products')
        .orderBy('createdAt', descending: true) // 新着順にソート
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildProductGrid(),
      floatingActionButton: _buildCartButton(),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'ショップ',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF00008B),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.favorite_border, color: Color(0xFF00008B)),
          onPressed: () => _navigateToFavorites(context),
        ),
        IconButton(
          icon: const Icon(Icons.monetization_on_outlined,
              color: Color(0xFF00008B)),
          onPressed: () => _navigateToCoinCharging(context),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(108),
        child: Column(
          children: [
            _buildSearchBar(),
            _buildCategoryFilter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '商品を検索',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 48,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedCategory = category);
              },
              backgroundColor: Colors.grey[100],
              selectedColor: const Color(0xFF00008B),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid() {
    return StreamBuilder<List<Product>>(
      stream: _productsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'エラーが発生しました: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = _filterProducts(snapshot.data!);

        if (products.isEmpty) {
          return const Center(
            child: Text('商品が見つかりませんでした'),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _initializeProductsStream();
            });
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3列に変更
              childAspectRatio: 0.7,
              mainAxisSpacing: 8, // スペースを調整
              crossAxisSpacing: 8, // スペースを調整
            ),
            itemCount: products.length,
            itemBuilder: (context, index) => _buildProductCard(products[index]),
          ),
        );
      },
    );
  }

  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () => _navigateToProductDetail(product),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 商品画像部分
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1, // 正方形の画像エリア
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: product.imageUrls.isNotEmpty
                      ? Hero(
                          tag: 'product-${product.id}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              product.imageUrls[0],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.error),
                            ),
                          ),
                        )
                      : const Icon(Icons.image, size: 30, color: Colors.grey),
                ),
              ),
              // お気に入りボタン
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    iconSize: 20, // アイコンサイズを小さく
                    padding: const EdgeInsets.all(4), // パディングを調整
                    icon: const Icon(Icons.favorite_border),
                    color: Colors.grey,
                    onPressed: () => _toggleFavorite(product),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 商品名
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12, // フォントサイズを小さく
            ),
          ),
          const SizedBox(height: 2),
          // 価格
          Text(
            '${product.price.toStringAsFixed(0)} P',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00008B),
            ),
          ),
          if (!product.isInStock)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '在庫なし',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFavoriteButton(Product product) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.favorite_border),
          color: Colors.grey,
          onPressed: () => _toggleFavorite(product),
        ),
      ),
    );
  }

  // ナビゲーション関連のメソッド
  void _navigateToProductDetail(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          product: product,
          isFavorite: false,
          // お気に入り状態は管理する必要あり
          onFavoritePressed: () => _toggleFavorite(product),
          onAddToCart: () => _addToCart(product),
          onFavoriteToggle: (String) {},
        ),
      ),
    );
  }

  void _navigateToFavorites(BuildContext context) {
    // お気に入り画面への遷移
  }

  void _navigateToCoinCharging(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CoinChargingScreen()),
    );
  }

  // アクション関連のメソッド
  void _toggleFavorite(Product product) {
    // お気に入り切り替えの実装
  }

  void _addToCart(Product product) async {
    if (!product.isInStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('申し訳ありません。この商品は現在在庫切れです。')),
      );
      return;
    }

    try {
      await _cartService.addToCart(product);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('カートに追加しました')),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  List<Product> _filterProducts(List<Product> products) {
    final searchQuery = _searchController.text.toLowerCase();
    return products.where((product) {
      final matchesCategory = _selectedCategory == 'すべて' ||
          product.categories.contains(_selectedCategory);
      final matchesSearch = product.name.toLowerCase().contains(searchQuery) ||
          product.description.toLowerCase().contains(searchQuery);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Widget _buildCartButton() {
    return StreamBuilder<int>(
      stream: _cartService.getCartItemCount(),
      builder: (context, snapshot) {
        final itemCount = snapshot.data ?? 0;
        return FloatingActionButton(
          backgroundColor: const Color(0xFF00008B),
          onPressed: () => _navigateToCart(context), // contextを渡す
          child: Badge(
            label: Text('$itemCount'),
            child: const Icon(Icons.shopping_cart, color: Colors.white),
          ),
        );
      },
    );
  }

  void _navigateToCart(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(), // CartScreenのインポートが必要
      ),
    );
  }
}
