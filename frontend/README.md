# Smart Vendor Flutter client

This folder contains the Flutter Web and Android application source.

For the complete Windows CMD setup, Firebase Hosting deployment, Android APK signing/build, and backend connection instructions, see the project-root `README.md`.

The hosted API URL is supplied at build time with:

```cmd
flutter build web --release --dart-define=API_BASE_URL=https://YOUR_API_HOST
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_API_HOST
```
