# Ejecutar desde la raíz del proyecto en PowerShell con Flutter instalado.
$ErrorActionPreference = 'Stop'
flutter doctor
flutter create --platforms=android --org com.tusolution --project-name tu_solution .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build apk --release
Write-Host 'APK generado en build\app\outputs\flutter-apk\app-release.apk'
