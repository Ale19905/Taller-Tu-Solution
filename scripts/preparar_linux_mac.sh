#!/usr/bin/env bash
set -euo pipefail
flutter doctor
flutter create --platforms=android --org com.tusolution --project-name tu_solution .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build apk --release
echo 'APK en build/app/outputs/flutter-apk/app-release.apk'
