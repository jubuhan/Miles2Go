// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDLrQuJqKP0NxtiL0Yjq3VSEgCDD6Iaehc',
    appId: '1:879955119702:web:403290265ec363f28775f7',
    messagingSenderId: '879955119702',
    projectId: 'sample2-bd1bb',
    authDomain: 'sample2-bd1bb.firebaseapp.com',
    storageBucket: 'sample2-bd1bb.firebasestorage.app',
    measurementId: 'G-CY0X6K1JJQ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBQ1SV_H56L20URrPVJN1L_pS3mCZlYfsM',
    appId: '1:879955119702:android:2336d69733a92ea38775f7',
    messagingSenderId: '879955119702',
    projectId: 'sample2-bd1bb',
    storageBucket: 'sample2-bd1bb.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA_zsIpIEYlVay4_6IWG6CxxGs9FYoaIDw',
    appId: '1:879955119702:ios:4b322491b29225a78775f7',
    messagingSenderId: '879955119702',
    projectId: 'sample2-bd1bb',
    storageBucket: 'sample2-bd1bb.firebasestorage.app',
    iosBundleId: 'com.example.miles2go',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA_zsIpIEYlVay4_6IWG6CxxGs9FYoaIDw',
    appId: '1:879955119702:ios:4b322491b29225a78775f7',
    messagingSenderId: '879955119702',
    projectId: 'sample2-bd1bb',
    storageBucket: 'sample2-bd1bb.firebasestorage.app',
    iosBundleId: 'com.example.miles2go',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDLrQuJqKP0NxtiL0Yjq3VSEgCDD6Iaehc',
    appId: '1:879955119702:web:6d0a3474ebe5c8418775f7',
    messagingSenderId: '879955119702',
    projectId: 'sample2-bd1bb',
    authDomain: 'sample2-bd1bb.firebaseapp.com',
    storageBucket: 'sample2-bd1bb.firebasestorage.app',
    measurementId: 'G-7F6DEPBBKP',
  );
}
