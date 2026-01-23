# Plan: Refactor DiqitLogger

## Problem
`DiqitLogger` in `diqit_logging` package handles too many responsibilities, making it a "God Class". It manages singleton instance, configuration, memory buffer history, file I/O initialization, and the actual logging proxy logic.

## Goal
Refactor `DiqitLogger` into smaller, focused classes to improve maintainability and testability.

## Architecture

### 1. `LogHistoryManager` (Internal)
**Responsibilities:**
- Manage `MemoryOutput`.
- Provide `getLogHistory()`.
- Provide `exportLogs()`.

### 2. `FileLogManager` (Internal)
**Responsibilities:**
- Initialize file logging (check directory, create file).
- Manage `AdvancedFileOutput`.
- Handle I/O errors during setup.

### 3. `DiqitLogger` (Public Facade)
**Responsibilities:**
- Singleton access.
- Configuration management (`LoggerConfig`).
- Facade for `LogHistoryManager` and `FileLogManager`.
- Logging methods (`d`, `debug`, `i`, `info`...) delegating to `Logger` instance.

## Execution Steps

1.  **Create internal helpers** in `lib/src/internal/`.
2.  **Move logic** from `DiqitLogger` to helpers.
3.  **Refactor `DiqitLogger`** to use helpers.
4.  **Verify** with existing tests.

## Verification
- Run `dart test` to ensure no regression.
