import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

class FinancialDashboardPage extends StatefulWidget {
  final AuthService authService;

  const FinancialDashboardPage({
    super.key,
    required this.authService,
  });

  @override
  State<FinancialDashboardPage> createState() =>
      _FinancialDashboardPageState();
}

class _FinancialDashboardPageState
    extends State<FinancialDashboardPage> {
  late Future<Map<String, dynamic>> financialFuture;

  DateTime _startDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadFinancialData();
  }

  void _loadFinancialData() {
    financialFuture = ApiService.getFinancialSummary(
      token: widget.authService.token!,
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _loadFinancialData();
    });

    try {
      await financialFuture;
    } catch (_) {}
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _money(dynamic value) {
    final number = double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;

    return '₹${number.toStringAsFixed(2)}';
  }

  double _number(dynamic value) {
    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  Future<void> _selectStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selected == null) return;

    if (selected.isAfter(_endDate)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Start date cannot be after end date.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _startDate = selected;
      _loadFinancialData();
    });
  }

  Future<void> _selectEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );

    if (selected == null) return;

    setState(() {
      _endDate = selected;
      _loadFinancialData();
    });
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    String? subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
              ),
              child: Icon(
                icon,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueBreakdown(
    Map<String, dynamic> data,
  ) {
    final onlineRevenue =
        _number(data['online_revenue']);

    final walkInRevenue =
        _number(data['walk_in_revenue']);

    final totalRevenue =
        _number(data['total_revenue']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Revenue Breakdown',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildBreakdownRow(
              'Online Orders',
              onlineRevenue,
              totalRevenue,
              Icons.shopping_cart_outlined,
            ),
            const SizedBox(height: 16),
            _buildBreakdownRow(
              'Walk-in Sales',
              walkInRevenue,
              totalRevenue,
              Icons.storefront_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(
    String title,
    double amount,
    double total,
    IconData icon,
  ) {
    final percentage =
        total > 0 ? (amount / total) * 100 : 0;

    return Column(
      children: [
        Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              _money(amount),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: total > 0 ? amount / total : 0,
          minHeight: 8,
          borderRadius:
              BorderRadius.circular(10),
        ),
        const SizedBox(height: 5),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCostBreakdown(
    Map<String, dynamic> data,
  ) {
    final onlineCogs =
        _number(data['online_cogs']);

    final walkInCogs =
        _number(data['walk_in_cogs']);

    final totalCogs =
        _number(data['total_cogs']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Cost of Goods Sold',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.shopping_cart_outlined,
              ),
              title: const Text(
                'Online COGS',
              ),
              trailing: Text(
                _money(onlineCogs),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.storefront_outlined,
              ),
              title: const Text(
                'Walk-in COGS',
              ),
              trailing: Text(
                _money(walkInCogs),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Total COGS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: Text(
                _money(totalCogs),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionSummary(
    Map<String, dynamic> data,
  ) {
    final online =
        data['online_transactions'] ?? 0;

    final walkIn =
        data['walk_in_transactions'] ?? 0;

    final total =
        data['total_transactions'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Transaction Summary',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _transactionItem(
                    'Online',
                    online.toString(),
                    Icons.shopping_cart,
                  ),
                ),
                Expanded(
                  child: _transactionItem(
                    'Walk-in',
                    walkIn.toString(),
                    Icons.storefront,
                  ),
                ),
                Expanded(
                  child: _transactionItem(
                    'Total',
                    total.toString(),
                    Icons.receipt_long,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionItem(
    String title,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(title),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Financial Management',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: financialFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Failed to load financial data.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign:
                          TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(
                        Icons.refresh,
                      ),
                      label:
                          const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data =
              snapshot.data ?? {};

          final totalRevenue =
              _number(data['total_revenue']);

          final totalCogs =
              _number(data['total_cogs']);

          final grossProfit =
              _number(data['gross_profit']);

          final profitMargin =
              _number(data['profit_margin']);

          final width =
              MediaQuery.of(context)
                  .size
                  .width;

          int columns;

          if (width >= 1200) {
            columns = 4;
          } else if (width >= 700) {
            columns = 2;
          } else {
            columns = 1;
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.all(16),
              children: [
                const Text(
                  'Business Financial Overview',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_formatDate(_startDate)} - '
                  '${_formatDate(_endDate)}',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 20),

                // DATE FILTER
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment:
                          WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed:
                              _selectStartDate,
                          icon: const Icon(
                            Icons.calendar_today,
                          ),
                          label: Text(
                            'From: ${_formatDate(_startDate)}',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              _selectEndDate,
                          icon: const Icon(
                            Icons.calendar_today,
                          ),
                          label: Text(
                            'To: ${_formatDate(_endDate)}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // MAIN METRICS
                GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio:
                      columns == 1 ? 3.0 : 1.65,
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  children: [
                    _buildMetricCard(
                      title: 'Total Revenue',
                      value:
                          _money(totalRevenue),
                      icon:
                          Icons.currency_rupee,
                    ),
                    _buildMetricCard(
                      title: 'Total COGS',
                      value:
                          _money(totalCogs),
                      icon:
                          Icons.shopping_basket_outlined,
                    ),
                    _buildMetricCard(
                      title: 'Gross Profit',
                      value:
                          _money(grossProfit),
                      icon:
                          Icons.trending_up,
                    ),
                    _buildMetricCard(
                      title: 'Profit Margin',
                      value:
                          '${profitMargin.toStringAsFixed(1)}%',
                      icon:
                          Icons.percent,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                _buildRevenueBreakdown(data),

                const SizedBox(height: 16),

                _buildCostBreakdown(data),

                const SizedBox(height: 16),

                _buildTransactionSummary(data),

                const SizedBox(height: 24),

                // FINANCIAL INTERPRETATION
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.insights,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Financial Insight',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          totalCogs == 0
                              ? 'Purchase costs have not been recorded for the transactions in this period. Gross profit therefore reflects revenue minus the currently recorded COGS.'
                              : 'The dashboard calculates gross profit from recorded revenue and cost of goods sold.',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }
}