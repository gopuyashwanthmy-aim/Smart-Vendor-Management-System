# Smart Vendor build validation report

This report records checks performed while preparing this release candidate. It does not claim that the project has been deployed to public hosting.

## Passed

- Python source compilation: `python -m compileall -q app tests`.
- Backend test suite: 10 tests passed when executed with a test-only password-hasher stand-in. In a normal bare-runner invocation, 7 tests pass and the auth integration module skips because `pwdlib` is not installed in this build runner.
- Customer registration/login route tests: all 3 passed with the test-only password-hasher stand-in; the real Argon2 dependency is declared in `backend/requirements.txt` but was not available in this build runner.
- Production AI fallback test: verifies that active customer orders and inventory produce an order-based purchase recommendation when no real model is available.
- Model artifact persistence test: verifies a serialized model can be stored and loaded from the PostgreSQL-compatible model-artifact table using SQLite for the unit test.
- Database migrations: full empty-database migration chain executed successfully against SQLite as a portability check.
- Existing-database preservation: simulated a current schema with an existing admin row, ran the initializer, and verified the row remained present after Alembic head stamping.
- Alembic revision graph: one linear head, `cce7f19a4b21`.
- Production configuration: verified `APP_ENV=production` forces `ENABLE_DEMO_AI=false` even when the environment variable is accidentally set to true.
- Archive hygiene: excludes `.env`, virtual environments, Git history, database dumps, Python bytecode and unverified model files.

## Skipped / not run in this build environment

- Customer registration integration tests were skipped because `pwdlib` is not installed in the build runner. The required dependency is declared in `backend/requirements.txt`; these tests should run after installing project requirements.
- The PostgreSQL-specific migration execution was not run against a live PostgreSQL server in this environment; SQLite migration execution is a portability check, not a substitute for a hosted PostgreSQL smoke test.
- Flutter `analyze`, Flutter widget tests, web release build and Android APK release build were not run because the Flutter/Dart SDK is not installed in this build environment. Run them on the Windows development machine using the commands in `README.md`.
- Firebase, Render and Neon accounts were not created or accessed. Public deployment must be completed by the project owner after supplying account configuration and approving the database restore.

## Before public sharing

1. Run `pip install -r requirements.txt` and `python -m pytest -v` in the backend virtual environment.
2. Run `flutter pub get`, `flutter analyze` and `flutter test` in `frontend`.
3. Back up the existing local PostgreSQL database before migrating a copy to Neon.
4. Test customer registration, customer order placement, admin access, product management, inventory, financial reports and AI fallback against the hosted database.
5. Build the signed APK with a private keystore and build the Flutter website with the hosted API URL.
