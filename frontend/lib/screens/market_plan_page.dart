import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

class MarketPlanPage extends StatefulWidget {
  final AuthService authService;

  const MarketPlanPage({
    super.key,
    required this.authService,
  });

  @override
  State<MarketPlanPage> createState() =>
      _MarketPlanPageState();
}

class _MarketPlanPageState
    extends State<MarketPlanPage> {
  late Future<List<dynamic>> planFuture;

  @override
  void initState() {
    super.initState();

    planFuture = ApiService.getMarketPlan(
      widget.authService.token!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🌅 Market Purchase Plan',
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: planFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load market plan.\n'
                '${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final plan = snapshot.data ?? [];

          if (plan.isEmpty) {
            return const Center(
              child: Text(
                'No pending purchases.',
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plan.length,
            itemBuilder: (context, index) {
              final item = plan[index];

              return Card(
                margin: const EdgeInsets.only(
                  bottom: 12,
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(
                      Icons.shopping_basket,
                    ),
                  ),
                  title: Text(
                    item['product_name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  trailing: Text(
                    '${item['required_quantity']} '
                    '${item['unit']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}