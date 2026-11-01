import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

class MyOrdersPage extends StatefulWidget {
  final AuthService authService;

  const MyOrdersPage({
    super.key,
    required this.authService,
  });

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  List<dynamic> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final token = widget.authService.token;

      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final orders = await ApiService.getMyOrders(token);

      if (!mounted) return;

      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load orders: $e',
          ),
        ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PLACED':
        return Colors.orange;

      case 'CONFIRMED':
        return Colors.blue;

      case 'PURCHASING':
        return Colors.purple;

      case 'READY':
        return Colors.teal;

      case 'DELIVERED':
        return Colors.green;

      default:
        return Colors.grey;
    }
  }

  int _statusIndex(String status) {
    switch (status) {
      case 'PLACED':
        return 0;
      case 'CONFIRMED':
        return 1;
      case 'PURCHASING':
        return 2;
      case 'READY':
        return 3;
      case 'DELIVERED':
        return 4;
      default:
        return 0;
    }
  }

  String _money(dynamic value) {
    final amount =
        double.tryParse(value.toString()) ?? 0;

    return '₹${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadOrders,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _orders.isEmpty
              ? RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 220),
                      Center(
                        child: Text(
                          'You have no orders yet.',
                          style: TextStyle(
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final order = _orders[index];

                      return _buildOrderCard(order);
                    },
                  ),
                ),
    );
  }

  Widget _buildOrderCard(
    Map<String, dynamic> order,
  ) {
    final status = order['status'].toString();

    final items =
        order['items'] as List<dynamic>;

    return Card(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order['id']}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(status),
                  side: BorderSide.none,
                ),
              ],
            ),

            const SizedBox(height: 12),

            ...items.map(
              (item) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 5,
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item['product_name']} × '
                          '${item['quantity']}',
                        ),
                      ),
                      Text(
                        _money(item['total']),
                      ),
                    ],
                  ),
                );
              },
            ),

            const Divider(),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _money(order['total_amount']),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            const Text(
              'Order Tracking',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            _buildTrackingTimeline(status),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingTimeline(
    String currentStatus,
  ) {
    const statuses = [
      'PLACED',
      'CONFIRMED',
      'PURCHASING',
      'READY',
      'DELIVERED',
    ];

    final currentIndex =
        _statusIndex(currentStatus);

    return Column(
      children: List.generate(
        statuses.length,
        (index) {
          final status = statuses[index];

          final completed =
              index <= currentIndex;

          final isLast =
              index == statuses.length - 1;

          return Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: completed
                          ? _statusColor(status)
                          : Colors.grey.shade300,
                    ),
                    child: Icon(
                      completed
                          ? Icons.check
                          : Icons.circle_outlined,
                      size: 16,
                      color: completed
                          ? Colors.white
                          : Colors.grey,
                    ),
                  ),

                  if (!isLast)
                    Container(
                      width: 2,
                      height: 34,
                      color: index < currentIndex
                          ? _statusColor(status)
                          : Colors.grey.shade300,
                    ),
                ],
              ),

              const SizedBox(width: 12),

              Padding(
                padding:
                    const EdgeInsets.only(top: 4),
                child: Text(
                  _prettyStatus(status),
                  style: TextStyle(
                    fontWeight:
                        completed
                            ? FontWeight.bold
                            : FontWeight.normal,
                    color: completed
                        ? null
                        : Colors.grey,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _prettyStatus(String status) {
    switch (status) {
      case 'PLACED':
        return 'Order Placed';

      case 'CONFIRMED':
        return 'Order Confirmed';

      case 'PURCHASING':
        return 'Vendor Purchasing';

      case 'READY':
        return 'Ready for Delivery';

      case 'DELIVERED':
        return 'Delivered';

      default:
        return status;
    }
  }
}