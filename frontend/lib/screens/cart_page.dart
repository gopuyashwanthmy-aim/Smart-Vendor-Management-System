import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';

class CartPage extends StatefulWidget {
  final CartService cartService;
  final AuthService authService;

  const CartPage({
    super.key,
    required this.cartService,
    required this.authService,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool placingOrder = false;

  Future<void> checkout() async {
    if (widget.cartService.items.isEmpty) {
      return;
    }

    final token = widget.authService.token;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login again.'),
        ),
      );
      return;
    }

    setState(() {
      placingOrder = true;
    });

    try {
      final result = await ApiService.createOrder(
        items: widget.cartService.items,
        token: token,
      );

      if (!mounted) return;

      widget.cartService.clear();

      await showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('Order Placed 🎉'),
            content: Text(
              'Order #${result['order_id']} created successfully.\n\n'
              'Total: ₹${result['total_amount']}\n'
              'Status: ${result['status']}',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to place order: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          placingOrder = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cartService;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🛒 My Cart'),
      ),
      body: cart.items.isEmpty
          ? const Center(
              child: Text(
                'Your cart is empty',
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];

                      return Card(
                        margin: const EdgeInsets.only(
                          bottom: 12,
                        ),
                        child: ListTile(
                          title: Text(
                            item.product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '₹${item.product.price.toStringAsFixed(2)} / ${item.product.unit}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    cart.decreaseQuantity(
                                      item.product,
                                    );
                                  });
                                },
                                icon: const Icon(
                                  Icons.remove,
                                ),
                              ),
                              Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    cart.increaseQuantity(
                                      item.product,
                                    );
                                  });
                                },
                                icon: const Icon(
                                  Icons.add,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '₹${item.totalPrice.toStringAsFixed(2)}',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '₹${cart.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      FilledButton(
                        onPressed:
                            placingOrder ? null : checkout,
                        child: placingOrder
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Checkout'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}