# Smart Vendor – Final Deployment Candidate

Flutter Web + Android APK + FastAPI + PostgreSQL for customer ordering and vendor operations. This package is configured for a public demo/prototype deployment on free tiers. Free hosting is not guaranteed to be continuously available.

## Roles and capabilities

- **Customers:** register with name, phone and password; log in; browse products; add items to cart; place orders; view their order history.
- **Admin:** log in using an existing admin account; manage products, orders, inventory/purchases, walk-in sales, financial summaries and AI planning.
- Public registration always creates `customer` accounts. It never accepts or grants the `admin` role. Phone/password login does not include SMS OTP verification; do not use weak or shared passwords.

## Architecture

- Flutter Web: Firebase Hosting (Spark/free tier).
- FastAPI: Render free web service (sleeps after inactivity).
- PostgreSQL: Neon free project (usage/storage quotas and scale-to-zero).
- Android: build a signed APK locally and install directly or distribute through a suitable release channel. Firebase Spark Hosting blocks APK/other executable uploads, so do not upload the APK to Firebase Hosting.

Official free-tier limitations change; check provider dashboards before deployment. Render free web services spin down after 15 minutes idle and free Render PostgreSQL expires after 30 days, so this project uses Neon for the hosted database. Neon Free currently documents 1 GB storage per project, 100 compute-hours per project per month and scale-to-zero; Firebase Hosting has no-cost quotas on Spark. Firebase Spark blocks hosting certain executable files such as APKs, so build and distribute the APK separately.

## Important data-preservation policy

**Do not run `docker compose down -v`. Do not delete the Docker volume.** The local PostgreSQL database is not embedded in this ZIP. The package does not reset it. To deploy with the existing data, create a private backup and restore a copy into a new hosted PostgreSQL database. Keep the local database and backup unchanged. The dump may contain customer names, phone numbers, order details and password hashes; only migrate/share it if you are authorized to use that information in a public demo. This release ZIP itself contains no database dump.

### 1. Local backup (Windows PowerShell)

From the project root, with Docker Desktop and the existing `smart_vendor_db` container running:

```powershell
.\scripts\backup_local_db.ps1
```

This creates `backups/smart_vendor_backup.dump`. Treat it as sensitive: it contains customer phone numbers, password hashes, orders and business data. Do not commit or publicly share it.

### 2. Create Neon database

1. Create a Neon account and a new PostgreSQL project/database.
2. Copy the connection details from the Neon dashboard. Use the pooled connection string for the app if available; keep `sslmode=require`.
3. For the initial `pg_restore`, use the direct (non-pooler) connection host if Neon shows both direct and pooled endpoints. Note the host, port, database name, username and password separately for the restore script.
4. Restore only into a new/empty hosted database.

### 3. Restore a copy of local data to Neon

Run from PowerShell (replace placeholders with values shown by Neon):

```powershell
.\scripts\restore_to_hosted_postgres.ps1 -HostName "YOUR_NEON_HOST" -Port 5432 -Database "YOUR_DATABASE" -Username "YOUR_USERNAME"
```

The script asks for the password securely and requires you to type `RESTORE`. It uses `pg_restore` without `--clean` or `--drop`. If the target database is not empty, stop and use a fresh Neon database instead. The source/local database is never changed. After restoring, configure `backend/.env`, run `python -m app.init_db`, then `python -m app.verify_db` and compare the counts with the source before switching the frontend to the hosted API.

### 4. Create or verify the admin account

If the migrated database already contains your admin account, use it. If no admin account is available, run this only against your own hosted database after configuring `backend/.env`:

```cmd
cd backend
copy .env.example .env
REM Edit .env and set the hosted DATABASE_URL, a strong SECRET_KEY, APP_ENV=production
python -m app.create_admin
```

This is a terminal-only operation. Never expose admin bootstrap as a public API endpoint.

## Backend deployment – Render

1. Create a private GitHub repository and push this project. Typical commands from the project root are:

   ```cmd
   git init
   git add .
   git commit -m "Prepare Smart Vendor deployment"
   git branch -M main
   git remote add origin https://github.com/YOUR_ACCOUNT/YOUR_REPOSITORY.git
   git push -u origin main
   ```

   Do not add `.env`, database dumps, `key.properties`, `.jks` or passwords.
