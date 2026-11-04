import 'package:flutter/material.dart';

import 'ai_management_page.dart';
import 'product_management_page.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'inventory_page.dart';
import 'market_plan_page.dart';
import 'quick_sale_page.dart';
import 'sales_history_page.dart';
import 'financial_dashboard_page.dart';
import 'ai_market_plan_page.dart';
import 'ai_insights_page.dart';
import 'order_detail_page.dart';
import 'customer_pages.dart';

class AdminDashboard extends StatefulWidget {
  final AuthService authService;

  const AdminDashboard({
    super.key,
    required this.authService,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<Map<String, dynamic>> dashboardFuture;
  late Future<List<dynamic>> ordersFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final token = widget.authService.token!;

    dashboardFuture = ApiService.getDashboard(token);
    ordersFuture = ApiService.getAdminOrders(token);
  }

  Future<void> refreshDashboard() async {
    setState(() {
      _loadData();
    });

    try {
      await dashboardFuture;
      await ordersFuture;
    } catch (_) {}
  }

  // =========================================================
  // NAVIGATION
  // =========================================================

  void _openMarketPlan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarketPlanPage(
          authService: widget.authService,
        ),
      ),
    );
  }

  void _openInventory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryPage(
          authService: widget.authService,
        ),
      ),
    );
  }

  void _openFinancialManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FinancialDashboardPage(
          authService: widget.authService,
        ),
      ),
    );
  }

  void _openProductManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductManagementPage(
          authService: widget.authService,
        ),
      ),
    );
  }

  void _openAiManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiManagementPage(
          token: widget.authService.token!,
        ),
      ),
    );
  }

  void _openAiMarketPlan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiMarketPlanPage(
          authService: widget.authService,
        ),
      ),
    );
  }

  void _openAiInsights() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiInsightsPage(
          authService: widget.authService,
        ),
      ),
    );
  }

  void _openQuickSale() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuickSalePage(
          authService: widget.authService,
        ),
      ),
    );
  }

  void _openSalesHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SalesHistoryPage(
          authService: widget.authService,
        ),
      ),
    );
  }

  void _openOrderDetails(int orderId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailPage(
          authService: widget.authService,
          orderId: orderId,
        ),
      ),
    );
  }

  // =========================================================
  // ORDER STATUS BUTTON
  // =========================================================

  Widget _buildStatusButton(
    Map<String, dynamic> order,
  ) {
    final status = (order['status'] ?? '').toString();

    String? nextStatus;
    String? buttonText;
    IconData? icon;

    switch (status) {
      case 'PLACED':
        nextStatus = 'CONFIRMED';
        buttonText = 'Confirm Order';
        icon = Icons.check;
        break;

      case 'CONFIRMED':
        nextStatus = 'PURCHASING';
        buttonText = 'Start Purchasing';
        icon = Icons.shopping_cart;
        break;

      case 'PURCHASING':
        nextStatus = 'READY';
        buttonText = 'Mark Ready';
        icon = Icons.inventory_2;
        break;

      case 'READY':
        nextStatus = 'DELIVERED';
        buttonText = 'Mark Delivered';
        icon = Icons.local_shipping;
        break;

      case 'DELIVERED':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),
            const SizedBox(width: 8),
            const Text(
              'Order Completed',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );

      default:
        return const Text(
          'Unknown Status',
        );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () async {
          try {
            await ApiService.updateOrderStatus(
              orderId: order['id'],
              status: nextStatus!,
              token: widget.authService.token!,
            );

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Order #${order['id']} updated to $nextStatus',
                ),
              ),
            );

            await refreshDashboard();
          } catch (e) {
            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to update order: $e',
                ),
              ),
            );
          }
        },
        icon: Icon(icon),
        label: Text(buttonText),
      ),
    );
  }

  // =========================================================
  // STAT CARD
  // =========================================================

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // SECTION TITLE
  // =========================================================

  Widget _buildSectionTitle(
    String title, {
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 24,
        bottom: 12,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // LOW STOCK
  // =========================================================

  Widget _buildLowStockSection(
    Map<String, dynamic> inventory,
  ) {
    final List<dynamic> products =
        inventory['low_stock_products'] ?? [];

    if (products.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Theme.of(context)
                    .colorScheme
                    .primary,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'No low-stock products right now.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: products.map((item) {
          final quantity =
              (item['remaining_quantity'] ?? 0)
                  .toString();

          return ListTile(
            leading: const Icon(
              Icons.warning_amber_rounded,
            ),
            title: Text(
              item['product_name'] ?? 'Unknown',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Remaining: $quantity ${item['unit'] ?? ''}',
            ),
          );
        }).toList(),
      ),
    );
  }

  // =========================================================
  // TOP PRODUCTS
  // =========================================================

  Widget _buildTopProducts(
    List<dynamic> products,
  ) {
    if (products.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No sales recorded today.',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: products
            .asMap()
            .entries
            .map((entry) {
          final index = entry.key;
          final product = entry.value;

          return ListTile(
            leading: CircleAvatar(
              child: Text(
                '${index + 1}',
              ),
            ),
            title: Text(
              product['product_name'] ?? 'Unknown',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${product['quantity']} ${product['unit'] ?? ''} sold',
            ),
          );
        }).toList(),
      ),
    );
  }

  // =========================================================
  // RECENT ORDERS
  // =========================================================

  Widget _buildRecentOrders(
    List<dynamic> orders,
  ) {
    if (orders.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No orders yet.',
          ),
        ),
      );
    }

    return Column(
      children: orders.map((rawOrder) {
        final order =
            rawOrder as Map<String, dynamic>;

        final status =
            (order['status'] ?? 'UNKNOWN').toString();

        final orderId =
            int.tryParse(
                  order['id']?.toString() ?? '',
                ) ??
                0;

        final customer =
            (order['customer']
                    as Map<String, dynamic>?) ??
                {};

        final customerName =
            customer['name']?.toString() ??
                order['customer_name']?.toString() ??
                'Unknown Customer';

        final customerPhone =
            customer['phone']?.toString();

        final itemList =
            (order['items'] as List<dynamic>?) ??
                [];

        return Card(
          margin: const EdgeInsets.only(
            bottom: 12,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: orderId > 0
                ? () => _openOrderDetails(orderId)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // ORDER HEADER
                  Row(
                    children: [
                      CircleAvatar(
                        child: Text(
                          '#$orderId',
                          style: const TextStyle(
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              customerName,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Order #$orderId',
                                  style: TextStyle(
                                    color: Theme.of(
                                            context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                                if (customerPhone !=
                                    null) ...[
                                  const SizedBox(
                                    width: 8,
                                  ),
                                  Text(
                                    '• $customerPhone',
                                    style: TextStyle(
                                      color: Theme.of(
                                              context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₹${order['total_amount'] ?? 0}',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // STATUS
                  Row(
                    children: [
                      const Text(
                        'Status: ',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration:
                            BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(
                            20,
                          ),
                          color: Theme.of(context)
                              .colorScheme
                              .secondaryContainer,
                        ),
                        child: Text(
                          status,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${itemList.length} '
                        'item${itemList.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // VIEW ORDER
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: orderId > 0
                          ? () =>
                              _openOrderDetails(
                                orderId,
                              )
                          : null,
                      icon: const Icon(
                        Icons.visibility_outlined,
                      ),
                      label: const Text(
                        'View Order Details',
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  _buildStatusButton(order),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // =========================================================
  // QUICK ACTIONS
  // =========================================================

  Widget _buildQuickActions() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: _openQuickSale,
          icon: const Icon(
            Icons.point_of_sale,
          ),
          label: const Text(
            'Quick Sale',
          ),
        ),
        OutlinedButton.icon(
          onPressed: _openInventory,
          icon: const Icon(
            Icons.inventory_2_outlined,
          ),
          label: const Text(
            'Inventory',
          ),
        ),
        FilledButton.icon(
          onPressed: _openAiMarketPlan,
          icon: const Icon(
            Icons.auto_awesome,
          ),
          label: const Text(
            'AI Purchase Plan',
          ),
        ),
        FilledButton.icon(
          onPressed: _openAiInsights,
          icon: const Icon(
            Icons.insights,
          ),
          label: const Text(
            'AI Insights',
          ),
        ),
        OutlinedButton.icon(
          onPressed: _openAiManagement,
          icon: const Icon(
            Icons.settings_suggest,
          ),
          label: const Text(
            'AI Management',
          ),
        ),
        OutlinedButton.icon(
          onPressed: _openProductManagement,
          icon: const Icon(
            Icons.category_outlined,
          ),
          label: const Text(
            'Products',
          ),
        ),
        OutlinedButton.icon(
          onPressed: _openFinancialManagement,
          icon: const Icon(
            Icons.account_balance_wallet_outlined,
          ),
          label: const Text(
            'Financials',
          ),
        ),
        OutlinedButton.icon(
          onPressed: _openMarketPlan,
          icon: const Icon(
            Icons.shopping_basket_outlined,
          ),
          label: const Text(
            'Market Plan',
          ),
        ),
        OutlinedButton.icon(
          onPressed: _openSalesHistory,
          icon: const Icon(
            Icons.receipt_long_outlined,
          ),
          label: const Text(
            'Sales History',
          ),
        ),
      ],
    );
  }

  // =========================================================
  // AI SECTION
  // =========================================================

  Widget _buildAiSection() {
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Vendor AI',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'AI-powered decision support for your business',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= 650;

                final cardWidth = wide
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _buildAiActionCard(
                        icon: Icons.auto_graph,
                        title: 'AI Purchase Plan',
                        description:
                            'Forecast tomorrow\'s demand and '
                            'calculate recommended purchase quantities.',
                        buttonText:
                            'Open Purchase Plan',
                        onPressed:
                            _openAiMarketPlan,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildAiActionCard(
                        icon: Icons.insights,
                        title: 'AI Business Insights',
                        description:
                            'Identify products that need attention '
                            'using demand, orders and inventory data.',
                        buttonText:
                            'View AI Insights',
                        onPressed:
                            _openAiInsights,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildAiActionCard(
                        icon: Icons.settings_suggest,
                        title: 'AI Management',
                        description:
                            'Monitor real-data readiness, model status '
                            'and production AI training.',
                        buttonText:
                            'Open AI Management',
                        onPressed:
                            _openAiManagement,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiActionCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant,
        ),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 28,
            color: Theme.of(context)
                .colorScheme
                .primary,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(
              Icons.arrow_forward,
              size: 18,
            ),
            label: Text(buttonText),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  Widget _menuItem(BuildContext context, IconData icon, String title, VoidCallback action) {
    return ListTile(leading: Icon(icon, color: const Color(0xFF2E7D32)), title: Text(title), onTap: () { Navigator.pop(context); action(); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(width: double.infinity, padding: const EdgeInsets.all(22), color: const Color(0xFFE4F1E1), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [CircleAvatar(radius: 27, backgroundColor: Colors.white, child: Icon(Icons.storefront, color: Color(0xFF2E7D32), size: 30)), SizedBox(height: 10), Text('Vendor Workspace', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF194D24))), Text('Smart Vendor Admin', style: TextStyle(color: Color(0xFF55745A)))])),
              Expanded(child: ListView(children: [
                _menuItem(context, Icons.dashboard_outlined, 'Dashboard', () {}),
                _menuItem(context, Icons.inventory_2_outlined, 'Product Management', _openProductManagement),
                _menuItem(context, Icons.category_outlined, 'Product Categories', () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryManagementPage(authService: widget.authService)))),
                _menuItem(context, Icons.receipt_long_outlined, 'Orders', () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminOrdersPage(authService: widget.authService)))),
                _menuItem(context, Icons.warehouse_outlined, 'Inventory', _openInventory),
                _menuItem(context, Icons.shopping_basket_outlined, 'Market Purchase Plan', _openMarketPlan),
                _menuItem(context, Icons.auto_awesome, 'AI Market Purchase Plan', _openAiMarketPlan),
                _menuItem(context, Icons.point_of_sale, 'Quick Sale', _openQuickSale),
                _menuItem(context, Icons.history, 'Sales History', _openSalesHistory),
                _menuItem(context, Icons.account_balance_wallet_outlined, 'Financial Reports', _openFinancialManagement),
                _menuItem(context, Icons.insights, 'AI Business Insights', _openAiInsights),
                _menuItem(context, Icons.settings_suggest, 'AI Management', _openAiManagement),
                _menuItem(context, Icons.notifications_outlined, 'Notifications', () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminNotificationsPage(authService: widget.authService)))),
              ])),
              const Divider(),
              ListTile(leading: const Icon(Icons.refresh), title: const Text('Refresh dashboard'), onTap: () { Navigator.pop(context); refreshDashboard(); }),
              ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Logout'), onTap: () { widget.authService.logout(); Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false); }),
            ],
          ),
        ),
      ),
      appBar: AppBar(title: const Text('Smart Vendor Admin')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: dashboardFuture,
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
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Failed to load dashboard.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: refreshDashboard,
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

          final data = snapshot.data ?? {};

          final today =
              data['today']
                      as Map<String, dynamic>? ??
                  {};

          final orders =
              data['orders']
                      as Map<String, dynamic>? ??
                  {};

          final inventory =
              data['inventory']
                      as Map<String, dynamic>? ??
                  {};

          final topProducts =
              data['top_products']
                      as List<dynamic>? ??
                  [];

          final recentOrders =
              data['recent_orders']
                      as List<dynamic>? ??
                  [];

          final revenue =
              (today['revenue'] ?? 0).toString();

          final onlineOrders =
              (today['online_orders'] ?? 0).toString();

          final walkInSales =
              (today['walk_in_sales'] ?? 0).toString();

          final productsSold =
              (today['products_sold'] ?? 0).toString();

          final pendingOrders =
              (orders['pending'] ?? 0).toString();

          final completedOrders =
              (orders['completed'] ?? 0).toString();

          final lowStockCount =
              (inventory['low_stock_count'] ?? 0)
                  .toString();

          final totalInventoryProducts =
              (inventory['total_products'] ?? 0)
                  .toString();

          return RefreshIndicator(
            onRefresh: refreshDashboard,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;

                int columns;

                if (width >= 1200) {
                  columns = 4;
                } else if (width >= 700) {
                  columns = 2;
                } else {
                  columns = 1;
                }

                return ListView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.all(16),
                  children: [
                    // =================================================
                    // HEADER
                    // =================================================

                    const Text(
                      'Business Overview',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Today\'s business performance',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),

                    // =================================================
                    // STAT CARDS
                    // =================================================

                    const SizedBox(height: 20),

                    GridView.count(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio:
                          columns == 1 ? 3.2 : 1.7,
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStatCard(
                          title:
                              'Today\'s Revenue',
                          value:
                              '₹$revenue',
                          icon:
                              Icons.currency_rupee,
                        ),
                        _buildStatCard(
                          title:
                              'Online Orders',
                          value:
                              onlineOrders,
                          icon:
                              Icons.shopping_cart,
                        ),
                        _buildStatCard(
                          title:
                              'Walk-in Sales',
                          value:
                              walkInSales,
                          icon:
                              Icons.storefront,
                        ),
                        _buildStatCard(
                          title:
                              'Products Sold',
                          value:
                              productsSold,
                          icon:
                              Icons.inventory,
                        ),
                      ],
                    ),

                    // =================================================
                    // ORDER SUMMARY
                    // =================================================

                    _buildSectionTitle(
                      'Order Summary',
                      icon:
                          Icons.assignment_outlined,
                    ),

                    GridView.count(
                      crossAxisCount:
                          width >= 700 ? 2 : 1,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio:
                          width >= 700
                              ? 2.8
                              : 3.2,
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStatCard(
                          title:
                              'Pending Orders',
                          value:
                              pendingOrders,
                          icon:
                              Icons.pending_actions,
                        ),
                        _buildStatCard(
                          title:
                              'Completed Orders',
                          value:
                              completedOrders,
                          icon:
                              Icons.check_circle_outline,
                        ),
                      ],
                    ),

                    // =================================================
                    // INVENTORY SUMMARY
                    // =================================================

                    _buildSectionTitle(
                      'Inventory',
                      icon:
                          Icons.inventory_2_outlined,
                    ),

                    GridView.count(
                      crossAxisCount:
                          width >= 700 ? 2 : 1,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio:
                          width >= 700
                              ? 2.8
                              : 3.2,
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStatCard(
                          title:
                              'Tracked Products',
                          value:
                              totalInventoryProducts,
                          icon:
                              Icons.category_outlined,
                        ),
                        _buildStatCard(
                          title:
                              'Low Stock Products',
                          value:
                              lowStockCount,
                          icon:
                              Icons.warning_amber_rounded,
                        ),
                      ],
                    ),

                    // =================================================
                    // LOW STOCK
                    // =================================================

                    _buildSectionTitle(
                      'Low Stock Alerts',
                      icon:
                          Icons.warning_amber_rounded,
                    ),

                    _buildLowStockSection(
                      inventory,
                    ),

                    // =================================================
                    // TOP PRODUCTS
                    // =================================================

                    _buildSectionTitle(
                      'Top Selling Products Today',
                      icon:
                          Icons.trending_up,
                    ),

                    _buildTopProducts(
                      topProducts,
                    ),

                    // =================================================
                    // RECENT ORDERS
                    // =================================================

                    _buildSectionTitle(
                      'Order Management',
                      icon:
                          Icons.assignment_turned_in_outlined,
                    ),

                    _buildRecentOrders(
                      recentOrders,
                    ),

                    // =================================================
                    // QUICK ACTIONS
                    // =================================================

                    _buildSectionTitle(
                      'Quick Actions',
                      icon:
                          Icons.flash_on_outlined,
                    ),

                    _buildQuickActions(),

                    const SizedBox(height: 30),

                    // =================================================
                    // AI SECTION
                    // =================================================

                    _buildAiSection(),

                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}