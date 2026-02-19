# 🎓 Students Checker (Dinsctor)

A modern, real-time dual-screen attendance tracking system built with **Flutter** and **Firebase**.

This application allows a teacher to launch a "Projector Screen" via the Web, which syncs in real-time with a "Teacher Remote" Mobile App. Once linked, the system broadcasts a rotating attendance token (or QR Code) to the projector, ensuring secure and dynamic attendance tracking for the classroom.

---

## ✨ Features

* **Dual-Screen Architecture**: Runs seamlessly as a Web application (for classroom projectors) and an Android/iOS mobile application (for the teacher's remote control).
* **Real-time Synchronization**: Uses Firebase Cloud Firestore to instantly link the projector screen with the mobile remote using a 4-digit pairing code.
* **Dynamic Token Generation**: The "Brain" of the app automatically cycles through new attendance tokens every 7 seconds to prevent cheating or token-sharing.
* **Secure Authentication**: Built-in Firebase Authentication (Email/Password) for secure teacher login and registration.
* **Clean & Modern UI**: Flat-design principles implemented across both the Web Landing Screen and Mobile Login/Remote interfaces.

---

## 🛠️ Tech Stack

* **Framework**: [Flutter](https://flutter.dev/) (kIsWeb for dual-platform rendering)
* **Backend**: [Firebase](https://firebase.google.com/)
    * **Firestore**: Real-time NoSQL database for session/token broadcasting.
    * **Firebase Auth**: Secure Email & Password user authentication.
* **Language**: Dart

---

## 📂 Project Structure

```text
lib/
├── main.dart                      # App entry point & routing
├── firebase_options.dart          # Auto-generated Firebase config
├── screens/
│   ├── login_screen.dart          # Auth UI (Mobile)
│   ├── teacher_remote_screen.dart # Teacher Control Panel (Mobile)
│   └── web_landing_screen.dart    # Projector Display (Web)
└── services/
    └── attendance_service.dart    # Core logic, timers, and Firestore DB calls