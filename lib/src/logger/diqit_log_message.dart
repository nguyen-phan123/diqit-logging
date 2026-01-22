import 'package:diqit_logging/src/logger/log_tag.dart';

class DLogMessage {
  final String message;
  final LogTag tag;

  const DLogMessage(this.message, [this.tag = LogTag.none]);

  @override
  String toString() => message;
}
