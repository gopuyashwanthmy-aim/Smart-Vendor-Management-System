import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

class AiInsightsPage extends StatefulWidget {
  final AuthService authService;

  const AiInsightsPage({
    super.key,
    required this.authService,
  });

  @override
  State<AiInsightsPage> createState() => _AiInsightsPageState();
}

class _AiInsightsPageState extends State<AiInsightsPage> {
  late Future<Map<String, dynamic>> _insightsFuture;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  void _loadInsights() {
    final token = widget.authService.token;

    if (token == null || token.isEmpty) {
      _insightsFuture = Future.error(
        Exception('Admin authentication token is missing.'),
      );
      return;
    }

    _insightsFuture = ApiService.getAiInsights(token);
  }

  Future<void> _refresh() async {
    setState(() {
      _loadInsights();
    });

    try {
      await _insightsFuture;
    } catch (_) {
      // Error is displayed by the FutureBuilder.
    }
  }

  String _formatNumber(dynamic value) {
    final number = double.tryParse(value.toString()) ?? 0;

    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number.toStringAsFixed(2);
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return 'Not available';
    }

    final parsed = DateTime.tryParse(value.toString());

    if (parsed == null) {
      return value.toString();
    }

    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/'
        '${parsed.year}';
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ATTENTION_REQUIRED':
        return Colors.red;
      case 'PURCHASE_RECOMMENDED':
        return Colors.orange;
      case 'STABLE':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  IconData _insightIcon(String type) {
    switch (type) {
      case 'PURCHASE_REQUIRED':
        return Icons.shopping_cart;
      case 'LOW_STOCK':
        return Icons.inventory_2;
      case 'ORDER_PRESSURE':
        return Icons.receipt_long;
      case 'INVENTORY_SUFFICIENT':
        return Icons.check_circle;
      case 'NO_PURCHASE':
        return Icons.done_all;
      case 'FORECAST_UNAVAILABLE':
        return Icons.warning_amber;
      default:
        return Icons.auto_awesome;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 'HIGH PRIORITY';
      case 'medium':
        return 'MEDIUM';
      default:
        return 'LOW';
    }
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(Map<String, dynamic> insight) {
    final productName =
        insight['product_name']?.toString() ?? 'Product';

    final unit =
        insight['unit']?.toString() ?? '';

    final type =
        insight['insight_type']?.toString() ?? '';

    final priority =
        insight['priority']?.toString() ?? 'low';

    final title =
        insight['title']?.toString() ?? productName;

    final message =
        insight['message']?.toString() ?? '';

    final demandLevel =
        insight['demand_level']?.toString() ?? 'UNKNOWN';

    final forecast =
        Map<String, dynamic>.from(
      insight['forecast'] ?? {},
    );

    final hasRealForecast = forecast['status'] == 'available';

    final orders =
        Map<String, dynamic>.from(
      insight['orders'] ?? {},
    );

    final inventory =
        Map<String, dynamic>.from(
      insight['inventory'] ?? {},
    );

    final planning =
        Map<String, dynamic>.from(
      insight['planning'] ?? {},
    );

    final priorityColor = _priorityColor(priority);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------------------------------------------------
            // HEADER
            // -------------------------------------------------

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _insightIcon(type),
                    color: priorityColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildTag(
                            _priorityLabel(priority),
                            priorityColor,
                          ),
                          _buildTag(
                            'Demand: $demandLevel',
                            Colors.blue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // -------------------------------------------------
            // AI MESSAGE
            // -------------------------------------------------

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: priorityColor.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),

            const SizedBox(height: 18),

            // -------------------------------------------------
            // METRICS
            // -------------------------------------------------

            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 850
                    ? 4
                    : constraints.maxWidth >= 550
                        ? 2
                        : 1;

                final width = columns == 1
                    ? constraints.maxWidth
                    : (constraints.maxWidth -
                            ((columns - 1) * 12)) /
                        columns;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildMetricBox(
                      width: width,
                      title: hasRealForecast ? 'AI Forecast' : 'Forecast',
                      value:
                          '${_formatNumber(forecast['predicted_demand'])} $unit',
                      subtitle: hasRealForecast ? 'Real-data predicted demand' : 'Active orders only; no model forecast',
                      icon: Icons.auto_graph,
                    ),
                    _buildMetricBox(
                      width: width,
                      title: 'Confirmed Orders',
                      value:
                          '${_formatNumber(orders['confirmed_quantity'])} $unit',
                      subtitle: 'Active customer orders',
                      icon: Icons.receipt_long,
                    ),
                    _buildMetricBox(
                      width: width,
                      title: 'Available Stock',
                      value:
                          '${_formatNumber(inventory['available'])} $unit',
                      subtitle: 'Currently available',
                      icon: Icons.inventory_2,
                    ),
                    _buildMetricBox(
                      width: width,
                      title: 'Stock Gap',
                      value:
                          '${_formatNumber(planning['stock_gap'])} $unit',
                      subtitle: 'Additional requirement',
                      icon: Icons.trending_up,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 14),

            // -------------------------------------------------
            // DETAILS
            // -------------------------------------------------

            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text(
                'View AI analysis details',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                _buildDetailRow(
                  'Expected demand',
                  '${_formatNumber(planning['expected_demand'])} $unit',
                ),
                _buildDetailRow(
                  'Safety stock',
                  '${_formatNumber(planning['safety_stock'])} $unit',
                ),
                _buildDetailRow(
                  'Target stock',
                  '${_formatNumber(planning['target_stock'])} $unit',
                ),
                _buildDetailRow(
                  'Reserved inventory',
                  '${_formatNumber(inventory['reserved'])} $unit',
                ),
                _buildDetailRow(
                  'Total inventory position',
                  '${_formatNumber(inventory['total_position'])} $unit',
                ),
                _buildDetailRow(
                  'Forecast date',
                  _formatDate(forecast['forecast_date']),
                ),
                _buildDetailRow(
                  'Model',
                  forecast['model']?.toString() ?? 'Order-based fallback',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMetricBox({
    required double width,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.20),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStatus(
    Map<String, dynamic> data,
  ) {
    final status =
        data['overall_status']?.toString() ?? 'UNKNOWN';

    final headline =
        data['headline']?.toString() ??
            'No business insight available.';

    final color = _statusColor(status);

    return Card(
      elevation: 1,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                status == 'STABLE'
                    ? Icons.check_circle
                    : Icons.warning_amber,
                color: color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.replaceAll('_', ' '),
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    headline,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackNotice(
    Map<String, dynamic> data,
  ) {
    final source = data['data_source']?.toString() ?? '';
    if (source != 'order_based_fallback') {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Real-data forecasting is not ready yet. These recommendations use active customer orders and recorded inventory only; no synthetic demand is used.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    Map<String, dynamic> data,
  ) {
    final summary =
        Map<String, dynamic>.from(
      data['summary'] ?? {},
    );
    final sourceLabel = data['data_source'] == 'real_business_data'
        ? 'Real Data'
        : 'Active Orders';

    final rawInsights =
        data['insights'] as List<dynamic>? ?? [];

    final insights = rawInsights
        .map(
          (item) => Map<String, dynamic>.from(
            item as Map,
          ),
        )
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth > 1200
            ? 1200.0
            : constraints.maxWidth - 32;

        return Center(
          child: SizedBox(
            width: maxWidth,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                vertical: 20,
              ),
              children: [
                // ------------------------------------------------
                // PAGE HEADER
                // ------------------------------------------------

                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Business Insights',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'AI-assisted analysis for your next market trip',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // ------------------------------------------------
                // FORECAST INFORMATION
                // ------------------------------------------------

                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _buildTag(
                      'Forecast: ${_formatDate(data['forecast_date'])}',
                      Colors.blue,
                    ),
                    _buildTag(
                      'Mode: ${data['mode']?.toString() ?? 'Unknown'}',
                      Colors.deepPurple,
                    ),
                    _buildTag(
                      'Source: $sourceLabel',
                      Colors.orange,
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                _buildOverallStatus(data),

                const SizedBox(height: 14),

                _buildFallbackNotice(data),

                const SizedBox(height: 18),

                // ------------------------------------------------
                // SUMMARY
                // ------------------------------------------------

                LayoutBuilder(
                  builder: (context, summaryConstraints) {
                    final columns =
                        summaryConstraints.maxWidth >= 900
                            ? 4
                            : summaryConstraints.maxWidth >= 550
                                ? 2
                                : 1;

                    final width = columns == 1
                        ? summaryConstraints.maxWidth
                        : (summaryConstraints.maxWidth -
                                ((columns - 1) * 12)) /
                            columns;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: width,
                          child: _buildSummaryCard(
                            icon: Icons.analytics,
                            title: 'Products Analyzed',
                            value: _formatNumber(
                              summary['products_analyzed'],
                            ),
                            subtitle:
                                'Products reviewed by AI',
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _buildSummaryCard(
                            icon: Icons.priority_high,
                            title: 'High Attention',
                            value: _formatNumber(
                              summary['high_attention'],
                            ),
                            subtitle:
                                'Products needing review',
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _buildSummaryCard(
                            icon: Icons.shopping_cart,
                            title: 'Purchase Required',
                            value: _formatNumber(
                              summary['purchase_required'],
                            ),
                            subtitle:
                                'Products needing stock',
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _buildSummaryCard(
                            icon: Icons.check_circle,
                            title: 'Stock Sufficient',
                            value: _formatNumber(
                              summary['inventory_sufficient'],
                            ),
                            subtitle:
                                'Products adequately stocked',
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                // ------------------------------------------------
                // INSIGHTS
                // ------------------------------------------------

                const Text(
                  'Product Insights',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                if (insights.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.analytics_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No insights available.',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...insights.map(
                    _buildInsightCard,
                  ),

                const SizedBox(height: 20),

                // ------------------------------------------------
                // FOOTER
                // ------------------------------------------------

                Center(
                  child: Text(
                    'Generated on ${_formatDate(data['generated_on'])}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Business Insights'),
        actions: [
          IconButton(
            tooltip: 'Refresh insights',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _insightsFuture,
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 50,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Unable to load AI insights',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data =
              snapshot.data ??
                  <String, dynamic>{};

          return RefreshIndicator(
            onRefresh: _refresh,
            child: _buildContent(data),
          );
        },
      ),
    );
  }
}