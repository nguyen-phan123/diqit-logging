import 'package:diqit_logging/src/logger/diqit_pretty_printer.dart';

/// Centralized printer selection logic for DiqitLogger.
///
/// Encapsulates the decision tree: shorthand methods use minimal printer,
/// full methods with countMethod use ephemeral printer, full methods use
/// trace printer. Provides locality and leverage — one implementation serves
/// 12 call sites.
class PrinterSelector {
  final DPrettyPrinter _minimalPrinter;
  final DPrettyPrinter _tracePrinter;

  PrinterSelector({
    required DPrettyPrinter minimalPrinter,
    required DPrettyPrinter tracePrinter,
  })  : _minimalPrinter = minimalPrinter,
        _tracePrinter = tracePrinter;

  /// Selects appropriate printer based on method type and options.
  ///
  /// - [isShorthand]: true for shorthand methods (t, d, i, w, e, ft)
  /// - [countMethod]: if non-null, creates ephemeral printer with custom stack depth
  /// - [customPrinter]: if provided, overrides all selection logic
  ///
  /// Returns:
  /// - customPrinter if provided
  /// - minimal printer if isShorthand=true
  /// - ephemeral printer if countMethod is non-null
  /// - trace printer otherwise
  DPrettyPrinter select({
    required bool isShorthand,
    int? countMethod,
    DPrettyPrinter? customPrinter,
  }) {
    if (customPrinter != null) return customPrinter;
    if (isShorthand) return _minimalPrinter;
    if (countMethod != null) {
      return DPrettyPrinter.trace(
        methodCount: countMethod,
        stackTraceBeginIndex: 0,
      );
    }
    return _tracePrinter;
  }
}
