import 'package:diqit_logging/src/logger/log_tag.dart';

class DLogMessage {
  final String message;
  final LogTag tag;
  final dynamic data;

  const DLogMessage(this.message, [this.tag = LogTag.none, this.data]);

  @override
  String toString() {
    if (data != null) {
      return '$message\nData: $data';
    }
    return message;
  }
}
