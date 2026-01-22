# Diqit Logging

A powerful, singleton-based logging wrapper for Dart/Flutter applications, designed to provide unified logging with support for multiple outputs, smart tagging, and flexible printing modes.

## ✨ Features

- **Singleton Architecture**: Global access via static methods—no need to pass logger instances around.
- **Dual Printer Modes**:
  - **Short/Clean**: For everyday development (less noise).
  - **Full/Trace**: For deep debugging (includes stack trace and method info).
- **Smart Tagging**: Categorize logs using `LogTag` (e.g., `LogTag.network`, `LogTag.database`).
- **File Logging**: Automatically writes logs to the file system (configurable).
- **Memory History**: Keeps a buffer of recent logs for in-app viewing or export.
- **Unified Interface**: Simple static methods like `DiqitLogger.i()`, `DiqitLogger.error()`.

---

## 💻 Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  diqit_logging:
    git:
      url: https://github.com/nguyen-phan123/diqit-logging.git
      path: packages/diqit_logging
```

---

## 🚀 Usage

### 1. Initialization

Initialize the logger once at the start of your app (e.g., in `main.dart`).

```dart
import 'package:diqit_logging/diqit_logging.dart';

void main() async {
  // Create configuration
  final config = LoggerConfig(
    enableConsoleLogging: true,
    enableFileLogging: true,
    logDirectory: 'path/to/app/documents/logs', // Optional
  );
  
  // Initialize
  await DiqitLogger.initialize(config);

  runApp(MyApp());
}
```

### 2. Basic Logging

Use the **short commands** (`t`, `d`, `i`, `w`, `e`, `ft`) for clean, concise logs.

```dart
DiqitLogger.i('Application started'); // Info
DiqitLogger.d('User 123 logged in', tag: LogTag.auth); // Debug with Tag
DiqitLogger.w('Connection slow', tag: LogTag.network); // Warning
```

### 3. Deep Debugging

Use the **full words** (`trace`, `debug`, `info`, `warning`, `error`, `fatal`) when you need stack traces and caller info.

```dart
try {
  fetchData();
} catch (e, stack) {
  // Logs error with full stack trace and method count
  DiqitLogger.error('API call failed', error: e, stackTrace: stack, tag: LogTag.network);
}
```

### 4. Advanced Features

#### Export Logs
You can export the in-memory log history to a string (useful for "Report a Bug" features).

```dart
String report = DiqitLogger.exportLogs(lastN: 100);
// Send report to server...
```

#### Runtime Control
Toggle console logging on/off dynamically:

```dart
DiqitLogger.setConsoleLogging(false); // Silence console logs
```

---

## 🏷️ Log Tags

Use `LogTag` to categorize your logs. Available tags:

- `LogTag.none` (default)
- `LogTag.ui`
- `LogTag.bloc`
- `LogTag.repo`
- `LogTag.network`
- `LogTag.database`
- `LogTag.mqtt`
- `LogTag.auth`
- ... and more.

---

## 🛠️ Comparison: Short vs Full API

| Level | Short API (Clean) | Full API (Trace Info) |
|-------|-------------------|-----------------------|
| Trace | `t()` | `trace()` |
| Debug | `d()` | `debug()` |
| Info | `i()` | `info()` |
| Warning | `w()` | `warning()` |
| Error | `e()` | `error()` |
| Fatal | `ft()` | `fatal()` |

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
