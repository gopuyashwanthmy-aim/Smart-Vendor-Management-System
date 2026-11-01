import '../models/cart_item.dart';
import '../models/product.dart';

class CartService {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  void addProduct(Product product) {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex != -1) {
      _items[existingIndex].quantity += 1;
    } else {
      _items.add(
        CartItem(product: product),
      );
    }
  }

  void increaseQuantity(Product product) {
    final item = _findItem(product);

    if (item != null) {
      item.quantity += 1;
    }
  }

  void decreaseQuantity(Product product) {
    final item = _findItem(product);

    if (item != null) {
      item.quantity -= 1;

      if (item.quantity <= 0) {
        removeProduct(product);
      }
    }
  }

  void removeProduct(Product product) {
    _items.removeWhere(
      (item) => item.product.id == product.id,
    );
  }

  double get total {
    return _items.fold(
      0,
      (sum, item) => sum + item.totalPrice,
    );
  }

  int get itemCount {
    return _items.length;
  }

  CartItem? _findItem(Product product) {
    try {
      return _items.firstWhere(
        (item) => item.product.id == product.id,
      );
    } catch (_) {
      return null;
    }
  }

  void clear() {
    _items.clear();
  }
}