# 🎓 Dinsctor – Smart Classroom Attendance System

**Dinsctor** is a modern, cross-platform software solution designed to streamline classroom attendance through secure, dynamic QR code scanning. It bridges a Web-based projector display with mobile applications for both instructors and students, eliminating manual roll calls and proxy attendance.

---

## ✨ Key Features

### 👨‍🏫 For Teachers (Mobile Dashboard)
* **Secure QR Rotation:** Generates a new cryptographically secure QR payload at a user-defined interval (e.g., every 15 seconds) to prevent students from sharing screenshots.
* **Auto-Turn Off Mode:** Automatically closes the attendance session after a specified time limit.
* **Live Command Dashboard:** View an actively updating list of attendees and instantly revoke (kick) a student's attendance in real-time.
* **Native Data Export:** Export the attendance list to a formatted **PDF** or directly save a timestamped **Excel (CSV)** file to the device's local storage.
* **Recent History:** Quickly access and re-export the last 15 classroom sessions.

### 👩‍🎓 For Students (Mobile App)
* **High-Speed Optic Scanning:** Built-in camera scanner for rapid QR barcode decoding.
* **Live Classroom Sync:** View the instructor's name and a live list of peers currently checked into the room.
* **Auto-Kick Detection:** If a teacher revokes attendance, the student’s app instantly detects the database change and returns them to the scanner.

### 🖥️ For the Classroom (Web Projector)
* **Idle & Active States:** Displays a massive, randomly generated 4-digit code for the teacher to pair with, followed by a glowing, high-contrast QR matrix once the session starts.
* **Real-Time UI:** Updates instantly via WebSocket streams without requiring page refreshes.

---

## 🛠️ Technology Stack
* **Frontend:** Flutter (Dart) - Compiles to Android (APK/AAB), iOS (IPA), and Web.
* **Backend:** Firebase Authentication & Cloud Firestore (NoSQL).
* **Key Packages:**
  * `mobile_scanner` (Camera QR decoding)
  * `qr_flutter` (Web QR rendering)
  * `file_saver` & `csv` (Native Excel downloading)
  * `printing` & `pdf` (Native PDF generation)

---

## 🚀 Getting Started

### Prerequisites
1. [Flutter SDK](https://docs.flutter.dev/get-started/install) installed on your machine.
2. An active Firebase Project with **Authentication** (Email/Password) and **Firestore Database** enabled.

### Installation
1. **Clone the repository:**
   ```bash
   git clone [https://github.com/yourusername/dinsctor.git](https://github.com/yourusername/dinsctor.git)
   cd dinsctor
Install dependencies:

Bash
flutter pub get
Connect Firebase:

Download your google-services.json (for Android) and place it in android/app/.

Download your GoogleService-Info.plist (for iOS) and place it in ios/Runner/.

Ensure your firebase_options.dart is configured correctly for the Web module.

Run the application:
To run the mobile app (Teacher/Student):

Bash
flutter run
To run the projector web interface:

Bash
flutter run -d chrome
📂 Project Structure
Plaintext
lib/
│
├── main.dart                   # App entry point & Global Theme
├── firebase_options.dart       # Auto-generated Firebase configurations
│
├── screens/
│   ├── login_screen.dart           # Authentication & Role-routing
│   ├── student_screen.dart         # Scanner and Live Classroom UI
│   ├── teacher_remote_screen.dart  # Command Dashboard & Export Logic
│   └── web_landing_screen.dart     # Web Projector UI
│
└── services/
└── attendance_service.dart     # Core Firebase DB Logic & Stream handling
🔒 Security Architecture
Dinsctor implements strict security protocols to guarantee attendance validity:

Anti-Proxy Tokens: QR codes contain randomized numeric payloads rather than static URLs.

Concurrency Grace Periods: Network latency compensation allows simultaneous scans to process without false rejections.

Duplicate Entry Nullification: Prevents double-counting if a student scans the code multiple times.

📄 License
This project is licensed under the MIT License - see the LICENSE file for details.