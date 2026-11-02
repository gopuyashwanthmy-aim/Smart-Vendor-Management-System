
import 'dart:async';

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
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    _loadOrders();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) {
        _loadOrders(showError: false);
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders({
    bool showError = true,
  }) async {
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

      if (showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load orders: $e'),
          ),
        );
      }
    }
  }

  List<dynamic> get _activeOrders {
    return _orders.where((order) {
      return order['status'] != 'DELIVERED';
    }).toList();
  }

  List<dynamic> get _completedOrders {
    return _orders.where((order) {
      return order['status'] == 'DELIVERED';
    }).toList();
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
    final amount = double.tryParse(value.toString()) ?? 0;
    return '₹${amount.toStringAsFixed(2)}';
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Date unavailable';

    try {
      final date = DateTime.parse(value.toString()).toLocal();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;

      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '$day/$month/$year • $hour:$minute $period';
    } catch (_) {
      return 'Date unavailable';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Orders'),
          actions: [
            IconButton(
              tooltip: 'Refresh orders',
              onPressed: _loading
                  ? null
                  : () => _loadOrders(),
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.local_shipping_outlined),
                text: 'Active Orders (${_activeOrders.length})',
              ),
              Tab(
                icon: const Icon(Icons.history),
                text: 'Order History (${_completedOrders.length})',
              ),
            ],
          ),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : TabBarView(
                children: [
                  _buildOrdersList(_activeOrders, completed: false),
                  _buildOrdersList(_completedOrders, completed: true),
                ],
              ),
      ),
    );
  }

  Widget _buildOrdersList(
    List<dynamic> orders, {
    required bool completed,
  }) {
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: orders.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 130),
                Icon(
                  completed
                      ? Icons.receipt_long_outlined
                      : Icons.shopping_bag_outlined,
                  size: 65,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    completed
                        ? 'No completed orders yet.'
                        : 'No active orders.',
                    style: const TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index] as Map<String, dynamic>;

                return _buildOrderCard(
                  order,
                  completed: completed,
                );
              },
            ),
    );
  }

  Widget _buildOrderCard(
    Map<String, dynamic> order, {
    required bool completed,
  }) {
    final status = (order['status'] ?? 'UNKNOWN').toString();

    final items = order['items'] as List<dynamic>? ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Order #${order['id']}',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(status),
                  backgroundColor: _statusColor(status).withOpacity(0.12),
                  labelStyle: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.bold,
                  ),
                  side: BorderSide.none,
                ),
              ],
            ),

            const SizedBox(height: 5),

            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: Colors.grey,
                ),
                const SizedBox(width: 7),
                Text(
                  _formatDate(order['created_at']),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),

            const Divider(height: 25),

            ...items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item['product_name']} × ${item['quantity']}',
                      ),
                    ),
                    Text(
                      _money(item['total']),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),

            const Divider(height: 25),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _money(order['total_amount']),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            if (!completed) ...[
              const SizedBox(height: 22),

              const Text(
                'Order Tracking',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              _buildTrackingTimeline(status),
            ] else ...[
              const SizedBox(height: 12),

              const Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Order successfully delivered',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingTimeline(String currentStatus) {
    const statuses = [
      'PLACED',
      'CONFIRMED',
      'PURCHASING',
      'READY',
      'DELIVERED',
    ];

    final currentIndex = _statusIndex(currentStatus);

    return Column(
      children: List.generate(
        statuses.length,
        (index) {
          final status = statuses[index];
          final completed = index <= currentIndex;
          final isLast = index == statuses.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      color: completed ? Colors.white : Colors.grey,
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
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _prettyStatus(status),
                  style: TextStyle(
                    fontWeight: completed
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: completed ? null : Colors.grey,
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
