## 1. Update Logger Methods

- [x] 1.1 Add optional `int? countMethod` parameter to `DiqitLogger.info` and override printer if provided.
- [x] 1.2 Add optional `int? countMethod` parameter to `DiqitLogger.warning` and override printer if provided.
- [x] 1.3 Add optional `int? countMethod` parameter to `DiqitLogger.trace` and override printer if provided.
- [x] 1.4 Add optional `int? countMethod` parameter to `DiqitLogger.debug` and override printer if provided.
- [x] 1.5 Add optional `int? countMethod` parameter to `DiqitLogger.fatal` and override printer if provided.

## 2. Verification

- [x] 2.1 Add unit tests in `test/src/diqit_logging_test.dart` to verify that providing `countMethod` correctly alters the stack trace output for these methods.
