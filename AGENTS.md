# Agent Guide: diqit_logging

This guide provides coding agents with essential information for working in this Dart package.

---

## 🛠️ Build, Lint, and Test Commands

### Setup
```bash
# Install dependencies
dart pub get
```

### Format
```bash
# Check formatting (CI-safe)
dart format --set-exit-if-changed .

# Auto-format all files
dart format .

# Format specific file
dart format lib/src/diqit_logging.dart
```

### Analyze
```bash
# Run analyzer (strict mode used in CI)
dart analyze --fatal-infos --fatal-warnings lib test

# Run analyzer (standard)
dart analyze
```

### Test
```bash
# Run all tests
dart test

# Run a single test file
dart test test/src/diqit_logging_test.dart

# Run with coverage
dart test --coverage=coverage

# Run specific test by name
dart test --name "can be instantiated"
```

### Pre-commit Hooks
Managed via `lefthook.yml` (run automatically on commit):
- **Format**: Auto-formats staged Dart files
- **Analyze**: Runs strict analysis on `lib` and `test`

---

## 📝 Code Style Guidelines

### Linting
- Uses **very_good_analysis 5.1.0** (strict Dart linting)
- Analysis options in `analysis_options.yaml`
- Disabled rules:
  - `public_member_api_docs: false` (private package)
  - `require_trailing_commas: false`
  - `prefer_const_constructors: false`
  - `avoid_print: false` (logging package)
  - `cascade_invocations: false`

### Import Order
Follow Dart conventions (dart format enforces this):
```dart
// 1. Dart/Flutter SDK imports
import 'dart:async';

// 2. Package imports
import 'package:logger/logger.dart';

// 3. Relative imports (internal package files)
import 'package:diqit_logging/src/logger/logger.dart';
```

### Naming Conventions
- **Classes**: `PascalCase` (e.g., `DiqitLogger`, `LoggerConfig`)
- **Files**: `snake_case.dart` (e.g., `diqit_logging.dart`, `log_tag.dart`)
- **Functions/Variables**: `camelCase` (e.g., `exportLogs`, `minLogLevel`)
- **Constants**: `camelCase` for static const (e.g., `LogTag.network`)
- **Private members**: Prefix with `_` (e.g., `_instance`, `_initialized`)

### Documentation
```dart
/// {@template class_name}
/// Brief description of the class.
///
/// Features:
/// - Feature 1
/// - Feature 2
///
/// Usage:
/// ```dart
/// final example = Example();
/// ```
/// {@endtemplate}
class Example {
  /// {@macro class_name}
  Example();
}
```

### Types
- **Always** specify return types for public methods
- **Always** specify types for public fields
- Use `late` for non-nullable fields initialized after construction
- Use type aliases for clarity: `typedef LogLevel = Level;`

### Class Structure (Standard Order)
1. Static constants
2. Static fields
3. Instance fields (public, then private)
4. Constructors (public, then private/named)
5. Static methods (public API first)
6. Public instance methods
7. Private instance methods (prefixed with `_`)

Example from `DiqitLogger`:
```dart
class DiqitLogger {
  static final DiqitLogger _instance = DiqitLogger._();
  
  late LoggerConfig _config;
  bool _initialized = false;
  Logger? _activeLogger;
  
  DiqitLogger._();
  
  static Future<void> initialize(LoggerConfig config) async { }
  static void setConsoleLogging(bool enabled) { }
  
  Future<void> _initializeInternal(LoggerConfig config) async { }
}
```

### Error Handling
- Use `try-catch` for async operations
- Pass `error` and `stackTrace` to logger methods
- Validate inputs in public API methods
- Use assertions for internal invariants: `assert(condition, 'message');`

### Comments
- Use `//` for implementation comments
- Use `///` for public API documentation
- Use `// *` for section headers (existing convention):
  ```dart
  // * --- Configuration State ---
  ```
- Use `TODO:` for future improvements
- Avoid obvious comments; code should be self-documenting

### Formatting
- **Line length**: 80 characters (dart format default)
- **Indentation**: 2 spaces (enforced by dart format)
- **No trailing commas required** (disabled in linting)
- Let `dart format` handle all spacing and alignment

### Testing
- Test files mirror source structure: `test/src/diqit_logging_test.dart`
- Use `group()` for test suites
- Use `test()` for individual tests
- Can ignore lints in tests: `// ignore_for_file: prefer_const_constructors`
- Use `mocktail` for mocking

---

## 🏗️ Architecture Notes

### Singleton Pattern
- `DiqitLogger` uses singleton: `DiqitLogger._instance`
- Public API is all static methods
- Internal state via private instance fields

### Initialization
- Must call `DiqitLogger.initialize(config)` before logging
- Lazy initialization with fallback to development config
- Async initialization for file logging setup

### Key Files
- `lib/diqit_logging.dart` - Main export file
- `lib/src/diqit_logging.dart` - Singleton logger implementation
- `lib/src/logger/logger_config.dart` - Configuration with presets
- `lib/src/logger/log_tag.dart` - Tag system for categorization

### Dependencies
- **logger**: ^2.6.2 (base logging library)
- **mocktail**: ^1.0.4 (testing mocks)
- **test**: ^1.25.7 (testing framework)

---

## ⚠️ Important Constraints

1. **Package is private**: `publish_to: none` in pubspec.yaml
2. **SDK constraint**: Dart >=3.0.0 <4.0.0
3. **No Flutter dependency**: Pure Dart package (though Flutter-compatible)
4. **Git hooks enabled**: Code must pass format + analyze on commit

---

## 🎯 When Making Changes

- Run `dart format .` before committing
- Ensure `dart analyze` passes with no warnings
- Add tests for new functionality
- Update README.md if public API changes
- Follow existing naming patterns (especially for LogTag constants)
- Maintain backward compatibility (this is used in production apps)

---

## Agent skills

### Issue tracker

Issues are tracked in GitHub (`nguyen-phan123/diqit-logging`). See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout: `CONTEXT.md` at repo root, ADRs in `docs/adr/`. See `docs/agents/domain.md`.
