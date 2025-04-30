# Voice-Driven To-Do List App

A cross-platform Flutter app to manage your to-do list with voice commands and real-time sync, powered by Firebase.

## Features

- **Google Sign-In & Email/Password Authentication**: Secure login for every user.
- **Per-User Task Storage**: Your tasks are private and synced across devices using Firestore.
- **Voice-Driven Task Management**: Add tasks by speaking (Chrome/Edge browsers or supported mobile devices).
- **Offline Support**: Work offline and sync automatically when back online.
- **Modern, Responsive UI**: Clean, accessible, and mobile/web-friendly.
- **Cross-Platform**: Works on Android, Windows, and Web (Chrome/Edge).

## Getting Started

### Prerequisites
- Flutter SDK (latest stable)
- Firebase project (with Firestore & Authentication enabled)
- Chrome or Edge browser for web voice support

### Setup
1. Clone this repository.
2. Run `flutter pub get` to install dependencies.
3. Configure Firebase:
   - Download your `google-services.json` (Android) and `firebase_options.dart` (for FlutterFire).
   - Enable Google Sign-In and Email/Password in Firebase Authentication.
   - Add your app's domain to Firebase authorized domains (for web).
4. Run the app:
   - Android: `flutter run -d android`
   - Windows: `flutter run -d windows`
   - Web: `flutter run -d edge` (for best voice support)

### Usage
- **Sign in** with Google or email/password.
- **Add tasks** by typing or using the mic button.
- **Complete or delete tasks** from your list.
- **Log out** from the menu.
- **Voice commands**: Speak your task and it will be added instantly (ensure mic permission is granted).

### Future Improvements
- Smarter voice command parsing (e.g., "complete buy milk").
- Task categories, reminders, and notifications.
- Collaboration and sharing features.
- Enhanced offline sync and undo/redo actions.
- Dark mode and accessibility enhancements.


*Made with Flutter, Firebase
