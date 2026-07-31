import 'package:logger/logger.dart';

/// Console output that splits long log lines into chunks to avoid
/// platform log buffer truncation.
///
/// On Flutter, [print] routes through [dart:developer]'s [log] which
/// has a per-message size limit (~1024 chars on most platforms).
/// Single long log lines (e.g. verbose JSON data) get silently
/// truncated. This output splits lines exceeding [chunkSize] into
/// multiple [print] calls so the full log reaches the console.
class SafeConsoleOutput extends LogOutput {
  /// Maximum characters per [print] call before splitting.
  ///
  /// Default 800 conservatively stays under the ~1024 char limit
  /// on Android/iOS [dart:developer] [log] while accounting for
  /// ANSI escape sequences in the output.
  final int chunkSize;

  SafeConsoleOutput({this.chunkSize = 800});

  @override
  void output(OutputEvent event) {
    for (final line in event.lines) {
      _writeLine(line);
    }
  }

  void _writeLine(String line) {
    if (line.length <= chunkSize) {
      print(line);
      return;
    }

    // Split at chunk boundaries, preferring natural break points
    var start = 0;
    while (start < line.length) {
      var end = (start + chunkSize).clamp(0, line.length);

      // Try to break at a natural point if not at the end
      if (end < line.length) {
        final slice = line.substring(start, end);
        final lastSpace = slice.lastIndexOf(' ');
        if (lastSpace > chunkSize ~/ 2) {
          end = start + lastSpace;
        }
      }

      print(line.substring(start, end));
      start = end;
    }
  }
}
