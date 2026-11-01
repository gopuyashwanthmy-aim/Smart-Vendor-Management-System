import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

class SalesHistoryPage extends StatefulWidget {
  final AuthService authService;

  const SalesHistoryPage({
    super.key,
    required this.authService,
  });

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  List<dynamic> _sales = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    try {
      final token = widget.authService.token;

      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final sales = await ApiService.getSales(token);

      if (!mounted) return;

      setState(() {
        _sales = sales;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load sales: $e'),
        ),
      );
    }
  }

  double get _totalRevenue {
    double total = 0;

    for (final sale in _sales) {
      total += double.tryParse(
            sale['total_amount'].toString(),
          ) ??
          0;
    }

    return total;
  }

  String _money(dynamic value) {
    final amount = double.tryParse(value.toString()) ?? 0;
    return '₹${amount.toStringAsFixed(2)}';
  }

  String _quantity(dynamic value) {
    final quantity = double.tryParse(value.toString()) ?? 0;

    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }

    return quantity.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadSales,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                _buildRevenueCard(),

                const SizedBox(height: 8),

                Expanded(
                  child: _sales.isEmpty
                      ? RefreshIndicator(
                          onRefresh: _loadSales,
                          child: ListView(
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 200),
                              Center(
                                child: Text(
                                  'No walk-in sales yet.',
                                  style: TextStyle(
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadSales,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _sales.length,
                            itemBuilder: (context, index) {
                              final sale = _sales[index];

                              final productName =
                                  sale['product_name']
                                          ?.toString() ??
                                      'Unknown Product';

                              final unit =
                                  sale['unit']?.toString() ?? '';

                              return Card(
                                margin: const EdgeInsets.only(
                                  bottom: 12,
                                ),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(
                                      Icons.point_of_sale,
                                    ),
                                  ),
                                  title: Text(
                                    productName,
                                    style: const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${_quantity(sale['quantity'])} '
                                    '$unit × '
                                    '${_money(sale['selling_price'])}',
                                  ),
                                  trailing: Text(
                                    _money(
                                      sale['total_amount'],
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildRevenueCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.currency_rupee,
            size: 42,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Walk-in Revenue',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _money(_totalRevenue),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_sales.length} sale${_sales.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}