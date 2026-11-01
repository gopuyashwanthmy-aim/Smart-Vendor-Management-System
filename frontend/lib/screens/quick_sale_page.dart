import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class QuickSalePage extends StatefulWidget {
  final AuthService authService;

  const QuickSalePage({
    super.key,
    required this.authService,
  });

  @override
  State<QuickSalePage> createState() => _QuickSalePageState();
}

class _QuickSalePageState extends State<QuickSalePage> {
  List<Product> _products = [];

  Product? _selectedProduct;

  final quantityController = TextEditingController();
  final priceController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  double get _quantity {
    return double.tryParse(quantityController.text) ?? 0;
  }

  double get _price {
    return double.tryParse(priceController.text) ?? 0;
  }

  double get _total {
    return _quantity * _price;
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();

    quantityController.addListener(_refreshTotal);
    priceController.addListener(_refreshTotal);
  }

  void _refreshTotal() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadProducts() async {
    try {
      final products = await ApiService.getProducts();

      if (!mounted) return;

      setState(() {
        _products = products;
        _loading = false;

        if (products.isNotEmpty) {
          _selectedProduct = products.first;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load products: $e'),
        ),
      );
    }
  }

  Future<void> _recordSale() async {
    final token = widget.authService.token;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication token not found'),
        ),
      );
      return;
    }

    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a product'),
        ),
      );
      return;
    }

    final quantity = double.tryParse(
      quantityController.text.trim(),
    );

    final sellingPrice = double.tryParse(
      priceController.text.trim(),
    );

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid quantity'),
        ),
      );
      return;
    }

    if (sellingPrice == null || sellingPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid selling price'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await ApiService.createSale(
        productId: _selectedProduct!.id,
        quantity: quantity,
        sellingPrice: sellingPrice,
        token: token,
      );

      if (!mounted) return;

      quantityController.clear();
      priceController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Walk-in sale recorded successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to record sale: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    quantityController.dispose();
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Sale'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 500,
                  ),
                  child: Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.point_of_sale,
                            size: 64,
                          ),

                          const SizedBox(height: 16),

                          const Text(
                            'Record Walk-in Sale',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            'Record a direct sale to a customer who did not place an online order.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),

                          const SizedBox(height: 30),

                          DropdownButtonFormField<Product>(
                            initialValue: _selectedProduct,
                            decoration: const InputDecoration(
                              labelText: 'Product',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.shopping_basket,
                              ),
                            ),
                            items: _products
                                .map<DropdownMenuItem<Product>>(
                              (product) {
                                return DropdownMenuItem<Product>(
                                  value: product,
                                  child: Text(
                                    '${product.name} (${product.unit})',
                                  ),
                                );
                              },
                            ).toList(),
                            onChanged: _saving
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedProduct = value;
                                    });
                                  },
                          ),

                          const SizedBox(height: 18),

                          TextField(
                            controller: quantityController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              hintText: 'Example: 2',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.scale,
                              ),
                            ),
                            enabled: !_saving,
                          ),

                          const SizedBox(height: 18),

                          TextField(
                            controller: priceController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Selling Price',
                              hintText: 'Price per unit',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.currency_rupee,
                              ),
                            ),
                            enabled: !_saving,
                          ),

                          const SizedBox(height: 24),

                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'TOTAL SALE AMOUNT',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  '₹${_total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          SizedBox(
                            height: 50,
                            child: FilledButton.icon(
                              onPressed:
                                  _saving ? null : _recordSale,
                              icon: _saving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.check,
                                    ),
                              label: Text(
                                _saving
                                    ? 'Recording Sale...'
                                    : 'Record Sale',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}