import 'dart:io';
import 'package:logger/logger.dart';

class DPrettyPrinter extends PrettyPrinter {
  static final bool _isColorSupported = !Platform.isIOS &&
      (Platform.isAndroid ||
          Platform.isWindows ||
          Platform.isLinux ||
          Platform.isMacOS);

  DPrettyPrinter({
    super.methodCount = 8,
    super.errorMethodCount = 8,
    super.lineLength = 120,
    super.colors = true,
    super.printEmojis = true,
    super.printTime = false,
    super.noBoxingByDefault = false,
    super.stackTraceBeginIndex = 2,
  });

  factory DPrettyPrinter.trace({
    int methodCount = 5,
    int stackTraceBeginIndex = 2,
  }) {
    return DPrettyPrinter(
      methodCount: methodCount,
      stackTraceBeginIndex: stackTraceBeginIndex,
      lineLength: 100,
      colors: _isColorSupported,
    );
  }

  factory DPrettyPrinter.cleanNoise() {
    return DPrettyPrinter(
      methodCount: 0,
      errorMethodCount: 0,
      lineLength: 100,
      colors: _isColorSupported,
      noBoxingByDefault: true,
      printEmojis: false,
    );
  }
}
