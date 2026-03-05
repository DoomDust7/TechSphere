import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    if (defaultTargetPlatform == TargetPlatform.iOS) return ios;
    throw UnsupportedError('No Firebase config for this platform.');
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCC6hk0cS_8Ap6xb0w4OZ6kaCtIjT5hsk4',
    appId: '1:394011305910:android:1b3960a51d828a339b0317',
    messagingSenderId: '394011305910',
    projectId: 'cupidity-flutter',
    storageBucket: 'cupidity-flutter.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCC6hk0cS_8Ap6xb0w4OZ6kaCtIjT5hsk4',
    appId: '1:394011305910:ios:REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: '394011305910',
    projectId: 'cupidity-flutter',
    storageBucket: 'cupidity-flutter.appspot.com',
    iosBundleId: 'in.co.cupidity.techsphere',
  );

  // Web: register a web app in Firebase Console → Project Settings → Add App → Web
  // then replace REPLACE_WITH_WEB_APP_ID with the appId from the config snippet.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCC6hk0cS_8Ap6xb0w4OZ6kaCtIjT5hsk4',
    appId: 'REPLACE_WITH_WEB_APP_ID',
    messagingSenderId: '394011305910',
    projectId: 'cupidity-flutter',
    authDomain: 'cupidity-flutter.firebaseapp.com',
    storageBucket: 'cupidity-flutter.appspot.com',
  );
}
