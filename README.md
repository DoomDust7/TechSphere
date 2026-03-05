# TechSphere — Real-time Chat App

A Flutter chat application with Google Sign-In, real-time messaging, typing indicators, online status, and image/sticker sharing — powered by Firebase.

## Features

| Feature | Details |
|---------|---------|
| **Auth** | Google Sign-In via Firebase Authentication |
| **Conversations list** | Shows all your chats with last message + unread count |
| **Real-time messaging** | Text, images, and stickers (9 included) |
| **Typing indicator** | Shows "typing…" when the other person is composing |
| **Online / Last seen** | Live presence in the chat header |
| **Read receipts** | Double tick (✓✓) when your message is read |
| **Image upload** | Send photos from gallery; stored in Firebase Storage |
| **Profile settings** | Change display name, bio, and profile photo |
| **Flutter Web** | Builds and runs in the browser via Firebase Hosting |

## Tech Stack

- **Flutter 3.x** — UI framework (Android, iOS, Web)
- **Firebase Auth 4.x** — Google Sign-In
- **Cloud Firestore 4.x** — real-time messages & user data
- **Firebase Storage 11.x** — image uploads
- **google_sign_in, cached_network_image, photo_view, timeago**

## Firestore Schema

```
usersChat/{userId}                        — profile, isOnline, lastSeen, typingTo
messages/{chatId}/{chatId}/{msgId}        — content, type, timestamp, isRead
conversations/{userId}/chats/{otherId}    — lastMessage, unreadCount
```

## Getting Started

### Prerequisites
- Flutter ≥ 3.11 (`flutter --version`)
- A Firebase project

### Firebase Setup
1. Create a project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication → Google**
3. Enable **Cloud Firestore** and **Storage**
4. Add an **Android app** (package `in.co.cupidity_flutter`) → download `google-services.json` → `android/app/`
5. Add a **Web app** → copy the `appId` into `lib/firebase_options.dart` under `web:`

### Run locally
```bash
flutter pub get
flutter run -d chrome          # web
flutter run                    # Android / iOS
```

### Deploy to Firebase Hosting
```bash
npm install -g firebase-tools
firebase login
firebase init hosting          # public dir: build/web, SPA: yes
flutter build web
firebase deploy
```
Live at: `https://cupidity-flutter.web.app`

## Migration from original (Cupidity Chat 2019)

The original repo used Firebase SDK 0.x which is completely incompatible with modern Flutter. All APIs were rewritten:

| Old | New |
|-----|-----|
| `Firestore.instance` | `FirebaseFirestore.instance` |
| `collection.document(id)` | `collection.doc(id)` |
| `snapshot.documents` | `snapshot.docs` |
| `FirebaseUser` | `User` |
| `GoogleAuthProvider.getCredential()` | `GoogleAuthProvider.credential()` |
| `FlatButton / RaisedButton` | `TextButton / ElevatedButton` |
| `ImagePicker.pickImage()` (static) | `ImagePicker().pickImage()` (instance, `XFile?`) |

New features added: conversations list, typing indicator, online/last-seen presence, read receipts.

## License

MIT