2. In Render, create a Blueprint from the repository and use the included `render.yaml`, or create a Python Web Service with root directory `backend`.
3. Build command: `pip install -r requirements.txt`
4. Start command: `python -m app.init_db && uvicorn app.main:app --host 0.0.0.0 --port $PORT`
5. Set these environment variables in Render:
   - `APP_ENV=production`
   - `DATABASE_URL` = Neon PostgreSQL URL (SQLAlchemy/psycopg2 compatible, `sslmode=require`)
   - `SECRET_KEY` = unique random secret, at least 32 characters
   - `CORS_ORIGINS` = Firebase site origin(s), e.g. `https://YOUR_PROJECT.web.app,https://YOUR_PROJECT.firebaseapp.com`
   - `ENABLE_DEMO_AI=false`
   - `DB_POOL_SIZE=2`, `DB_MAX_OVERFLOW=1`
6. Wait for deploy. Test `/health`, `/health/ready`, and `/docs`. The readiness route must return `database: connected`.

`app.init_db` runs Alembic migrations on an empty database. For an imported current database without an Alembic version table, it checks required current tables/columns and stamps the current head only after the schema check passes. It never drops business data. If the schema check fails, it stops rather than guessing.

## Flutter website – Firebase Hosting

Install Flutter and Firebase CLI on Windows. Sign in to Firebase and create a Spark project.

```cmd
npm install -g firebase-tools
firebase login
firebase projects:list
copy .firebaserc.example .firebaserc
REM Edit .firebaserc and replace YOUR_FIREBASE_PROJECT_ID
set API_BASE_URL=https://YOUR_RENDER_SERVICE.onrender.com
call scripts\build_web.cmd
firebase deploy --only hosting
```

The Firebase website URL will be `https://YOUR_PROJECT.web.app` (or `firebaseapp.com`). Add both origins to Render `CORS_ORIGINS` and redeploy the backend if necessary.

## Android APK

The Android application ID is `com.smartvendor.app`; the app label is `Smart Vendor`; Internet permission is enabled. Create your own release signing key and keep it private. Do not put it in GitHub or send it to anyone.

From `frontend\android` in CMD, create a keystore (run once):

```cmd
keytool -genkeypair -v -keystore app\smart-vendor-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias smartvendor
```

Create `frontend\android\key.properties` (this file is ignored by Git):

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=smartvendor
storeFile=app/smart-vendor-release.jks
```

Then from the project root in CMD:

```cmd
set API_BASE_URL=https://YOUR_RENDER_SERVICE.onrender.com
call scripts\build_android_apk.cmd
```

APK output: `frontend\build\app\outputs\flutter-apk\app-release.apk`. Transfer it to the Android phone and install it. Firebase Spark Hosting blocks APK uploads; use direct USB/nearby sharing or a suitable release asset service if you need a public APK link.

**Back up the keystore and passwords securely.** Losing them prevents signing future updates with the same app identity.

## AI production behaviour

- Synthetic demo training is disabled whenever `APP_ENV=production`, regardless of `ENABLE_DEMO_AI`.
- The `/admin/ai/train-demo` endpoint is not registered in production.
- AI insights and AI market plan use a verified real-data model only when a real model is present and the product has sufficient actual history. Otherwise they return an order-based fallback based on active `PLACED`/`CONFIRMED` orders and recorded inventory. They do not invent forecasts.
- The real-data readiness gate requires at least 30 calendar days of observed history and at least 14 distinct transaction days.
- Trained model artifacts are stored in PostgreSQL, not only on the Render filesystem, so a Render restart does not erase the trained model.

## Local development (Windows CMD)

```cmd
docker compose up -d
cd backend
copy .env.example .env
REM Keep APP_ENV=development and local DATABASE_URL for local development
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python -m app.init_db
uvicorn app.main:app --reload
```

Open another CMD:

```cmd
cd frontend
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## Tests and validation

Backend tests (run inside the backend virtual environment):

```cmd
set DATABASE_URL=sqlite:///./test-run.sqlite
python -m pytest -v
```

Flutter checks:

```cmd
cd frontend
flutter analyze
flutter test
```

Deployment validation checklist:

- `/health/ready` confirms the hosted PostgreSQL connection.
- Existing admin account can log in.
- A new customer can register; the returned role is always `customer`.
- Customer can browse products and place an order.
- Admin can create/edit products, manage orders, inventory and sales.
- Admin-only endpoints reject customer tokens with HTTP 403.
- AI endpoints report `order_based_fallback` when no verified real model is available.
- Refresh the web app and confirm it still calls the hosted API.
- Install the signed APK and repeat customer/admin login tests.

## Known prototype limitations

- Render free backend instances sleep after inactivity and may take time to wake.
- Neon free database has quotas and can scale to zero. Monitor usage and keep independent backups.
- No SMS OTP, payment gateway, delivery tracking or push notifications are included unless already supported by the existing application.
- This is a public demo/prototype deployment configuration, not a guarantee of uninterrupted production service.
