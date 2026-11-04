import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'order_detail_page.dart';

class CustomerProfilePage extends StatefulWidget {
  final AuthService authService;

  const CustomerProfilePage({super.key, required this.authService});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  final name = TextEditingController();
  final phoneController = TextEditingController();
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    name.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getCustomerProfile(
        widget.authService.token!,
      );
      name.text = data['name'] ?? '';
      phoneController.text = data['phone'] ?? '';
    } catch (e) {
      if (mounted) _msg('$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _msg(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  Future<void> _save() async {
    if (name.text.trim().length < 2) {
      _msg('Enter your full name.');
      return;
    }

    setState(() => saving = true);
    try {
      final updated = await ApiService.updateCustomerProfile(
        token: widget.authService.token!,
        name: name.text.trim(),
      );
      widget.authService.updateLocalUser(updated);
      if (mounted) _msg('Profile updated successfully.');
    } catch (e) {
      if (mounted) _msg('$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const CircleAvatar(
                  radius: 42,
                  child: Icon(Icons.person, size: 42),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: Text(saving ? 'Saving...' : 'Save profile'),
                ),
              ],
            ),
    );
  }
}

class CustomerAddressesPage extends StatefulWidget {
  final AuthService authService;

  const CustomerAddressesPage({super.key, required this.authService});

  @override
  State<CustomerAddressesPage> createState() => _CustomerAddressesPageState();
}

