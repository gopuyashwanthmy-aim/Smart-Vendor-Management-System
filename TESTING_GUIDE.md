# Smart Vendor – local test guide for the customer experience upgrade

## Important safety note

Test this updated copy against your **local development database**, not the live Neon database. Keep your existing database backup unchanged. The new database changes are additive: one address table, one notification table, and nullable scheduled-delivery/address columns on orders.

## 1. Start the backend

Open CMD in `backend`:

```cmd
venv\Scripts\activate
python -m app.init_db
uvicorn app.main:app --reload
```

`app.init_db` applies the new Alembic revision when migration history exists. For an older restored local database without Alembic history, it adds the new tables/columns and preserves existing rows.

Open `http://127.0.0.1:8000/docs` and confirm the new route groups:

- Categories
- Customer
- Orders

## 2. Start Flutter Web

Open a second CMD in `frontend`:

```cmd
flutter pub get
flutter analyze
flutter run -d chrome
```

The local API default is `http://127.0.0.1:8000`. Do not build/deploy to Firebase until the complete test checklist below passes.

## 3. Customer checklist

- Open the hamburger drawer and visit Home, My Profile, Delivery Address, My Cart, My Orders, Scheduled Delivery, Notifications and Logout.
- Confirm the page theme uses pale/light green backgrounds and green accents.
- Check category chips and verify that selecting a category filters products.
- Search for a product by name; clear the search and verify all products return.
- Open the price filter and apply/clear a maximum price.
- Confirm products with zero availability show Out of stock and cannot be added to the cart.
- Confirm low remaining stock is labelled Low stock.
- Add, edit, set-default and delete a delivery address.
- Update the customer display name in My Profile.
- Add an item to cart and checkout with an address, leaving Schedule delivery off.
- Place another test order with Schedule delivery on, selecting a future date and time slot.
- Confirm My Orders displays order status, delivery address and scheduled delivery details.
- Open Scheduled Delivery and confirm the scheduled order appears.
- Open Notifications and confirm the order-placed notification appears.

## 4. Admin checklist

- Log in as admin and verify the hamburger drawer contains the existing modules.
- Open Product Categories and add a test category.
- Open Product Management and verify category selection is a dropdown populated from saved categories.
- Add a test product to the test category; add inventory for it if using inventory batches.
- Open Orders and confirm the test customer order appears.
- Open the order and advance statuses one stage at a time: CONFIRMED, PURCHASING, READY, DELIVERED.
- Open admin Notifications and confirm a new-order notification is present.

## 5. Verify customer notifications for every order stage

After the admin advances an order, log back in as that customer and open Notifications. Expected events:

1. Order placed (PLACED).
2. Order confirmed (CONFIRMED).
3. Vendor purchasing (PURCHASING).
4. Ready for delivery (READY).
5. Delivered (DELIVERED).

Notifications are stored in the app and the Notifications page refreshes while open. This build does not configure operating-system/browser push notifications; Firebase Cloud Messaging setup is a separate integration requiring client configuration and permission handling.

## 6. Stock behaviour

When inventory batches exist for a product, checkout checks unreserved `remaining_quantity` and reserves the ordered quantity. When no inventory batches exist, checkout checks and reduces the product's `stock_quantity`. Delivery processing continues to use the existing FIFO costing service.

Use test products/orders for validation. Do not use an existing live order to test stock deduction.

## Test status from the build environment

- Backend Python compile check: passed.
- Existing backend tests: 7 passed, 1 skipped.
- API integration smoke tests (categories, address create/list, scheduled order creation, availability deduction, and the full five-stage notification lifecycle through DELIVERED): passed.
- Fresh Alembic migration on a temporary SQLite database: passed.
- Legacy database initializer simulation (no Alembic version table): passed; new tables and columns were added without removing rows.
- Flutter analysis/build: run on your Windows machine using the commands above; Flutter SDK is not installed in the build environment used to prepare this archive.
