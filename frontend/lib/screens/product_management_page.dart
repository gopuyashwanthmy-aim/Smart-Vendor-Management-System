import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';


class ProductManagementPage extends StatefulWidget {
  final AuthService authService;

  const ProductManagementPage({
    super.key,
    required this.authService,
  });

  @override
  State<ProductManagementPage> createState() =>
      _ProductManagementPageState();
}


class _ProductManagementPageState
    extends State<ProductManagementPage> {

  late Future<List<Product>> productsFuture;


  @override
  void initState() {
    super.initState();
    _loadProducts();
  }


  void _loadProducts() {
    productsFuture = ApiService.getProducts();
  }


  Future<void> _refreshProducts() async {
    setState(() {
      _loadProducts();
    });

    try {
      await productsFuture;
    } catch (_) {}
  }


  // =========================================================
  // ADD / EDIT DIALOG
  // =========================================================

  Future<void> _showProductDialog({
    Product? product,
  }) async {

    final isEditing = product != null;

    final nameController = TextEditingController(
      text: product?.name ?? '',
    );

    final unitController = TextEditingController(
      text: product?.unit ?? 'kg',
    );

    final priceController = TextEditingController(
      text: product?.price.toString() ?? '',
    );

    final stockController = TextEditingController(
      text: product?.stockQuantity.toString() ?? '0',
    );

    final categoryController = TextEditingController(
      text: product?.categoryId.toString() ?? '',
    );

    final imageController = TextEditingController(
      text: product?.imageUrl ?? '',
    );


    String? errorMessage;


    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: Text(
                isEditing
                    ? 'Edit Product'
                    : 'Add Product',
              ),

              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Product Name',
                          hintText: 'Example: Tomato',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: unitController,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          hintText: 'kg / piece / dozen',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: priceController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Selling Price',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: stockController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Initial Stock',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: categoryController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Category ID',
                          hintText: 'Example: 1',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: imageController,
                        decoration: const InputDecoration(
                          labelText: 'Image URL (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              actions: [

                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      false,
                    );
                  },
                  child: const Text('Cancel'),
                ),

                FilledButton(
                  onPressed: () async {

                    final name =
                        nameController.text.trim();

                    final unit =
                        unitController.text.trim();

                    final price =
                        double.tryParse(
                      priceController.text.trim(),
                    );

                    final stock =
                        double.tryParse(
                      stockController.text.trim(),
                    );

                    final categoryId =
                        int.tryParse(
                      categoryController.text.trim(),
                    );

                    if (name.isEmpty) {
                      setDialogState(() {
                        errorMessage =
                            'Product name is required.';
                      });
                      return;
                    }

                    if (unit.isEmpty) {
                      setDialogState(() {
                        errorMessage =
                            'Unit is required.';
                      });
                      return;
                    }

                    if (price == null || price <= 0) {
                      setDialogState(() {
                        errorMessage =
                            'Enter a valid price greater than 0.';
                      });
                      return;
                    }

                    if (stock == null || stock < 0) {
                      setDialogState(() {
                        errorMessage =
                            'Enter a valid stock quantity.';
                      });
                      return;
                    }

                    if (categoryId == null ||
                        categoryId <= 0) {
                      setDialogState(() {
                        errorMessage =
                            'Enter a valid category ID.';
                      });
                      return;
                    }


                    try {

                      if (isEditing) {
                        await ApiService.updateProduct(
                          productId: product.id,
                          name: name,
                          unit: unit,
                          price: price,
                          stockQuantity: stock,
                          categoryId: categoryId,
                          imageUrl:
                              imageController.text
                                      .trim()
                                      .isEmpty
                                  ? null
                                  : imageController.text
                                      .trim(),
                          token:
                              widget.authService.token!,
                        );
                      } else {
                        await ApiService.createProduct(
                          name: name,
                          unit: unit,
                          price: price,
                          stockQuantity: stock,
                          categoryId: categoryId,
                          imageUrl:
                              imageController.text
                                      .trim()
                                      .isEmpty
                                  ? null
                                  : imageController.text
                                      .trim(),
                          token:
                              widget.authService.token!,
                        );
                      }

                      if (!context.mounted) {
                        return;
                      }

                      Navigator.pop(
                        dialogContext,
                        true,
                      );

                    } catch (e) {

                      setDialogState(() {
                        errorMessage =
                            e.toString();
                      });
                    }
                  },

                  child: Text(
                    isEditing
                        ? 'Save Changes'
                        : 'Add Product',
                  ),
                ),
              ],
            );
          },
        );
      },
    );


    nameController.dispose();
    unitController.dispose();
    priceController.dispose();
    stockController.dispose();
    categoryController.dispose();
    imageController.dispose();


    if (result == true && mounted) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Product updated successfully.'
                : 'Product added successfully.',
          ),
        ),
      );

      await _refreshProducts();
    }
  }


  // =========================================================
  // DELETE PRODUCT
  // =========================================================

  Future<void> _deleteProduct(
    Product product,
  ) async {

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Product?',
          ),

          content: Text(
            'Are you sure you want to delete '
            '"${product.name}"?',
          ),

          actions: [

            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );


    if (confirmed != true) {
      return;
    }


    try {

      await ApiService.deleteProduct(
        productId: product.id,
        token: widget.authService.token!,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Product deleted successfully.',
          ),
        ),
      );

      await _refreshProducts();

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Unable to delete product: $e',
          ),
        ),
      );
    }
  }


  // =========================================================
  // PRODUCT CARD
  // =========================================================

  Widget _buildProductCard(
    Product product,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [

            Row(
              children: [

                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(12),
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                  ),
                  child:
                      product.imageUrl != null &&
                              product.imageUrl!
                                  .isNotEmpty
                          ? ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(
                                12,
                              ),
                              child: Image.network(
                                product.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                                  return const Icon(
                                    Icons
                                        .inventory_2_outlined,
                                  );
                                },
                              ),
                            )
                          : const Icon(
                              Icons
                                  .inventory_2_outlined,
                            ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                PopupMenuButton<String>(
                  onSelected: (value) {

                    if (value == 'edit') {
                      _showProductDialog(
                        product: product,
                      );
                    }

                    if (value == 'delete') {
                      _deleteProduct(product);
                    }
                  },

                  itemBuilder: (context) {
                    return const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              '₹${product.price} / ${product.unit}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Stock: ${product.stockQuantity} ${product.unit}',
            ),

            const SizedBox(height: 4),

            Text(
              'Category ID: ${product.categoryId}',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const Spacer(),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showProductDialog(
                    product: product,
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Product'),
              ),
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
          'Product Management',
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshProducts,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: () {
          _showProductDialog();
        },
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Product',
        ),
      ),

      body: FutureBuilder<List<Product>>(
        future: productsFuture,

        builder: (
          context,
          snapshot,
        ) {

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
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

                    const SizedBox(
                      height: 12,
                    ),

                    const Text(
                      'Failed to load products.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    Text(
                      '${snapshot.error}',
                      textAlign:
                          TextAlign.center,
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    FilledButton.icon(
                      onPressed:
                          _refreshProducts,
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


          final products =
              snapshot.data ?? [];


          if (products.isEmpty) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [

                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    const Text(
                      'No products found.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    const Text(
                      'Add your first product to get started.',
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    FilledButton.icon(
                      onPressed: () {
                        _showProductDialog();
                      },
                      icon: const Icon(
                        Icons.add,
                      ),
                      label: const Text(
                        'Add Product',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }


          return RefreshIndicator(
            onRefresh:
                _refreshProducts,

            child: LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {

                final width =
                    constraints.maxWidth;

                int columns;

                if (width >= 1200) {
                  columns = 4;
                } else if (width >= 800) {
                  columns = 3;
                } else if (width >= 550) {
                  columns = 2;
                } else {
                  columns = 1;
                }


                return GridView.builder(
                  physics:
                      const AlwaysScrollableScrollPhysics(),

                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    100,
                  ),

                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio:
                        columns == 1
                            ? 1.7
                            : 1.15,
                  ),

                  itemCount:
                      products.length,

                  itemBuilder: (
                    context,
                    index,
                  ) {
                    return _buildProductCard(
                      products[index],
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}