# WP to Flutter - Cloud Build Engine 🚀

Automated cloud compiler service for the WP to Flutter WordPress plugin.

Every build request is guarded by a license key, compiled on GitHub's Linux
runners (Flutter stable + Java 17 + Temurin), and published as a GitHub
Release with both installable formats:

- **APK** (`app-release.apk`) — direct installation for testing on a phone.
- **AAB** (`app-release.aab`) — Android App Bundle for Google Play, Cafe Bazaar
  and Myket publishing.

The Android platform folder (`android/`) is **never committed** — the pipeline
generates fresh, always-up-to-date Gradle scaffolding on the runner with
`flutter create --platforms=android .` before compiling.

## 📱 Recent Applications Built

| نام وب‌سایت / اپلیکیشن | تاریخ ساخت | نسخه نصبی تستی (APK) | نسخه انتشار مارکت‌ها (AAB) |
| :--- | :--- | :--- | :--- |
| گجتال | 2026-10-30 16:32 UTC | [Download APK](https://github.com/mrpunisher1234-tech/wp-flutter-builder/releases/download/build-2/app-release.apk) | — |
| گجتال | 2026-10-30 17:12 UTC | — | [Download AAB](https://github.com/mrpunisher1234-tech/wp-flutter-builder/releases/download/build-3/app-release.aab) |
| گجتال | 2026-10-30 19:00 UTC | [Download APK](https://github.com/mrpunisher1234-tech/wp-flutter-builder/releases/download/build-4/app-release.apk) | — |
| گجتال | 2026-10-30 19:33 UTC | [Download APK](https://github.com/mrpunisher1234-tech/wp-flutter-builder/releases/download/build-6/app-release.apk) | — |
| گجتال | 2026-10-30 20:10 UTC | [Download APK](https://github.com/mrpunisher1234-tech/wp-flutter-builder/releases/download/build-9/app-release.apk) | — |
| گجتال | 2026-10-30 20:48 UTC | [Download APK](https://github.com/mrpunisher1234-tech/wp-flutter-builder/releases/download/build-11/app-release.apk) | — |
