# 🛡️ Honos Attendance System

[![Download Android APK](https://img.shields.io/badge/Download-Android_APK-3B82F6?style=for-the-badge&logo=android)](https://github.com/shivansh-121/honos-attendance-system/raw/main/honos_attendance_system/docs/Honos_Attendance.apk)
[![Download Portal](https://img.shields.io/badge/Client-Download_Portal-8B5CF6?style=for-the-badge&logo=googlechrome)](https://shivansh-121.github.io/honos-attendance-system/)

A premium, cross-platform workforce management solution designed for **Honos Security Services**. This application leverages AI-driven liveness detection and automated "Floating Guard" logic to provide a seamless, maintenance-free attendance experience.

---

## 🚀 Key Innovations

### 🤖 Intelligent "Floating Guard" System
*   **Zero-Maintenance Transfers**: Guards are no longer locked to a single site. The system "learns" where a guard is working based on where their attendance is marked.
*   **Global Search**: Supervisors can mark attendance for ANY guard in the company using a fast search bar (Name or Employee ID).
*   **Automated Site-Linking**: Marking attendance at a site automatically re-assigns the guard to that site's local dashboard, eliminating manual Admin work.

### 🎭 AI Liveness & Face Verification
*   **Blink Detection**: Prevents photo-spoofing by requiring a real-time blink during attendance marking.
*   **Facial Matching**: Real-time comparison between the guard's registered profile and their live selfie using **Google ML Kit**.
*   **Supervisor Override**: Integrated safety-valve for emergency situations where manual verification is needed.

### 📍 Precision Geo-Fencing
*   **Instant Verification**: Optimized location logic prioritizes "Last Known Position" for a <0.5s booting experience on all devices.
*   **Dynamic Radius**: Geo-fencing ensures attendance can only be marked within a specific radius of the site coordinates.

---

## 🛠️ Tech Stack & Architecture

| Category | Technology Used |
| :--- | :--- |
| **Framework** | Flutter (Dart) |
| **Database** | Firebase Firestore (Real-time Cloud Sync) |
| **Local Cache** | Hive (Offline-first architecture) |
| **State Management** | Riverpod |
| **AI/ML** | Google ML Kit (Face Detection) |
| **Maps** | OpenStreetMap (flutter_map) |

---

## 📋 Features Overview

### 👑 Admin Panel
- **Supervisor Management**: Create, edit, and delete supervisor accounts.
- **Site Management**: Define site locations, coordinates, and geofence radii.
- **Global Visibility**: Monitor attendance and guard distribution across all company sites in real-time.

### 👮 Supervisor Dashboard
- **Instant Attendance**: Rapid 3-step process (Location -> Search -> Verification).
- **My Guards**: Dynamic local list of guards currently assigned to the site.
- **On-Duty Tracking**: Real-time status updates for the entire team.

---

## 🚀 Getting Started

1.  **Environment Setup**:
    ```bash
    flutter pub get
    ```
2.  **Firebase Integration**:
    Ensure your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are placed in the correct directories.
3.  **Clean Build**:
    ```bash
    flutter clean
    flutter run
    ```

---

## 📱 Platforms Support
- **Android**: Full feature set (GPS, Camera, Background Services).
- **iOS**: Full feature set.
- **Web**: Optimized for Admin/Supervisor dashboard testing.
- **Windows**: Admin Panel support only.

---

Developed with ❤️ for **Honos Security Services**.
