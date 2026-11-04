import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/product.dart';
import '../models/cart_item.dart';
import '../config/app_config.dart';

class ApiService {
  static const String baseUrl = AppConfig.apiBaseUrl;

  // =========================================================
  // GET PRODUCTS
  // =========================================================

  static Future<List<Product>> getProducts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/products/'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data =
          jsonDecode(response.body);

      return data
          .map(
            (json) => Product.fromJson(json),
          )
          .toList();
    }

    throw Exception(
      'Failed to load products: ${response.statusCode}',
    );
  }

  // =========================================================
  // CREATE PRODUCT - ADMIN
  // =========================================================

  static Future<Map<String, dynamic>> createProduct({
    required String name,
    required String unit,
    required double price,
    required double stockQuantity,
    required int categoryId,
    String? imageUrl,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/products/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'unit': unit,
        'price': price,
        'stock_quantity': stockQuantity,
        'category_id': categoryId,
        'image_url': imageUrl,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to create product: ${response.body}',
    );
  }

  // =========================================================
  // UPDATE PRODUCT - ADMIN
  // =========================================================

  static Future<Map<String, dynamic>> updateProduct({
    required int productId,
    required String name,
    required String unit,
    required double price,
    required double stockQuantity,
    required int categoryId,
    String? imageUrl,
    required String token,
  }) async {
    final response = await http.put(
      Uri.parse(
        '$baseUrl/products/$productId',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'unit': unit,
        'price': price,
        'stock_quantity': stockQuantity,
        'category_id': categoryId,
        'image_url': imageUrl,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to update product: ${response.body}',
    );
  }

  // =========================================================
  // DELETE PRODUCT - ADMIN
  // =========================================================

  static Future<Map<String, dynamic>> deleteProduct({
    required int productId,
    required String token,
  }) async {
    final response = await http.delete(
      Uri.parse(
        '$baseUrl/products/$productId',
      ),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to delete product: ${response.body}',
    );
  }

  // =========================================================
  // CREATE ORDER
  // =========================================================

  static Future<Map<String, dynamic>> createOrder({
    required List<CartItem> items,
    required String token,
    int? deliveryAddressId,
    DateTime? scheduledDeliveryAt,
    String? deliverySlot,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'delivery_address_id': deliveryAddressId,
        'scheduled_delivery_at': scheduledDeliveryAt?.toUtc().toIso8601String(),
        'delivery_slot': deliverySlot,
        'items': items.map((item) {
          return {
            'product_id': item.product.id,
            'quantity': item.quantity,
          };
        }).toList(),
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to create order: ${response.body}',
    );
  }

  // =========================================================
  // GET MY ORDERS
  // =========================================================

  static Future<List<dynamic>> getMyOrders(
    String token,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/orders/my-orders'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)
          as List<dynamic>;
    }

    throw Exception(
      'Failed to load my orders: ${response.body}',
    );
  }

  // =========================================================
  // GET ADMIN ORDERS
  // =========================================================

  static Future<List<dynamic>> getAdminOrders(
    String token,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/orders'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)
          as List<dynamic>;
    }

    throw Exception(
      'Failed to load admin orders: ${response.body}',
    );
  }

  // =========================================================
  // GET ADMIN ORDER DETAILS
  // =========================================================

  static Future<Map<String, dynamic>>
      getAdminOrderDetails({
    required int orderId,
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/admin/orders/$orderId',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to load order details: ${response.body}',
    );
  }

  // =========================================================
  // UPDATE ORDER STATUS
  // =========================================================

  static Future<Map<String, dynamic>>
      updateOrderStatus({
    required int orderId,
    required String status,
    required String token,
  }) async {
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/admin/orders/$orderId/status',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'new_status': status,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to update order: ${response.body}',
    );
  }

  // =========================================================
  // GET MARKET PURCHASE PLAN
  // =========================================================

  static Future<List<dynamic>> getMarketPlan(
    String token,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/market-plan'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)
          as List<dynamic>;
    }

    throw Exception(
      'Failed to load market plan: ${response.body}',
    );
  }

  // =========================================================
  // GET AI MARKET PURCHASE PLAN
  // =========================================================

  static Future<Map<String, dynamic>>
      getAiMarketPlan(
    String token,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/admin/ai/market-plan',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to load AI market plan: ${response.body}',
    );
  }

  // =========================================================
  // GET AI BUSINESS INSIGHTS
  // =========================================================

  static Future<Map<String, dynamic>>
      getAiInsights(
    String token,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/admin/ai/insights',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to load AI insights: ${response.body}',
    );
  }

  // =========================================================
  // GET AI READINESS
  // =========================================================

  static Future<Map<String, dynamic>>
      getAiReadiness(
    String token,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/admin/ai/readiness',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to load AI readiness: ${response.body}',
    );
  }

  // =========================================================
  // GET AI MODEL STATUS
  // =========================================================

  static Future<Map<String, dynamic>>
      getAiModelStatus(
    String token,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/admin/ai/model-status',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to load AI model status: ${response.body}',
    );
  }

  // =========================================================
  // TRAIN REAL AI MODEL
  // =========================================================

  static Future<Map<String, dynamic>>
      trainRealAiModel(
    String token,
  ) async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/admin/ai/train',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to train real AI model: ${response.body}',
    );
  }

  // =========================================================
  // GET INVENTORY
  // =========================================================

  static Future<List<dynamic>> getInventory(
    String token,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/admin/inventory/',
      ),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)
          as List<dynamic>;
    }

    throw Exception(
      'Failed to load inventory: ${response.body}',
    );
  }

  // =========================================================
  // ADD INVENTORY / PURCHASE
  // =========================================================

  static Future<Map<String, dynamic>>
      addInventory({
    required int productId,
    required double purchasedQuantity,
    required double purchaseCostPerUnit,
    required double reservedQuantity,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/admin/inventory/',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'product_id': productId,
        'purchased_quantity':
            purchasedQuantity,
        'purchase_cost_per_unit':
            purchaseCostPerUnit,
        'reserved_quantity':
            reservedQuantity,
      }),
    );

    if (response.statusCode == 200 ||
        response.statusCode == 201) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to add inventory: ${response.body}',
    );
  }

  // =========================================================
  // CREATE WALK-IN SALE
  // =========================================================

  static Future<Map<String, dynamic>>
      createSale({
    required int productId,
    required double quantity,
    required double sellingPrice,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/admin/sales/',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'product_id': productId,
        'quantity': quantity,
        'selling_price': sellingPrice,
      }),
    );

    if (response.statusCode == 200 ||
        response.statusCode == 201) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to create sale: ${response.body}',
    );
  }

  // =========================================================
  // GET WALK-IN SALES
  // =========================================================

  static Future<List<dynamic>> getSales(
    String token,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/admin/sales/',
      ),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)
          as List<dynamic>;
    }

    throw Exception(
      'Failed to load sales: ${response.body}',
    );
  }

  // =========================================================
  // GET VENDOR DASHBOARD
  // =========================================================

  static Future<Map<String, dynamic>>
      getDashboard(
    String token,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/admin/dashboard',
      ),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to load dashboard: ${response.body}',
    );
  }

  // =========================================================
  // GET FINANCIAL SUMMARY
  // =========================================================

  static Future<Map<String, dynamic>>
      getFinancialSummary({
    required String token,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParameters =
        <String, String>{};

    if (startDate != null) {
      queryParameters['start_date'] =
          _formatDate(startDate);
    }

    if (endDate != null) {
      queryParameters['end_date'] =
          _formatDate(endDate);
    }

    final uri = Uri.parse(
      '$baseUrl/admin/financial/summary',
    ).replace(
      queryParameters:
          queryParameters.isEmpty
              ? null
              : queryParameters,
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to load financial summary: ${response.body}',
    );
  }

  // =========================================================
  // FORMAT DATE
  // =========================================================

  static String _formatDate(
    DateTime date,
  ) {
    final year =
        date.year.toString().padLeft(4, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    final day =
        date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }


  // CUSTOMER EXPERIENCE: categories, profile, addresses and notifications.
  static Future<List<dynamic>> getCategories() async {
    final response = await http.get(Uri.parse('$baseUrl/categories/'));
    if (response.statusCode == 200) return jsonDecode(response.body) as List<dynamic>;
    throw Exception('Failed to load categories: ${response.body}');
  }

  static Future<Map<String, dynamic>> getCustomerProfile(String token) async {
    final response = await http.get(Uri.parse('$baseUrl/customer/profile'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception('Failed to load profile: ${response.body}');
  }

  static Future<Map<String, dynamic>> updateCustomerProfile({required String token, required String name}) async {
    final response = await http.put(Uri.parse('$baseUrl/customer/profile'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({'name': name}));
    if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception('Failed to update profile: ${response.body}');
  }

  static Future<List<dynamic>> getCustomerAddresses(String token) async {
    final response = await http.get(Uri.parse('$baseUrl/customer/addresses'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) return jsonDecode(response.body) as List<dynamic>;
    throw Exception('Failed to load addresses: ${response.body}');
  }

  static Future<Map<String, dynamic>> saveCustomerAddress({required String token, required Map<String, dynamic> address, int? addressId}) async {
    final uri = Uri.parse(addressId == null ? '$baseUrl/customer/addresses' : '$baseUrl/customer/addresses/$addressId');
    final response = await (addressId == null ? http.post(uri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode(address)) : http.put(uri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode(address)));
    if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception('Failed to save address: ${response.body}');
  }

  static Future<void> deleteCustomerAddress({required String token, required int addressId}) async {
    final response = await http.delete(Uri.parse('$baseUrl/customer/addresses/$addressId'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode != 200) throw Exception('Failed to delete address: ${response.body}');
  }

  static Future<List<dynamic>> getNotifications(String token) async {
    final response = await http.get(Uri.parse('$baseUrl/customer/notifications'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) return jsonDecode(response.body) as List<dynamic>;
    throw Exception('Failed to load notifications: ${response.body}');
  }

  static Future<int> getUnreadNotificationCount(String token) async {
    final response = await http.get(Uri.parse('$baseUrl/customer/notifications/unread-count'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) return (jsonDecode(response.body)['count'] as num).toInt();
    throw Exception('Failed to load notification count: ${response.body}');
  }

  static Future<void> markNotificationRead({required String token, required int notificationId}) async {
    final response = await http.patch(Uri.parse('$baseUrl/customer/notifications/$notificationId/read'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode != 200) throw Exception('Failed to update notification: ${response.body}');
  }

  static Future<void> markAllNotificationsRead(String token) async {
    final response = await http.post(Uri.parse('$baseUrl/customer/notifications/read-all'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode != 200) throw Exception('Failed to update notifications: ${response.body}');
  }

  static Future<Map<String, dynamic>> createCategory({required String token, required String name}) async {
    final response = await http.post(Uri.parse('$baseUrl/categories/'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({'name': name}));
    if (response.statusCode == 201) return jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception('Failed to create category: ${response.body}');
  }

  static Future<void> deleteCategory({required String token, required int categoryId}) async {
    final response = await http.delete(Uri.parse('$baseUrl/categories/$categoryId'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode != 200) throw Exception('Failed to delete category: ${response.body}');
  }




}