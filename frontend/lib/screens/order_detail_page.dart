import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

class OrderDetailPage extends StatefulWidget {
  final AuthService authService;
  final int orderId;

  const OrderDetailPage({
    super.key,
    required this.authService,
    required this.orderId,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  bool _loading = true;
  bool _updating = false;
  String? _error;
  Map<String, dynamic>? _order;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final order = await ApiService.getAdminOrderDetails(
        orderId: widget.orderId,
        token: widget.authService.token!,
      );

      if (!mounted) return;

      setState(() {
        _order = order;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String? _nextStatus(String status) {
    switch (status) {
      case 'PLACED':
        return 'CONFIRMED';
      case 'CONFIRMED':
        return 'PURCHASING';
      case 'PURCHASING':
        return 'READY';
      case 'READY':
        return 'DELIVERED';
      default:
        return null;
    }
  }

  String _nextStatusLabel(String status) {
    switch (status) {
      case 'PLACED':
        return 'Confirm Order';
      case 'CONFIRMED':
        return 'Start Purchasing';
      case 'PURCHASING':
        return 'Mark Ready';
      case 'READY':
        return 'Mark Delivered';
      default:
        return 'Order Completed';
    }
  }

  IconData _nextStatusIcon(String status) {
    switch (status) {
      case 'PLACED':
        return Icons.check;
      case 'CONFIRMED':
        return Icons.shopping_cart;
      case 'PURCHASING':
        return Icons.inventory_2;
      case 'READY':
        return Icons.local_shipping;
      default:
        return Icons.check_circle;
    }
  }

  Future<void> _updateStatus() async {
    if (_order == null || _updating) return;

    final currentStatus =
        (_order!['status'] ?? '').toString();

    final nextStatus = _nextStatus(currentStatus);

    if (nextStatus == null) return;

    setState(() {
      _updating = true;
    });

    try {
      final updated =
          await ApiService.updateOrderStatus(
        orderId: widget.orderId,
        status: nextStatus,
        token: widget.authService.token!,
      );

      if (!mounted) return;

      setState(() {
        _order = {
          ..._order!,
          'status':
              updated['status'] ?? nextStatus,
        };
        _updating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order #${widget.orderId} updated to '
            '${updated['status'] ?? nextStatus}',
          ),
        ),
      );

      await _loadOrder();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _updating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update order: $e',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Order #${widget.orderId}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadOrder,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return _buildError();
    }

    if (_order == null) {
      return const Center(
        child: Text('Order not found.'),
      );
    }

    final order = _order!;
    final customer =
        (order['customer'] as Map<String, dynamic>?) ??
            {};
    final items =
        (order['items'] as List<dynamic>?) ?? [];

    final status =
        (order['status'] ?? 'UNKNOWN').toString();

    final total =
        _number(order['total_amount']);

    final createdAt =
        order['created_at']?.toString();

    return RefreshIndicator(
      onRefresh: _loadOrder,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildOrderHeader(
            status: status,
            total: total,
            createdAt: createdAt,
          ),
          const SizedBox(height: 16),
          _buildCustomerCard(customer),
          const SizedBox(height: 16),
          _buildItemsCard(items),
          const SizedBox(height: 16),
          _buildFinancialCard(items, total),
          const SizedBox(height: 16),
          _buildStatusCard(status),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOrderHeader({
    required String status,
    required double total,
    required String? createdAt,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              child: Text(
                '#${widget.orderId}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer Order',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    createdAt == null
                        ? 'Order date unavailable'
                        : 'Placed: ${_formatDate(createdAt)}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _statusChip(status),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '₹${_formatNumber(total)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(
    Map<String, dynamic> customer,
  ) {
    final name =
        customer['name']?.toString() ??
            'Unknown Customer';

    final phone =
        customer['phone']?.toString() ??
            'Phone unavailable';

    final id =
        customer['id']?.toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                phone,
              ),
            ),
            if (id != null) ...[
              const SizedBox(height: 4),
              Text(
                'Customer ID: $id',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard(
    List<dynamic> items,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Order Items',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${items.length} item${items.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 16,
                ),
                child: Text(
                  'No items found for this order.',
                ),
              )
            else
              ...items.map(
                (rawItem) {
                  final item =
                      rawItem as Map<String, dynamic>;

                  final productName =
                      item['product_name']
                              ?.toString() ??
                          'Unknown Product';

                  final quantity =
                      _number(item['quantity']);

                  final price =
                      _number(item['price']);

                  final lineTotal =
                      _number(
                    item['total'] ??
                        quantity * price,
                  );

                  return Container(
                    margin: const EdgeInsets.only(
                      bottom: 10,
                    ),
                    padding:
                        const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant,
                      ),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            borderRadius:
                                BorderRadius.circular(
                              10,
                            ),
                          ),
                          child: const Icon(
                            Icons.shopping_basket,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                productName,
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_formatNumber(quantity)} × '
                                '₹${_formatNumber(price)}',
                                style: TextStyle(
                                  color: Colors
                                      .grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${_formatNumber(lineTotal)}',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Order Total',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                Text(
                  '₹${_formatNumber(_number(_order?['total_amount']))}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 19,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialCard(
    List<dynamic> items,
    double total,
  ) {
    double revenue = 0;
    double cogs = 0;
    double profit = 0;

    for (final rawItem in items) {
      final item =
          rawItem as Map<String, dynamic>;

      revenue +=
          _number(item['revenue']);

      cogs +=
          _number(item['cost_of_goods_sold']);

      profit +=
          _number(item['profit']);
    }

    final financialRecorded =
        cogs > 0 || profit != 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (!financialRecorded)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 14,
                ),
                child: Text(
                  'Financial cost data will be recorded when the order is delivered.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            _financialRow(
              'Revenue',
              revenue > 0 ? revenue : total,
            ),
            _financialRow(
              'COGS',
              cogs,
            ),
            _financialRow(
              'Gross Profit',
              profit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _financialRow(
    String label,
    double value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '₹${_formatNumber(value)}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    String status,
  ) {
    final nextStatus =
        _nextStatus(status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatusTimeline(status),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    nextStatus == null ||
                            _updating
                        ? null
                        : _updateStatus,
                icon: _updating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        _nextStatusIcon(status),
                      ),
                label: Text(
                  _updating
                      ? 'Updating...'
                      : _nextStatusLabel(status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline(
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
        statuses.indexOf(currentStatus);

    return Column(
      children: List.generate(
        statuses.length,
        (index) {
          final status = statuses[index];
          final completed =
              currentIndex >= index;

          return Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 13,
                    child: completed
                        ? const Icon(
                            Icons.check,
                            size: 15,
                          )
                        : Text(
                            '${index + 1}',
                            style:
                                const TextStyle(
                              fontSize: 11,
                            ),
                          ),
                  ),
                  if (index <
                      statuses.length - 1)
                    Container(
                      width: 2,
                      height: 28,
                      color: completed
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                          : Theme.of(context)
                              .colorScheme
                              .outlineVariant,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Padding(
                padding:
                    const EdgeInsets.only(top: 5),
                child: Text(
                  status,
                  style: TextStyle(
                    fontWeight:
                        status == currentStatus
                            ? FontWeight.bold
                            : FontWeight.normal,
                    color:
                        status == currentStatus
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                            : null,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .secondaryContainer,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 52,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load order.',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loadOrder,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }

  String _formatDate(String value) {
    try {
      final parsed =
          DateTime.parse(value).toLocal();

      return '${parsed.day.toString().padLeft(2, '0')}/'
          '${parsed.month.toString().padLeft(2, '0')}/'
          '${parsed.year} '
          '${parsed.hour.toString().padLeft(2, '0')}:'
          '${parsed.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value;
    }
  }
}
