# Plan: Rewrite README.md for Diqit Logging

## 1. Context & Analysis
- **Current State**: Generic "Very Good Analysis" boilerplate. Lacks specific details about `DiqitLogger`.
- **Goal**: Create a comprehensive, developer-friendly README that accurately reflects the package's capabilities.
- **Source of Truth**: `lib/src/diqit_logging.dart` and `lib/src/logger/`.

## 2. Proposed Structure

### A. Header & Badges
- Package Name: `diqit_logging`
- Description: "A powerful, singleton-based logging wrapper for Dart/Flutter with dual-printer support and file logging."
- Badges: CI Status, Dart Version, License.

### B. Key Features
- **Singleton Architecture**: Easy global access.
- **Smart Tagging**: Usage of `LogTag` (Network, DB, UI, etc.).
- **Dual Mode Printers**:
  - Short/Clean (`t`, `d`, `i`) for daily dev.
  - Full/Trace (`trace`, `debug`, `info`) for deep debugging.
- **File Logging**: Automatic file rotation and storage.
- **Memory Buffer**: In-app log history and export capabilities.

### C. Installation
- Standard `dart pub add`
- Or Git dependency (since `publish_to: none`).

### D. Usage Guide (Code Snippets)
1. **Initialization**:
   ```dart
   final config = LoggerConfig(
     enableConsoleLogging: true,
     enableFileLogging: true,
     logDirectory: 'path/to/logs',
   );
   await DiqitLogger.initialize(config);
   ```

2. **Basic Logging**:
   ```dart
   DiqitLogger.i('App initialized');
   DiqitLogger.d('User data loaded', tag: LogTag.auth);
   ```

3. **Advanced Logging (With Trace)**:
   ```dart
   DiqitLogger.error('API Failed', error: e, stackTrace: s);
   ```

### E. Configuration
- Detailed table of `LoggerConfig` parameters.

## 3. Execution Steps
1. [ ] Backup existing README (optional, git has history).
2. [ ] Draft new content based on current code.
3. [ ] Update `Installation` section to reflect internal package status.
4. [ ] Verify links and badges.

## 4. Open Questions (Socratic Gate)
- **Language**: Should the README be in English (Standard) or Vietnamese (Team preference)? -> *Assumption: English.*
- **Installation Source**: Is this package hosted on a private pub server or just Git? -> *Assumption: Git/Local.*
