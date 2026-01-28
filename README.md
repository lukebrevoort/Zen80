# Zen 80 🧘

Zen 80 is a Flutter productivity tracking app that helps you achieve **80%+ Signal Ratio** through intentional daily planning and focus management.

## 🎯 Core Concept

**Signal vs. Noise Philosophy:**

- **Signal** = Focused work on 3-5 critical daily tasks that move your goals forward
- **Noise** = Everything else (meetings, emails, admin work, distractions)
- **Goal** = Achieve 80%+ Signal Ratio by intentionally planning and protecting your focus time

Zen 80 helps you identify what matters most each day, schedule dedicated time for it, and track whether you're actually spending your time on what you said was important.

## ✨ Features

### 📋 Daily Planning Flow

- **Morning Planning**: Choose 3-5 Signal tasks for the day
- **Time Estimation**: Estimate how long each task will take
- **Calendar Integration**: See your existing commitments while planning
- **Smart Scheduling**: Block time for your Signal tasks in Google Calendar

### 📅 Google Calendar Integration

- **Two-way sync** with Google Calendar
- **Import existing events** as Signal tasks
- **External event handling**: Mark calendar events as Signal work
- **Automatic time blocking**: Creates calendar events when you schedule tasks

### ⏱️ Time Tracking

- **Built-in timers** for each task
- **Actual vs. Estimated**: Track how long tasks really take
- **Scheduled vs. Unscheduled**: See which tasks still need time blocks
- **Real-time progress**: Watch your Signal Ratio throughout the day

### 🔄 Smart Task Rollover

- **End-of-day review**: Evaluate incomplete tasks
- **Rollover suggestions**: Automatically suggest carrying over unfinished work
- **Context retention**: Keep your momentum going day-to-day
- **Clean slate option**: Start fresh when needed

### 📊 Analytics & Insights

- **Signal Ratio tracking**: Daily and weekly percentage of focused work time
- **Time breakdown charts**: Visual representation of Signal vs. Noise
- **Tag-based analytics**: See where your time goes by category
- **Weekly reviews**: Reflect on patterns and progress

### 🏷️ Task Organization

- **Tags & categories**: Organize tasks by project, context, or priority
- **Subtasks**: Break down complex work into manageable pieces
- **Custom tags**: Create your own organizational system
- **Filtering**: Find tasks quickly with powerful filters

## 🚀 Getting Started

### Prerequisites

- Flutter 3.10.4 or higher
- Dart 3.0.0 or higher
- iOS 12.0+ / Android 5.0+ (for mobile)
- macOS 10.14+ / Windows 10+ / Linux (for desktop)

### Installation

1. **Clone the repository:**

   ```bash
   git clone https://github.com/YOUR_USERNAME/zen-80.git
   cd zen-80
   ```

2. **Install dependencies:**

   ```bash
   flutter pub get
   ```

3. **Set up Google Calendar API:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select existing one
   - Enable Google Calendar API
   - Create OAuth 2.0 credentials
   - Download `credentials.json` (NOT included in repo for security)
   - Place credentials in appropriate platform directory:
     - **iOS**: Update `ios/Runner/Info.plist` with your OAuth client ID
     - **Android**: Place `google-services.json` in `android/app/`
     - **Web**: Update OAuth config in web configuration

4. **Run the app:**

   ```bash
   # iOS
   flutter run -d ios

   # Android
   flutter run -d android

   # Web
   flutter run -d chrome

   # macOS
   flutter run -d macos
   ```

### iOS Archive (Xcode)

Use the helper script to ensure Flutter configs and Pods are generated before archiving:

```bash
./scripts/xcodebuild_archive.sh
```

To enable code signing, set the signing variables before running the script:

```bash
CODE_SIGNING_ALLOWED=YES \
CODE_SIGNING_REQUIRED=YES \
CODE_SIGN_IDENTITY="Apple Development" \
DEVELOPMENT_TEAM=Q5T8FJNX57 \
./scripts/xcodebuild_archive.sh
```

## 🏗️ Architecture

### Tech Stack

- **Framework**: Flutter 3.10.4
- **State Management**: Provider
- **Local Storage**: Hive (encrypted NoSQL database)
- **Authentication**: Google OAuth 2.0
- **Calendar Sync**: Google Calendar API
- **Secure Storage**: flutter_secure_storage (for OAuth tokens)

### Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/                      # Data models
│   ├── signal_task.dart        # Core task model
│   ├── time_slot.dart          # Scheduled time blocks
│   ├── google_calendar_event.dart
│   └── ...
├── providers/                   # State management
│   ├── signal_task_provider.dart
│   ├── calendar_provider.dart
│   ├── rollover_provider.dart
│   └── ...
├── screens/                     # UI screens
│   ├── home_screen.dart
│   ├── daily_planning_flow.dart
│   ├── scheduling_screen.dart
│   ├── rollover_screen.dart
│   └── ...
├── services/                    # Business logic
│   ├── google_calendar_service.dart
│   ├── sync_service.dart
│   ├── storage_service.dart
│   └── ...
└── widgets/                     # Reusable components
    ├── task_card.dart
    ├── timer/
    ├── analytics/
    └── ...
```

### Key Design Decisions

**1. External Calendar Events as Fulfillment (Not Addition)**

- When you mark an existing calendar event as Signal work, it **fulfills** your task estimate
- Example: Task "Study CS" (180 min) + External event "CS Lecture" (60 min) = 120 min remaining
- This matches the mental model: "This event is WHERE I'll do the work"

**2. Estimate as Goal (Not Running Total)**

- `estimatedMinutes` represents your target outcome
- `scheduledMinutes` represents allocated time (may exceed estimate)
- `actualMinutes` represents time actually worked

**3. Daily Planning Flow**

- Forces intentional morning planning
- Rollover flow ensures incomplete work is reviewed
- Navigation: Rollover → Daily Planning → Scheduling → Home

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/models/signal_task_test.dart

# Run with coverage
flutter test --coverage
```

### Test Coverage

- Model tests: Core business logic
- Provider tests: State management
- Service tests: Calendar sync, rollover logic
- Widget tests: _(Coming soon)_

## 📱 Platform Support

| Platform | Status       | Notes                  |
| -------- | ------------ | ---------------------- |
| iOS      | ✅ Supported | iOS 12.0+              |
| Android  | ✅ Supported | Android 5.0+ (API 21+) |
| Web      | ✅ Supported | Modern browsers        |
| macOS    | ✅ Supported | macOS 10.14+           |
| Windows  | ✅ Supported | Windows 10+            |
| Linux    | ✅ Supported | GTK-based              |

## 🔒 Security & Privacy

- **OAuth tokens** stored in encrypted secure storage (iOS Keychain / Android KeyStore)
- **No plaintext credentials** in codebase
- **Local-first architecture**: Your task data stays on your device (Hive database)
- **Calendar sync**: Only reads/writes events you explicitly create or mark as Signal
- **No analytics tracking**: Your productivity data is yours alone

### Files NOT Included in Git (See `.gitignore`)

- `google-services.json` (Android OAuth)
- `GoogleService-Info.plist` (iOS OAuth)
- `credentials.json` (Desktop OAuth)
- `.env` files
- `secrets.dart`

## 🛠️ Development

### Code Generation

Some models use code generation for JSON serialization:

```bash
# Generate model code
flutter pub run build_runner build

# Watch for changes (development)
flutter pub run build_runner watch
```

### Debugging

- **Debug screen**: Available in settings for troubleshooting
- **Verbose logging**: Check console for sync operations
- **Hive Inspector**: Use Hive boxes viewer for database inspection

## 🗺️ Roadmap

### Current Version (v0.1.0)

- ✅ Core Signal/Noise task tracking
- ✅ Google Calendar two-way sync
- ✅ Daily planning and rollover flows
- ✅ Time tracking with timers
- ✅ Basic analytics (Signal Ratio, weekly stats)

### Upcoming Features

- [ ] Widget support (iOS Live Activities, Android Home Screen)
- [ ] Offline mode improvements
- [ ] Recurring tasks
- [ ] Team/shared Signal tasks
- [ ] Advanced analytics (trends, predictions)
- [ ] AI-powered task estimation
- [ ] Focus mode integrations (Do Not Disturb, app blocking)
- [ ] Export data (CSV, PDF reports)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes
4. Run tests: `flutter test`
5. Commit: `git commit -m "Add amazing feature"`
6. Push: `git push origin feature/amazing-feature`
7. Open a Pull Request

### Coding Standards

- Follow [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Add tests for new features
- Update documentation for API changes
- Keep commits focused and atomic

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by Cal Newport's "Deep Work" and the 80/20 principle
- Built with Flutter and the amazing Flutter community
- Google Calendar API for seamless calendar integration

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/zen-80/issues)
- **Discussions**: [GitHub Discussions](https://github.com/YOUR_USERNAME/zen-80/discussions)
- **Email**: <luke@brevoort.com>

---

**Focus on what matters. Track what you do. Achieve more Signal, less Noise.** 🛰️
