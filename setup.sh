#!/usr/bin/env bash
# One-time setup: generates the Android/iOS platform folders with Flutter,
# then lays the Gratideo Android files over them. Run from this folder.
set -euo pipefail

command -v flutter >/dev/null || { echo "Install Flutter first: https://docs.flutter.dev/get-started/install"; exit 1; }

echo "1/4  Generating platform folders"
flutter create --org com.isaacmunandar --project-name gratideo --platforms android,ios . >/dev/null

echo "2/4  Applying the Android overlay (manifest + MainActivity)"
mkdir -p android/app/src/main/kotlin/com/isaacmunandar/gratideo
cp android_overlay/app/src/main/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
cp android_overlay/app/src/main/kotlin/com/isaacmunandar/gratideo/MainActivity.kt android/app/src/main/kotlin/com/isaacmunandar/gratideo/MainActivity.kt

# flutter create drops its counter-sample test in, which does not compile against
# this app. Our tests live in test/auth_test.dart and test/content_test.dart.
rm -f test/widget_test.dart

echo "3/4  Patching android/app/build.gradle(.kts): minSdk 23 + core library desugaring"
python3 - <<'PY'
import pathlib, re
kts = pathlib.Path("android/app/build.gradle.kts")
groovy = pathlib.Path("android/app/build.gradle")
if kts.exists():
    s = kts.read_text()
    s = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 23", s)
    if "isCoreLibraryDesugaringEnabled" not in s:
        s = s.replace("compileOptions {", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
    if "coreLibraryDesugaring(" not in s:
        s = s.rstrip() + '\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    kts.write_text(s)
    print("patched build.gradle.kts")
elif groovy.exists():
    s = groovy.read_text()
    s = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion|minSdk\s*=?\s*flutter\.minSdkVersion", "minSdk 23", s)
    if "coreLibraryDesugaringEnabled" not in s:
        s = s.replace("compileOptions {", "compileOptions {\n        coreLibraryDesugaringEnabled true", 1)
    if "coreLibraryDesugaring " not in s:
        s = s.rstrip() + "\n\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    groovy.write_text(s)
    print("patched build.gradle")
else:
    print("no app gradle file found; patch minSdk 23 + desugaring by hand (see README)")
PY

echo "4/4  Fetching packages"
flutter pub get

echo
echo "Done. Plug in the Fold (USB debugging on) and run:  flutter run --release"
