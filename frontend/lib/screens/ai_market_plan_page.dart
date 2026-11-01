import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

class AiMarketPlanPage extends StatefulWidget {
  final AuthService authService;

  const AiMarketPlanPage({
    super.key,
    required this.authService,
  });

  @override
  State<AiMarketPlanPage> createState() => _AiMarketPlanPageState();
}

class _AiMarketPlanPageState extends State<AiMarketPlanPage> {
  late Future<Map<String, dynamic>> marketPlanFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final token = widget.authService.token;

    if (token == null || token.isEmpty) {
      marketPlanFuture = Future.error(
        'Authentication token is missing.',
      );
      return;
    }

    marketPlanFuture = ApiService.getAiMarketPlan(token);
  }

  Future<void> _refresh() async {
    setState(() {
      _loadData();
    });

    try {
      await marketPlanFuture;
    } catch (_) {}
  }

  // =========================================================
  // HELPERS
  // =========================================================

  String _formatNumber(dynamic value) {
    final number = double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;

    if (number == number.roundToDouble()) {
      return number.toStringAsFixed(0);
    }

    return number.toStringAsFixed(2);
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Not available';
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Color _recommendationColor(
    BuildContext context,
    String recommendation,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (recommendation) {
      case 'HIGH_PURCHASE':
        return colorScheme.error;

      case 'MEDIUM_PURCHASE':
        return Colors.orange;

      case 'LOW_PURCHASE':
        return colorScheme.primary;

      case 'NO_PURCHASE':
        return Colors.green;

      default:
        return colorScheme.outline;
    }
  }

  String _recommendationText(
    String recommendation,
  ) {
    switch (recommendation) {
      case 'HIGH_PURCHASE':
        return 'HIGH PURCHASE';

      case 'MEDIUM_PURCHASE':
        return 'MEDIUM PURCHASE';

      case 'LOW_PURCHASE':
        return 'LOW PURCHASE';

      case 'NO_PURCHASE':
        return 'NO PURCHASE';

      default:
        return recommendation.isEmpty
            ? 'UNKNOWN'
            : recommendation;
    }
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader(
    Map<String, dynamic> data,
  ) {
    final forecastDate =
        data['forecast_date']?.toString();

    final dataSource =
        data['data_source']?.toString() ?? 'unknown';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(14),
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Market Purchase Plan',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Real-data forecasting when available; otherwise based on active customer orders.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 14),
            Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                _buildInfoChip(
                  icon: Icons.calendar_today,
                  label: 'Forecast',
                  value: _formatDate(
                    forecastDate,
                  ),
                ),
                _buildInfoChip(
                  icon: Icons.psychology,
                  label: 'Mode',
                  value: data['mode']
                          ?.toString()
                          .toUpperCase() ??
                      'ORDER_BASED',
                ),
                _buildInfoChip(
                  icon: Icons.storage,
                  label: 'Data Source',
                  value: dataSource == 'real_business_data'
                      ? 'Real Business Data'
                      : 'Active Orders',
                ),
                _buildInfoChip(
                  icon: Icons.shield_outlined,
                  label: 'Safety Buffer',
                  value:
                      '${_formatNumber(data['safety_buffer_percent'])}%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  // =========================================================
  // SUMMARY CARDS
  // =========================================================

  Widget _buildSummaryCards(
    List<dynamic> products,
  ) {
    double totalPredictedDemand = 0;
    double totalRecommendedPurchase = 0;
    double totalConfirmedOrders = 0;
    int highPurchaseCount = 0;

    for (final item in products) {
      final forecast =
          item['ai_forecast']
              as Map<String, dynamic>? ??
          {};

      final plan =
          item['purchase_plan']
              as Map<String, dynamic>? ??
          {};

      totalPredictedDemand +=
          double.tryParse(
                forecast['predicted_demand']
                        ?.toString() ??
                    '',
              ) ??
              0;

      totalRecommendedPurchase +=
          double.tryParse(
                plan[
                            'recommended_purchase_quantity']
                        ?.toString() ??
                    '',
              ) ??
              0;

      totalConfirmedOrders +=
          double.tryParse(
                item['confirmed_order_quantity']
                        ?.toString() ??
                    '',
              ) ??
              0;

      if (plan['recommendation'] ==
          'HIGH_PURCHASE') {
        highPurchaseCount++;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final columns = width >= 1000
            ? 4
            : width >= 650
                ? 2
                : 1;

        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio:
              columns == 1 ? 3.2 : 1.8,
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          children: [
            _buildSummaryCard(
              title: 'Predicted Demand',
              value: _formatNumber(
                totalPredictedDemand,
              ),
              subtitle: 'All products',
              icon: Icons.trending_up,
            ),
            _buildSummaryCard(
              title: 'Recommended Purchase',
              value: _formatNumber(
                totalRecommendedPurchase,
              ),
              subtitle: 'Total quantity',
              icon: Icons.shopping_cart_checkout,
            ),
            _buildSummaryCard(
              title: 'Confirmed Orders',
              value: _formatNumber(
                totalConfirmedOrders,
              ),
              subtitle: 'Customer demand',
              icon: Icons.assignment,
            ),
            _buildSummaryCard(
              title: 'High Purchase',
              value: highPurchaseCount.toString(),
              subtitle: 'Products requiring attention',
              icon: Icons.warning_amber_rounded,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(12),
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
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

  // =========================================================
  // PRODUCT CARD
  // =========================================================

  Widget _buildProductCard(
    Map<String, dynamic> item,
  ) {
    final productName =
        item['product_name']?.toString() ??
            'Unknown Product';

    final unit =
        item['unit']?.toString() ?? '';

    final forecast =
        item['ai_forecast']
            as Map<String, dynamic>? ??
        {};

    final inventory =
        item['inventory']
            as Map<String, dynamic>? ??
        {};

    final plan =
        item['purchase_plan']
            as Map<String, dynamic>? ??
        {};

    final predictedDemand =
        forecast['predicted_demand'] ?? 0;

    final confirmedOrders =
        item['confirmed_order_quantity'] ?? 0;

    final available =
        inventory['available'] ?? 0;

    final reserved =
        inventory['reserved'] ?? 0;

    final safetyStock =
        plan['safety_stock'] ?? 0;

    final expectedDemand =
        plan['expected_demand'] ?? 0;

    final targetStock =
        plan['target_stock'] ?? 0;

    final recommended =
        plan[
                'recommended_purchase_quantity'] ??
            0;

    final recommendation =
        plan['recommendation']
                ?.toString() ??
            '';

    final recommendationLabel =
        plan['recommendation_label']
                ?.toString() ??
            '';

    final forecastStatus =
        forecast['status']
                ?.toString() ??
            'unavailable';

    final badgeColor =
        _recommendationColor(
      context,
      recommendation,
    );

    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // -------------------------------------------------
            // PRODUCT HEADER
            // -------------------------------------------------

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(12),
                    color: Theme.of(context)
                        .colorScheme
                        .secondaryContainer,
                  ),
                  child: const Icon(
                    Icons.eco_outlined,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unit: $unit',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(20),
                    color: badgeColor.withValues(
                      alpha: 0.12,
                    ),
                  ),
                  child: Text(
                    _recommendationText(
                      recommendation,
                    ),
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            const Divider(),

            const SizedBox(height: 14),

            // -------------------------------------------------
            // AI FORECAST
            // -------------------------------------------------

            _buildSubSectionTitle(
              'AI Forecast',
              Icons.auto_awesome,
            ),

            const SizedBox(height: 10),

            _buildMetricsGrid(
              [
                _MetricData(
                  'Predicted Demand',
                  '${_formatNumber(predictedDemand)} $unit',
                  Icons.trending_up,
                ),
                _MetricData(
                  'Confirmed Orders',
                  '${_formatNumber(confirmedOrders)} $unit',
                  Icons.shopping_bag_outlined,
                ),
                _MetricData(
                  'Expected Demand',
                  '${_formatNumber(expectedDemand)} $unit',
                  Icons.analytics_outlined,
                ),
                _MetricData(
                  'Safety Stock',
                  '${_formatNumber(safetyStock)} $unit',
                  Icons.shield_outlined,
                ),
              ],
            ),

            const SizedBox(height: 18),

            // -------------------------------------------------
            // INVENTORY
            // -------------------------------------------------

            _buildSubSectionTitle(
              'Inventory Position',
              Icons.inventory_2_outlined,
            ),

            const SizedBox(height: 10),

            _buildMetricsGrid(
              [
                _MetricData(
                  'Available',
                  '${_formatNumber(available)} $unit',
                  Icons.inventory,
                ),
                _MetricData(
                  'Reserved',
                  '${_formatNumber(reserved)} $unit',
                  Icons.lock_outline,
                ),
                _MetricData(
                  'Target Stock',
                  '${_formatNumber(targetStock)} $unit',
                  Icons.flag_outlined,
                ),
              ],
            ),

            const SizedBox(height: 18),

            // -------------------------------------------------
            // PURCHASE RECOMMENDATION
            // -------------------------------------------------

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(14),
                color: badgeColor.withValues(
                  alpha: 0.08,
                ),
                border: Border.all(
                  color: badgeColor.withValues(
                    alpha: 0.25,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shopping_cart_checkout,
                    color: badgeColor,
                    size: 30,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recommended Purchase',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatNumber(recommended)} $unit',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight:
                                FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          recommendationLabel,
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight:
                                FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // -------------------------------------------------
            // MODEL INFO
            // -------------------------------------------------

            Row(
              children: [
                Icon(
                  forecastStatus ==
                          'available'
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  size: 17,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    forecastStatus ==
                            'available'
                        ? 'AI model: ${forecast['model'] ?? 'Unknown'}'
                        : 'Using order-based purchase planning',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),

            if (forecast['error'] != null) ...[
              const SizedBox(height: 6),
              Text(
                forecast['error'].toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubSectionTitle(
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(
    List<_MetricData> metrics,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 750
                ? metrics.length
                : constraints.maxWidth >= 450
                    ? 2
                    : 1;

        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio:
              columns == 1 ? 4.2 : 2.4,
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          children: metrics
              .map(
                (metric) => Container(
                  padding:
                      const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(10),
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        metric.icon,
                        size: 19,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              metric.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                        context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(
                              height: 3,
                            ),
                            Text(
                              metric.value,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  // =========================================================
  // EMPTY STATE
  // =========================================================

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Icon(
              Icons.auto_awesome,
              size: 52,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),
            const SizedBox(height: 14),
            const Text(
              'No AI purchase recommendations',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'There are currently no products available for forecasting.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Market Purchase Plan',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: marketPlanFuture,
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
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 52,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Failed to load AI purchase plan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(
                        Icons.refresh,
                      ),
                      label: const Text(
                        'Retry',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final data =
              snapshot.data ?? {};

          final products =
              data['products']
                      as List<dynamic>? ??
                  [];

          if (products.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.all(16),
                children: [
                  _buildHeader(data),
                  const SizedBox(height: 16),
                  _buildEmptyState(),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.all(16),
              children: [
                _buildHeader(data),

                const SizedBox(height: 16),

                _buildSummaryCards(products),

                const SizedBox(height: 24),

                Row(
                  children: [
                    const Icon(
                      Icons.shopping_basket_outlined,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Product-wise Purchase Recommendations',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${products.length} products',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                ...products.map(
                  (item) => _buildProductCard(
                    item
                        as Map<String, dynamic>,
                  ),
                ),

                const SizedBox(height: 20),

                // -------------------------------------------------
                if (data['data_source'] == 'order_based_fallback')
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Real-data forecasting is not ready yet. Purchase quantities are calculated from active customer orders and recorded inventory only.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================
// METRIC MODEL
// =============================================================

class _MetricData {
  final String label;
  final String value;
  final IconData icon;

  const _MetricData(
    this.label,
    this.value,
    this.icon,
  );
}