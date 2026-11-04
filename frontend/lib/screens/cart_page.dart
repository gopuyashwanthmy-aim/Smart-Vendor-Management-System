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
    if (widget.cartService.items.isEmpty) return;

    final token = widget.authService.token;
    if (token == null) {
      _msg('Please login again.');
      return;
    }

    List<dynamic> addresses;
    try {
      addresses = await ApiService.getCustomerAddresses(token);
    } catch (e) {
      if (mounted) _msg('Could not load delivery addresses: $e');
      return;
    }

    if (!mounted) return;
    if (addresses.isEmpty) {
      _msg('Please add a delivery address from the menu before placing an order.');
      return;
    }

    final defaultAddress = addresses.firstWhere(
      (address) => address['is_default'] == true,
      orElse: () => addresses.first,
    );

    int? addressId = (defaultAddress['id'] as num).toInt();
    bool schedule = false;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String slot = '9:00 AM - 12:00 PM';

    const slots = [
      '9:00 AM - 12:00 PM',
      '12:00 PM - 3:00 PM',
      '3:00 PM - 6:00 PM',
      '6:00 PM - 9:00 PM',
    ];

    final choice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Delivery details'),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Delivery address'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: addressId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: addresses.map((address) {
                          final id = (address['id'] as num).toInt();
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(
                              '${address['label']} · ${address['address_line']}, ${address['city']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => addressId = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Schedule delivery'),
                        subtitle: const Text(
                          'Choose a date and convenient time slot',
                        ),
                        value: schedule,
                        onChanged: (value) {
                          setDialogState(() => schedule = value);
                        },
                        activeTrackColor: const Color(0xFF78A95B),
                      ),
                      if (schedule) ...[
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().add(
                                const Duration(days: 1),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 30),
                              ),
                            );
                            if (picked != null) {
                              setDialogState(() => selectedDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_month),
                          label: Text(
                            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: slot,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Delivery time slot',
                            border: OutlineInputBorder(),
                          ),
                          items: slots
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setDialogState(() => slot = value ?? slots.first);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );

    if (choice != true || !mounted) return;

    setState(() => placingOrder = true);
    try {
      DateTime? deliveryAt;
      if (schedule) {
        final hour = slot.startsWith('9:')
            ? 9
            : slot.startsWith('12:')
                ? 12
                : slot.startsWith('3:')
                    ? 15
                    : 18;
        deliveryAt = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          hour,
        );
      }

      final result = await ApiService.createOrder(
        items: widget.cartService.items,
        token: token,
        deliveryAddressId: addressId,
        scheduledDeliveryAt: deliveryAt,
        deliverySlot: schedule ? slot : null,
      );

      if (!mounted) return;
      widget.cartService.clear();

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Order Placed 🎉'),
          content: Text(
            'Order #${result['order_id']} created successfully.\n\n'
            'Total: ₹${result['total_amount']}\n'
            'Status: ${result['status']}\n'
            '${schedule ? 'Delivery: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year} · $slot' : 'Delivery: As soon as possible'}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _msg('Failed to place order: $e');
    } finally {
      if (mounted) setState(() => placingOrder = false);
    }
  }

  void _msg(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cartService;

    return Scaffold(
      appBar: AppBar(title: const Text('🛒 My Cart')),
      body: cart.items.isEmpty
          ? const Center(
              child: Text(
                'Your cart is empty',
                style: TextStyle(fontSize: 20),
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
                                onPressed: () => setState(
                                  () => cart.decreaseQuantity(item.product),
                                ),
                                icon: const Icon(Icons.remove),
                              ),
                              Text('${item.quantity}'),
                              IconButton(
                                onPressed: () => setState(
                                  () => cart.increaseQuantity(item.product),
                                ),
                                icon: const Icon(Icons.add),
                              ),
                              const SizedBox(width: 8),
                              Text('₹${item.totalPrice.toStringAsFixed(2)}'),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 16)),
                          Text(
                            '₹${cart.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      FilledButton.icon(
                        onPressed: placingOrder ? null : checkout,
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: placingOrder
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
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
