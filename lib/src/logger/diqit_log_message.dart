import 'log_tag.dart';

class DLogMessage {
  final String message;
  final DLogTag tag;

  const DLogMessage(this.message, [this.tag = DLogTag.none]);

  @override
  String toString() => message;
}