class _CustomerAddressesPageState extends State<CustomerAddressesPage> {
  List<dynamic> rows = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      rows = await ApiService.getCustomerAddresses(
        widget.authService.token!,
      );
    } catch (e) {
      if (mounted) _msg('$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _msg(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  Future<void> _form([Map<String, dynamic>? row]) async {
    final label = TextEditingController(text: row?['label'] ?? 'Home');
    final recipient = TextEditingController(
      text: row?['recipient_name'] ?? widget.authService.user?['name'] ?? '',
    );
    final phone = TextEditingController(
      text: row?['phone'] ?? widget.authService.user?['phone'] ?? '',
    );
    final line = TextEditingController(text: row?['address_line'] ?? '');
    final landmark = TextEditingController(text: row?['landmark'] ?? '');
    final city = TextEditingController(text: row?['city'] ?? '');
    final pin = TextEditingController(text: row?['pincode'] ?? '');
    bool isDefault = row?['is_default'] ?? rows.isEmpty;
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(
                row == null ? 'Add delivery address' : 'Edit address',
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final field
                            in <(TextEditingController, String)>[
                          (label, 'Label (Home / Work)'),
                          (recipient, 'Recipient name'),
                          (phone, 'Phone number'),
                          (line, 'Address'),
                          (landmark, 'Landmark (optional)'),
                          (city, 'City'),
                          (pin, 'PIN code'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TextFormField(
                              controller: field.$1,
                              decoration: InputDecoration(
                                labelText: field.$2,
                              ),
                              validator: field.$2.contains('optional')
                                  ? null
                                  : (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                            ),
                          ),
                        CheckboxListTile(
                          value: isDefault,
                          onChanged: (value) {
                            setDialogState(
                              () => isDefault = value ?? false,
                            );
                          },
                          title: const Text('Set as default address'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      formKey.currentState!.validate(),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true) {
      try {
        await ApiService.saveCustomerAddress(
          token: widget.authService.token!,
          address: {
            'label': label.text.trim(),
            'recipient_name': recipient.text.trim(),
            'phone': phone.text.trim(),
            'address_line': line.text.trim(),
            'landmark': landmark.text.trim().isEmpty
                ? null
                : landmark.text.trim(),
            'city': city.text.trim(),
            'pincode': pin.text.trim(),
            'is_default': isDefault,
          },
          addressId: row?['id'],
        );
        await _load();
      } catch (e) {
        if (mounted) _msg('$e');
      }
    }

    for (final controller in [
      label,
      recipient,
      phone,
      line,
      landmark,
      city,
      pin,
    ]) {
      controller.dispose();
    }
  }

  Future<void> _delete(int id) async {
    try {
      await ApiService.deleteCustomerAddress(
        token: widget.authService.token!,
        addressId: id,
      );
      await _load();
    } catch (e) {
      if (mounted) _msg('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Addresses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(),
        icon: const Icon(Icons.add),
        label: const Text('Add address'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
              ? const Center(
                  child: Text('No saved addresses. Add an address for delivery.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final address = Map<String, dynamic>.from(rows[index]);
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.location_on_outlined),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${address['label']} · ${address['recipient_name']}',
                              ),
                            ),
                            if (address['is_default'] == true)
                              const Chip(label: Text('Default')),
                          ],
                        ),
                        subtitle: Text(
                          '${address['address_line']}, ${address['city']} - ${address['pincode']}\n${address['phone']}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _form(address);
                            if (value == 'delete') {
                              _delete((address['id'] as num).toInt());
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class CustomerNotificationsPage extends StatefulWidget {
  final AuthService authService;

  const CustomerNotificationsPage({super.key, required this.authService});

  @override
  State<CustomerNotificationsPage> createState() =>
      _CustomerNotificationsPageState();
}

class _CustomerNotificationsPageState
    extends State<CustomerNotificationsPage> {
  List<dynamic> rows = [];
  bool loading = true;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _load();
    timer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final data = await ApiService.getNotifications(
        widget.authService.token!,
      );
      if (mounted) setState(() => rows = data);
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _read(int id) async {
    try {
      await ApiService.markNotificationRead(
        token: widget.authService.token!,
        notificationId: id,
      );
      await _load(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ApiService.markAllNotificationsRead(widget.authService.token!);
      await _load(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
              ? const Center(child: Text('You are all caught up.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final notification =
                          Map<String, dynamic>.from(rows[index]);
                      final isRead = notification['is_read'] == true;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isRead
                                ? Colors.grey.shade200
                                : const Color(0xFFDDF0D8),
                            child: Icon(
                              isRead
                                  ? Icons.notifications_none
                                  : Icons.notifications_active,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                          title: Text(
                            notification['title'] ?? 'Notification',
                            style: TextStyle(
                              fontWeight: isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${notification['message']}\n${notification['created_at'] ?? ''}',
                          ),
                          isThreeLine: true,
                          onTap: () => _read(
                            (notification['id'] as num).toInt(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class ScheduledDeliveriesPage extends StatefulWidget {
  final AuthService authService;

  const ScheduledDeliveriesPage({super.key, required this.authService});

  @override
  State<ScheduledDeliveriesPage> createState() =>
      _ScheduledDeliveriesPageState();
}

class _ScheduledDeliveriesPageState extends State<ScheduledDeliveriesPage> {
  List<dynamic> rows = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await ApiService.getMyOrders(widget.authService.token!);
      rows = all
          .where((order) => order['scheduled_delivery_at'] != null)
          .toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _date(dynamic value) {
    try {
      var raw = value.toString();
      if (!raw.endsWith('Z') &&
          !RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw)) {
        raw = '${raw}Z';
      }
      final date = DateTime.parse(raw).toLocal();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '$day/$month/${date.year} · $hour:$minute $period';
    } catch (_) {
      return value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scheduled Deliveries')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No scheduled deliveries yet. Choose a delivery date and time when placing your next order.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final order = rows[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.calendar_month),
                          ),
                          title: Text(
                            'Order #${order['id']} · ${order['status']}',
                          ),
                          subtitle: Text(
                            '${_date(order['scheduled_delivery_at'])}\n${order['delivery_slot'] ?? ''}',
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class AdminNotificationsPage extends StatelessWidget {
  final AuthService authService;

  const AdminNotificationsPage({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return CustomerNotificationsPage(authService: authService);
  }
}

class AdminOrdersPage extends StatefulWidget {
  final AuthService authService;

  const AdminOrdersPage({super.key, required this.authService});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  late Future<List<dynamic>> future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    future = ApiService.getAdminOrders(widget.authService.token!);
  }

  Future<void> _refresh() async {
    setState(_load);
    try {
      await future;
    } catch (_) {
      // The FutureBuilder displays the error state.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Management'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load orders: ${snapshot.error}'),
            );
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return const Center(child: Text('No customer orders yet.'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = Map<String, dynamic>.from(orders[index]);
                final customer =
                    Map<String, dynamic>.from(order['customer'] ?? {});
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.receipt_long),
                    ),
                    title: Text(
                      'Order #${order['id']} · ${order['status']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${customer['name'] ?? 'Customer'} · ${customer['phone'] ?? ''}\n'
                      '₹${order['total_amount']} · ${order['created_at'] ?? ''}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderDetailPage(
                            authService: widget.authService,
                            orderId: order['id'],
                          ),
                        ),
                      );
                      if (mounted) _refresh();
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class CategoryManagementPage extends StatefulWidget {
  final AuthService authService;

  const CategoryManagementPage({super.key, required this.authService});

  @override
  State<CategoryManagementPage> createState() =>
      _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  List<dynamic> rows = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      rows = await ApiService.getCategories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _add() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim().length >= 2,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await ApiService.createCategory(
          token: widget.authService.token!,
          name: controller.text.trim(),
        );
        await _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')),
          );
        }
      }
    }
    controller.dispose();
  }

  Future<void> _delete(int id) async {
    try {
      await ApiService.deleteCategory(
        token: widget.authService.token!,
        categoryId: id,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add category'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final category = rows[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: Text(category['name']),
                    subtitle: Text('Category ID: ${category['id']}'),
                    trailing: IconButton(
                      onPressed: () =>
                          _delete((category['id'] as num).toInt()),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
