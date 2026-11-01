import 'package:flutter/material.dart';

import '../services/api_service.dart';

class AiManagementPage extends StatefulWidget {
  final String token;

  const AiManagementPage({
    super.key,
    required this.token,
  });

  @override
  State<AiManagementPage> createState() => _AiManagementPageState();
}

class _AiManagementPageState extends State<AiManagementPage> {
  bool _loading = true;
  bool _training = false;

  String? _error;

  Map<String, dynamic>? _readiness;
  Map<String, dynamic>? _modelStatus;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getAiReadiness(widget.token),
        ApiService.getAiModelStatus(widget.token),
      ]);

      if (!mounted) return;

      setState(() {
        _readiness = results[0];
        _modelStatus = results[1];
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

  Future<void> _trainRealModel() async {
    if (_training) return;

    final ready =
        _readiness?['ready_for_training'] == true;

    if (!ready) {
      _showMessage(
        'Real AI is not ready yet. Continue collecting business data.',
        isError: true,
      );
      return;
    }

    setState(() {
      _training = true;
    });

    try {
      final result =
          await ApiService.trainRealAiModel(widget.token);

      if (!mounted) return;

      final status = result['status'];

      if (status == 'success') {
        _showMessage(
          'Real AI model trained successfully.',
        );
      } else {
        _showMessage(
          result['message']?.toString() ??
              'Real AI training could not be completed.',
          isError: true,
        );
      }

      await _loadData();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString(),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _training = false;
        });
      }
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadData,
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
      return _buildErrorState();
    }

    if (_readiness == null) {
      return const Center(
        child: Text('Unable to load AI status.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;

          return SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1200,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildReadinessCard(),
                    const SizedBox(height: 20),
                    _buildDataCards(wide),
                    const SizedBox(height: 20),
                    _buildRequirementsCard(),
                    const SizedBox(height: 20),
                    _buildModelsCard(),
                    const SizedBox(height: 20),
                    _buildTrainingCard(),
                    const SizedBox(height: 20),
                    _buildArchitectureCard(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Smart Vendor AI Control Center',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Monitor data readiness, models, and demand forecasting.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
                color: Colors.grey.shade700,
              ),
        ),
      ],
    );
  }

  Widget _buildReadinessCard() {
    final ready =
        _readiness?['ready_for_training'] == true;

    final status =
        _readiness?['status']?.toString() ??
            'UNKNOWN';

    final message =
        _readiness?['message']?.toString() ??
            'No status available.';

    final color =
        ready ? Colors.green : Colors.orange;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                ready
                    ? Icons.check_circle
                    : Icons.hourglass_top,
                color: color,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    ready
                        ? 'Real AI is ready'
                        : 'Real AI is collecting data',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Status: $status',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCards(bool wide) {
    final data =
        (_readiness?['data']
                as Map<String, dynamic>?) ??
            {};

    final cards = [
      _StatData(
        'Historical Days',
        '${data['historical_days'] ?? 0}',
        Icons.calendar_month,
      ),
      _StatData(
        'Transaction Days',
        '${data['transaction_days'] ?? 0}',
        Icons.receipt_long,
      ),
      _StatData(
        'Products',
        '${data['products_with_history'] ?? 0}',
        Icons.inventory_2,
      ),
      _StatData(
        'Demand Records',
        '${data['total_records'] ?? 0}',
        Icons.dataset,
      ),
    ];

    if (wide) {
      return Row(
        children: cards
            .map(
              (card) => Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.only(right: 12),
                  child: _buildStatCard(card),
                ),
              ),
            )
            .toList(),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards
          .map(
            (card) => SizedBox(
              width: 260,
              child: _buildStatCard(card),
            ),
          )
          .toList(),
    );
  }

  Widget _buildStatCard(_StatData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              data.icon,
              size: 30,
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.value,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementsCard() {
    final requirements =
        (_readiness?['requirements']
                as Map<String, dynamic>?) ??
            {};

    final data =
        (_readiness?['data']
                as Map<String, dynamic>?) ??
            {};

    final minimumDays =
        requirements['minimum_historical_days'] ?? 30;

    final minimumTransactions =
        requirements['minimum_transaction_days'] ?? 14;

    final historicalDays =
        data['historical_days'] ?? 0;

    final transactionDays =
        data['transaction_days'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Real AI Training Requirements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _requirementRow(
              'Historical calendar days',
              historicalDays,
              minimumDays,
            ),
            const SizedBox(height: 12),
            _requirementRow(
              'Transaction days',
              transactionDays,
              minimumTransactions,
            ),
            const SizedBox(height: 14),
            Text(
              'The system waits for sufficient real business history before training the production forecasting model.',
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requirementRow(
    String label,
    dynamic current,
    dynamic required,
  ) {
    final currentValue =
        int.tryParse('$current') ?? 0;

    final requiredValue =
        int.tryParse('$required') ?? 1;

    final progress =
        (currentValue / requiredValue)
            .clamp(0.0, 1.0);

    final complete =
        currentValue >= requiredValue;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              '$currentValue / $requiredValue',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
        ),
        const SizedBox(height: 5),
        Text(
          complete
              ? 'Requirement met'
              : 'Still collecting data',
          style: TextStyle(
            fontSize: 12,
            color: complete
                ? Colors.green.shade700
                : Colors.orange.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildModelsCard() {
    final models = _modelStatus ?? {};

    final real =
        (models['real_model']
                as Map<String, dynamic>?) ??
            {};

    final recommended =
        models['recommended_mode']
                ?.toString() ??
            'unavailable';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Models',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildModelRow(
              title: 'Real Business Model',
              available:
                  real['available'] == true,
              icon: Icons.business,
              metadata:
                  real['metadata']
                      as Map<String, dynamic>?,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(12),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Current planning mode: ${recommended.toUpperCase()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildModelRow({
    required String title,
    required bool available,
    required IconData icon,
    Map<String, dynamic>? metadata,
  }) {
    final modelName =
        metadata?['model_name']
                ?.toString() ??
            'Not trained';

    final records =
        metadata?['trained_records'] ?? 0;

    final trainedAt =
        metadata?['trained_at']
                ?.toString();

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 30,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _statusChip(available),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                'Model: $modelName',
              ),
              if (available) ...[
                const SizedBox(height: 4),
                Text(
                  'Training records: $records',
                ),
                if (trainedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Last trained: ${_formatDate(trainedAt)}',
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusChip(bool available) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: available
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.grey.withValues(alpha: 0.12),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        available
            ? 'AVAILABLE'
            : 'NOT AVAILABLE',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: available
              ? Colors.green.shade700
              : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildTrainingCard() {
    final ready =
        _readiness?['ready_for_training'] == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Real AI Training',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ready
                  ? 'Enough real business data is available. You can train the production forecasting model.'
                  : 'Training is currently locked because the system needs more real transaction history.',
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    ready && !_training
                        ? _trainRealModel
                        : null,
                icon: _training
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.model_training,
                      ),
                label: Text(
                  _training
                      ? 'Training Real AI...'
                      : 'Train Real AI Model',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchitectureCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Pipeline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            _pipelineStep(
              Icons.shopping_cart,
              'Online Orders',
            ),
            _pipelineArrow(),
            _pipelineStep(
              Icons.storefront,
              'Walk-in Sales',
            ),
            _pipelineArrow(),
            _pipelineStep(
              Icons.dataset,
              'Historical Demand Dataset',
            ),
            _pipelineArrow(),
            _pipelineStep(
              Icons.model_training,
              'Machine Learning Model',
            ),
            _pipelineArrow(),
            _pipelineStep(
              Icons.analytics,
              'Demand Forecast',
            ),
            _pipelineArrow(),
            _pipelineStep(
              Icons.shopping_basket,
              'AI Purchase Recommendation',
            ),
          ],
        ),
      ),
    );
  }

  Widget _pipelineStep(
    IconData icon,
    String title,
  ) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          child: Icon(
            icon,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _pipelineArrow() {
    return const Padding(
      padding: EdgeInsets.only(
        left: 18,
        top: 4,
        bottom: 4,
      ),
      child: Icon(
        Icons.arrow_downward,
        size: 20,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 50,
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to load AI management data.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
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

class _StatData {
  final String label;
  final String value;
  final IconData icon;

  const _StatData(
    this.label,
    this.value,
    this.icon,
  );
}