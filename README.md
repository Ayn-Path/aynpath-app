# aynpath-app

## Overview
AynPath App is a Flutter-based mobile application designed to provide **indoor navigation** with features such as:
- AR visual arrows for real-time guidance  
- Audio and haptic feedback for accessibility  
- Obstacle detection using computer vision  
- Seamless integration with the AynPath server for localization and VPS matching

This app is part of the **AynPath project**:  
- [aynpath-datasets](https://github.com/Ayn-Path/aynpath-datasets) – ORB features datasets  
- [aynpath-server](https://github.com/Ayn-Path/aynpath-server) – backend for localization

## Getting Started
### Setup
- [Flutter](https://docs.flutter.dev/get-started/install) (version 3.32.0)
- Android Studio / VS Code with Flutter plugin  
- Android device or emulator (iOS also supported if you have a Mac)

### Run the Project
Remember!: Before launching the app, you need to start the server. You can learn more about the server at [here](https://github.com/Ayn-Path/aynpath-server)

(1) Clone the app repo
```bash
git clone https://github.com/Ayn-Path/aynpath-app.git
cd aynpath-app
```

(2) Install dependencies
```bash
flutter pub get
```

(3) Run the app (make sure the server is already running)
```bash
flutter run
```
## Development Device
Tested on:
* Device: Samsung Galaxy A52
* OS: Android 13

## Release
You can download the latest release APK here

# Notes/Limitations
* The app **requires AynPath Server** to be running before launch.  
* Currently tested only on **Android** devices. iOS cannot run this app.  
* AR features require **ARCore (Android)**.  
* Obstacle detection performance may vary depending on the environment (e.g., lighting, camera).  
* Large datasets may increase startup time and memory usage.  
* Project is under **active development** – breaking changes may occur.  

## Known Development Issues
* **Namespace conflicts** sometimes occur when upgrading Flutter or dependencies.  
* **Dependency version mismatches** (e.g., incompatible plugin versions).   
* Mismatched Namespace in AndroidManifest.xml and build.gradle
  - Since Flutter 3.0, Android projects use the namespace property in android/app/build.gradle.
  - If this doesn’t match the package declared in AndroidManifest.xml, you’ll get build errors.

  Fix:
  * Open android/app/build.gradle
  * Make sure namespace matches your package name (e.g., com.aynpath.app):
  ```gradle
  android {
    namespace "com.aynpath.app"
    compileSdkVersion 34
    ...
  }
  ```
  * Check that your AndroidManifest.xml also uses the same package:
  ```xml
  <manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.aynpath.app">
  ```

## References
