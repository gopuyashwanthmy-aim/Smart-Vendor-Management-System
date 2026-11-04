import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import 'cart_page.dart';
import 'customer_pages.dart';
import 'my_orders_page.dart';

class HomePage extends StatefulWidget {
  final AuthService authService;

  const HomePage({super.key, required this.authService});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Product>> productsFuture;
  late Future<List<dynamic>> categoriesFuture;

  final CartService cartService = CartService();
  final TextEditingController search = TextEditingController();

  int? selectedCategory;
  double? maxPrice;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void _refresh() {
    productsFuture = ApiService.getProducts();
    categoriesFuture = ApiService.getCategories();
  }

  void _open(Widget page) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _logout() {
    widget.authService.logout();
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  Widget _item(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2E7D32)),
      title: Text(title),
      onTap: onTap,
    );
  }

  Widget _drawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              color: const Color(0xFFE4F1E1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 27,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      color: Color(0xFF2E7D32),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.authService.user?['name'] ?? 'Customer',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF194D24),
                    ),
                  ),
                  const Text(
                    'Customer account',
                    style: TextStyle(color: Color(0xFF55745A)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  _item(
                    Icons.home_outlined,
                    'Home',
                    () => Navigator.pop(context),
                  ),
                  _item(
                    Icons.person_outline,
                    'My Profile',
                    () => _open(
                      CustomerProfilePage(authService: widget.authService),
                    ),
                  ),
                  _item(
                    Icons.location_on_outlined,
                    'Delivery Address',
                    () => _open(
                      CustomerAddressesPage(authService: widget.authService),
                    ),
                  ),
                  _item(
                    Icons.shopping_cart_outlined,
                    'My Cart',
                    () => _open(
                      CartPage(
                        cartService: cartService,
                        authService: widget.authService,
                      ),
                    ),
                  ),
                  _item(
                    Icons.receipt_long_outlined,
                    'My Orders',
                    () => _open(
                      MyOrdersPage(authService: widget.authService),
                    ),
                  ),
                  _item(
                    Icons.calendar_month_outlined,
                    'Scheduled Delivery',
                    () => _open(
                      ScheduledDeliveriesPage(
                        authService: widget.authService,
                      ),
                    ),
                  ),
                  _item(
                    Icons.notifications_none,
                    'Notifications',
                    () => _open(
                      CustomerNotificationsPage(
                        authService: widget.authService,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFilters(List<Product> products) async {
    final rawMax = products.isEmpty
        ? 500.0
        : products
            .map((product) => product.price)
            .reduce((a, b) => a > b ? a : b);
    final upper = rawMax.clamp(100.0, 5000.0).toDouble();
    double value = (maxPrice ?? upper).clamp(0.0, upper).toDouble();

    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Filter by price'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Maximum price: ₹${value.toStringAsFixed(0)}'),
                  Slider(
                    min: 0,
                    max: upper,
                    value: value,
                    onChanged: (newValue) {
                      setDialogState(() => value = newValue);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, -1.0),
                  child: const Text('Clear'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, value),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (result == -1) {
      setState(() => maxPrice = null);
    } else if (result != null) {
      setState(() => maxPrice = result);
    }
  }

  Widget _productCard(Product product) {
    final available = product.stockQuantity > 0;
    final low = product.stockQuantity > 0 && product.stockQuantity <= 3;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xFFEAF4E8),
              child: product.imageUrl != null &&
                      product.imageUrl!.isNotEmpty
                  ? Image.network(
                      product.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.eco,
                          size: 54,
                          color: Colors.green,
                        );
                      },
                    )
                  : const Icon(
                      Icons.eco,
                      size: 54,
                      color: Colors.green,
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${product.price.toStringAsFixed(2)} / ${product.unit}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Text(
                  !available
                      ? 'Out of stock'
                      : low
                          ? 'Only ${product.stockQuantity} ${product.unit} left'
                          : 'In stock',
                  style: TextStyle(
                    fontSize: 12,
                    color: !available
                        ? Colors.red
                        : low
                            ? Colors.orange
                            : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: !available
                        ? null
                        : () {
                            setState(() => cartService.addProduct(product));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${product.name} added to cart',
                                ),
                              ),
                            );
                          },
                    icon: const Icon(
                      Icons.add_shopping_cart,
                      size: 18,
                    ),
                    label: Text(
                      available ? 'Add to Cart' : 'Unavailable',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _drawer(),
      appBar: AppBar(
        title: const Text('🥬 Smart Vendor'),
        actions: [
          Stack(
            children: [
              IconButton(
                tooltip: 'Cart',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CartPage(
                        cartService: cartService,
                        authService: widget.authService,
                      ),
                    ),
                  ).then((_) {
                    if (mounted) setState(() {});
                  });
                },
                icon: const Icon(Icons.shopping_cart_outlined),
              ),
              if (cartService.items.isNotEmpty)
                Positioned(
                  right: 5,
                  top: 4,
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: Colors.green,
                    child: Text(
                      '${cartService.items.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_refresh);
          await productsFuture;
        },
        child: FutureBuilder<List<Product>>(
          future: productsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Unable to load products.\n${snapshot.error}'),
              );
            }

            final products = snapshot.data ?? [];
            return FutureBuilder<List<dynamic>>(
              future: categoriesFuture,
              builder: (context, categorySnapshot) {
                final categories = categorySnapshot.data ?? [];
                final query = search.text.trim().toLowerCase();
                final filtered = products.where((product) {
                  return (query.isEmpty ||
                          product.name.toLowerCase().contains(query)) &&
                      (selectedCategory == null ||
                          product.categoryId == selectedCategory) &&
                      (maxPrice == null || product.price <= maxPrice!);
                }).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF2E7D32),
                            Color(0xFF78A95B),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fresh groceries, delivered to you.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Shop fresh vegetables, fruits and everyday essentials.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search vegetables, fruits...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          onPressed: () => _showFilters(products),
                          icon: const Icon(Icons.tune),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Shop by Category',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (categorySnapshot.connectionState ==
                        ConnectionState.waiting)
                      const LinearProgressIndicator()
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: selectedCategory == null,
                            onSelected: (_) {
                              setState(() => selectedCategory = null);
                            },
                          ),
                          ...categories.map((category) {
                            final id = (category['id'] as num).toInt();
                            return ChoiceChip(
                              label: Text(category['name']),
                              selected: selectedCategory == id,
                              onSelected: (_) {
                                setState(() => selectedCategory = id);
                              },
                            );
                          }),
                        ],
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Available Products',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '${filtered.length} items',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text('No products match your search.'),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 260,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.76,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _productCard(filtered[index]);
                        },
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
