import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class InventoryPage extends StatefulWidget {
  final AuthService authService;

  const InventoryPage({
    super.key,
    required this.authService,
  });

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<dynamic> _inventory = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    try {
      final token = widget.authService.token;

      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final data = await ApiService.getInventory(token);

      if (!mounted) return;

      setState(() {
        _inventory = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load inventory: $e'),
        ),
      );
    }
  }

  Future<void> _showAddPurchaseDialog() async {
    final token = widget.authService.token;

    if (token == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication token not found'),
        ),
      );
      return;
    }

    // Capture the messenger before any async gap.
    final messenger = ScaffoldMessenger.of(context);

    try {
      final products = await ApiService.getProducts();

      if (!mounted) return;

      if (products.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No products available'),
          ),
        );
        return;
      }

      Product selectedProduct = products.first;

      final purchasedController = TextEditingController();
      final purchaseCostController = TextEditingController();
      final reservedController = TextEditingController();

      bool saving = false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final purchased =
                  double.tryParse(purchasedController.text.trim()) ?? 0;

              final purchaseCost =
                  double.tryParse(purchaseCostController.text.trim()) ?? 0;

              final totalCost = purchased * purchaseCost;

              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.add_shopping_cart),
                    SizedBox(width: 10),
                    Text('Add Purchase'),
                  ],
                ),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<Product>(
                          initialValue: selectedProduct,
                          decoration: const InputDecoration(
                            labelText: 'Product',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.inventory_2),
                          ),
                          items: products.map<DropdownMenuItem<Product>>(
                            (Product product) {
                              return DropdownMenuItem<Product>(
                                value: product,
                                child: Text(
                                  '${product.name} (${product.unit})',
                                ),
                              );
                            },
                          ).toList(),
                          onChanged: saving
                              ? null
                              : (Product? value) {
                                  if (value != null) {
                                    setDialogState(() {
                                      selectedProduct = value;
                                    });
                                  }
                                },
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: purchasedController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Purchased Quantity',
                            hintText: 'Example: 20',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.shopping_basket),
                          ),
                          enabled: !saving,
                          onChanged: (_) {
                            setDialogState(() {});
                          },
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: purchaseCostController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText:
                                'Purchase Cost / ${selectedProduct.unit}',
                            hintText: 'Example: 25',
                            prefixText: '₹ ',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.currency_rupee),
                          ),
                          enabled: !saving,
                          onChanged: (_) {
                            setDialogState(() {});
                          },
                        ),

                        const SizedBox(height: 12),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(dialogContext)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Purchase Cost',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '₹${totalCost.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: reservedController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Reserved Quantity',
                            hintText: 'Example: 15',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.bookmark),
                          ),
                          enabled: !saving,
                        ),

                        const SizedBox(height: 12),

                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Remaining quantity = Purchased - Reserved',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),

                        const SizedBox(height: 4),

                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Purchase cost is the amount paid to buy the stock.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () {
                            Navigator.pop(dialogContext);
                          },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            final purchasedText =
                                purchasedController.text.trim();

                            final purchaseCostText =
                                purchaseCostController.text.trim();

                            final reservedText =
                                reservedController.text.trim();

                            final purchased =
                                double.tryParse(purchasedText);

                            final purchaseCost =
                                double.tryParse(purchaseCostText);

                            final reserved =
                                double.tryParse(reservedText);

                            if (purchased == null || purchased <= 0) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Enter a valid purchased quantity',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (purchaseCost == null || purchaseCost <= 0) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Enter a valid purchase cost',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (reserved == null || reserved < 0) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Enter a valid reserved quantity',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (reserved > purchased) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Reserved quantity cannot exceed purchased quantity',
                                  ),
                                ),
                              );
                              return;
                            }

                            setDialogState(() {
                              saving = true;
                            });

                            try {
                              await ApiService.addInventory(
                                productId: selectedProduct.id,
                                purchasedQuantity: purchased,
                                purchaseCostPerUnit: purchaseCost,
                                reservedQuantity: reserved,
                                token: token,
                              );

                              if (!dialogContext.mounted) return;

                              Navigator.pop(dialogContext);

                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Purchase added successfully',
                                  ),
                                ),
                              );

                              await _loadInventory();
                            } catch (e) {
                              if (!dialogContext.mounted) return;

                              setDialogState(() {
                                saving = false;
                              });

                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to add purchase: $e',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      saving ? 'Saving...' : 'Add Purchase',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      purchasedController.dispose();
      purchaseCostController.dispose();
      reservedController.dispose();
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to load products: $e'),
        ),
      );
    }
  }

  String _formatNumber(dynamic value) {
    final number = double.tryParse(value.toString()) ?? 0;

    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number.toStringAsFixed(2);
  }

  String _formatCurrency(dynamic value) {
    final number = double.tryParse(value.toString()) ?? 0;
    return '₹${number.toStringAsFixed(2)}';
  }

  Color _remainingColor(double remaining) {
    if (remaining <= 0) {
      return Colors.red;
    }

    if (remaining <= 5) {
      return Colors.orange;
    }

    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadInventory,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPurchaseDialog,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Add Purchase'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _inventory.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No inventory records yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Use "Add Purchase" to record stock.',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadInventory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _inventory.length,
                    itemBuilder: (context, index) {
                      final item = _inventory[index];

                      final productName =
                          item['product_name']?.toString() ??
                              'Unknown Product';

                      final unit =
                          item['unit']?.toString() ?? '';

                      final purchased =
                          double.tryParse(
                                item['purchased_quantity'].toString(),
                              ) ??
                              0;

                      final purchaseCost =
                          double.tryParse(
                                item['purchase_cost_per_unit'].toString(),
                              ) ??
                              0;

                      final totalPurchaseCost =
                          double.tryParse(
                                item['total_purchase_cost'].toString(),
                              ) ??
                              (purchased * purchaseCost);

                      final reserved =
                          double.tryParse(
                                item['reserved_quantity'].toString(),
                              ) ??
                              0;

                      final remaining =
                          double.tryParse(
                                item['remaining_quantity'].toString(),
                              ) ??
                              0;

                      final remainingColor =
                          _remainingColor(remaining);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.inventory_2,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      productName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _financialBox(
                                        title: 'Cost / $unit',
                                        value:
                                            _formatCurrency(purchaseCost),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _financialBox(
                                        title: 'Total Cost',
                                        value:
                                            _formatCurrency(
                                          totalPurchaseCost,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Expanded(
                                    child: _quantityBox(
                                      title: 'Purchased',
                                      value:
                                          _formatNumber(purchased),
                                      unit: unit,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _quantityBox(
                                      title: 'Reserved',
                                      value:
                                          _formatNumber(reserved),
                                      unit: unit,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _quantityBox(
                                      title: 'Remaining',
                                      value:
                                          _formatNumber(remaining),
                                      unit: unit,
                                      valueColor:
                                          remainingColor,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              LinearProgressIndicator(
                                value: purchased > 0
                                    ? (remaining / purchased)
                                        .clamp(0.0, 1.0)
                                    : 0,
                              ),

                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  Icon(
                                    remaining <= 0
                                        ? Icons.error_outline
                                        : remaining <= 5
                                            ? Icons.warning_amber
                                            : Icons.check_circle_outline,
                                    size: 18,
                                    color: remainingColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    remaining <= 0
                                        ? 'Stock exhausted'
                                        : remaining <= 5
                                            ? 'Low stock'
                                            : 'Stock available',
                                    style: TextStyle(
                                      color: remainingColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _financialBox({
    required String title,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _quantityBox({
    required String title,
    required String value,
    required String unit,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          if (unit.isNotEmpty)
            Text(
              unit,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
        ],
      ),
    );
  }
}