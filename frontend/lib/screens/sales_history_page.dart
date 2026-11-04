
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
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  double _number(dynamic value) {
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(dynamic value) {
    return '₹${_number(value).toStringAsFixed(2)}';
  }

  String _quantity(dynamic value) {
    final quantity = _number(value);

    return quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(2);
  }

  Future<void> _loadSales() async {
    setState(() => _loading = true);

    try {
      final token = widget.authService.token;

      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final results = await Future.wait([
        ApiService.getSales(token),
        ApiService.getAdminOrders(token),
      ]);

      final walkInSales = results[0];
      final onlineOrders = results[1];

      final List<Map<String, dynamic>> combined = [];

      // Walk-in transactions
      for (final sale in walkInSales) {
        combined.add({
          'type': 'WALK_IN',
          'id': sale['id'],
          'date': sale['created_at'],
          'total_amount': sale['total_amount'],
          'cogs': sale['cost_of_goods_sold'],
          'profit': sale['profit'],
          'items': [
            {
              'product_name': sale['product_name'] ?? 'Unknown Product',
              'quantity': sale['quantity'],
              'price': sale['selling_price'],
              'total': sale['total_amount'],
              'unit': sale['unit'] ?? '',
            }
          ],
        });
      }

      // Only delivered online orders count as completed sales.
      for (final order in onlineOrders) {
        if (order['status']?.toString().toUpperCase() != 'DELIVERED') {
          continue;
        }

        final items = (order['items'] as List<dynamic>? ?? []);

        final totalCogs = items.fold<double>(
          0,
          (sum, item) =>
              sum + _number(item['cost_of_goods_sold']),
        );

        final totalProfit = items.fold<double>(
          0,
          (sum, item) => sum + _number(item['profit']),
        );

        combined.add({
          'type': 'ONLINE',
          'id': order['id'],
          'date': order['created_at'],
          'customer': order['customer']?['name'] ?? 'Customer',
          'phone': order['customer']?['phone'] ?? '',
          'total_amount': order['total_amount'],
          'cogs': totalCogs,
          'profit': totalProfit,
          'items': items,
        });
      }

      combined.sort((a, b) {
        final dateA = DateTime.tryParse(a['date']?.toString() ?? '') ??
            DateTime(2000);

        final dateB = DateTime.tryParse(b['date']?.toString() ?? '') ??
            DateTime(2000);

        return dateB.compareTo(dateA);
      });

      if (!mounted) return;

      setState(() {
        _transactions = combined;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load sales: $e'),
        ),
      );
    }
  }

  double get _totalRevenue {
    return _transactions.fold<double>(
      0,
      (sum, sale) => sum + _number(sale['total_amount']),
    );
  }

  double get _totalCogs {
    return _transactions.fold<double>(
      0,
      (sum, sale) => sum + _number(sale['cogs']),
    );
  }

  double get _totalProfit {
    return _transactions.fold<double>(
      0,
      (sum, sale) => sum + _number(sale['profit']),
    );
  }

  int get _onlineCount =>
      _transactions.where((s) => s['type'] == 'ONLINE').length;

  int get _walkInCount =>
      _transactions.where((s) => s['type'] == 'WALK_IN').length;

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');

    if (date == null) return 'Date unavailable';

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}  '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
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
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSales,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 16),
                  _buildTransactionCounts(),
                  const SizedBox(height: 20),
                  const Text(
                    'Transaction History',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text('No completed sales found.'),
                      ),
                    )
                  else
                    ..._transactions.map(_buildTransactionCard),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total Revenue',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 5),
            Text(
              _money(_totalRevenue),
              style: const TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const Divider(height: 25),
            _summaryRow('Cost of Goods Sold', _money(_totalCogs)),
            const SizedBox(height: 10),
            _summaryRow('Gross Profit', _money(_totalProfit)),
            const SizedBox(height: 10),
            _summaryRow(
              'Profit Margin',
              '${_totalRevenue > 0
                  ? (_totalProfit / _totalRevenue * 100).toStringAsFixed(2)
                  : '0.00'}%',
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildTransactionCounts() {
    return Row(
      children: [
        Expanded(
          child: _countCard(
            'Online Orders',
            _onlineCount,
            Icons.shopping_bag_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _countCard(
            'Walk-in Sales',
            _walkInCount,
            Icons.storefront,
          ),
        ),
      ],
    );
  }

  Widget _countCard(String title, int count, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: Colors.green, size: 28),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final isOnline = transaction['type'] == 'ONLINE';
    final items = transaction['items'] as List<dynamic>? ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isOnline ? Icons.shopping_bag : Icons.storefront,
                  color: Colors.green,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    isOnline
                        ? 'Online Order #${transaction['id']}'
                        : 'Walk-in Sale #${transaction['id']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                _typeBadge(isOnline),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Date: ${_formatDate(transaction['date'])}',
              style: const TextStyle(color: Colors.grey),
            ),
            if (isOnline) ...[
              const SizedBox(height: 5),
              Text('Customer: ${transaction['customer']}'),
              Text('Phone: ${transaction['phone']}'),
            ],
            const Divider(height: 22),
            ...items.map((item) {
              final productName =
                  item['product_name'] ?? 'Unknown Product';

              final quantity = _quantity(item['quantity']);
              final price = _money(item['price']);
              final total = _money(
                item['total'] ?? item['revenue'],
              );

              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('$productName × $quantity'),
                    ),
                    Text('$price  |  $total'),
                  ],
                ),
              );
            }),
            const Divider(height: 18),
            _summaryRow(
              'Revenue',
              _money(transaction['total_amount']),
            ),
            const SizedBox(height: 6),
            _summaryRow(
              'COGS',
              _money(transaction['cogs']),
            ),
            const SizedBox(height: 6),
            _summaryRow(
              'Profit',
              _money(transaction['profit']),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: ${_money(transaction['total_amount'])}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeBadge(bool isOnline) {
    final color = isOnline ? Colors.blue : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOnline ? 'ONLINE' : 'WALK-IN',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
