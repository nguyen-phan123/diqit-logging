import 'package:logger/logger.dart';

/// {@template aligned_pretty_printer}
/// Wrapper around [LogPrinter] that adds padding for alignment.
///
/// Use this to align logs when mixing printers with and without emojis.
/// For example, when combining compact (with emoji) and minimal (without emoji)
/// outputs, this ensures messages line up vertically.
///
/// Usage:
/// ```dart
/// final minimalPrinter = DPrettyPrinter.minimal();
/// final alignedPrinter = AlignedPrettyPrinter(
///   minimalPrinter,
///   paddingSize: 3, // Matches emoji width
/// );
/// ```
/// {@endtemplate}
class AlignedPrettyPrinter extends LogPrinter {
  /// The underlying printer to wrap.
  final LogPrinter printer;

  /// Number of spaces to add before each line.
  /// Default is 3 to match typical emoji width (emoji + space).
  final int paddingSize;

  /// {@macro aligned_pretty_printer}
  AlignedPrettyPrinter(
    this.printer, {
    this.paddingSize = 3,
  });

  @override
  List<String> log(LogEvent event) {
    final lines = printer.log(event);
    if (paddingSize <= 0) return lines;

    final padding = ' ' * paddingSize;
    return lines.map((line) => '$padding$line').toList();
  }
}
