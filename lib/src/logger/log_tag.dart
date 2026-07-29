/// Represents high-level architectural layers or major domain subsystems.
///
/// LogTag is used for coarse-grained log filtering across the system.
/// For fine-grained component, widget, or file locality, use scoped child
/// loggers via `logger.createChild('module/submodule')` instead of creating
/// new LogTags.
class LogTag {
  final String label;

  const LogTag(this.label);

  static const LogTag none = LogTag('');

  // Layers
  static const LogTag ui = LogTag('ui');
  static const LogTag bloc = LogTag('BLOC');
  static const LogTag state = LogTag('STATE');
  static const LogTag usecase = LogTag('USECASE');
  static const LogTag repository = LogTag('REPO');
  static const LogTag network = LogTag('NETWORK');
  static const LogTag database = LogTag('DB');
  static const LogTag mqtt = LogTag('MQTT');

  // Features / Domain Subsystems (Deprecated: use logger.createChild)
  @Deprecated(
    'Use logger.createChild("navigation") for scoped module path instead. '
    'Will be removed in v2.0.0.',
  )
  static const LogTag navigation = LogTag('NAV');

  @Deprecated(
    'Use logger.createChild("event") for scoped module path instead. '
    'Will be removed in v2.0.0.',
  )
  static const LogTag event = LogTag('EVENT');

  static const LogTag sync = LogTag('SYNC');

  @Deprecated(
    'Use logger.createChild("order") for scoped module path instead. '
    'Will be removed in v2.0.0.',
  )
  static const LogTag order = LogTag('ORDER');

  @Deprecated(
    'Use logger.createChild("payment") for scoped module path instead. '
    'Will be removed in v2.0.0.',
  )
  static const LogTag payment = LogTag('PAYMENT');

  @Deprecated(
    'Use logger.createChild("printer") for scoped module path instead. '
    'Will be removed in v2.0.0.',
  )
  static const LogTag printer = LogTag('PRINTER');

  @Deprecated(
    'Use logger.createChild("kds") for scoped module path instead. '
    'Will be removed in v2.0.0.',
  )
  static const LogTag kds = LogTag('KDS');

  factory LogTag.custom(String label) => LogTag(label);

  static const List<LogTag> values = [
    none,
    ui,
    bloc,
    state,
    usecase,
    repository,
    network,
    database,
    // ignore: deprecated_member_use_from_same_package
    navigation,
    // ignore: deprecated_member_use_from_same_package
    event,
    sync,
    // ignore: deprecated_member_use_from_same_package
    order,
    // ignore: deprecated_member_use_from_same_package
    payment,
    // ignore: deprecated_member_use_from_same_package
    printer,
    mqtt,
    // ignore: deprecated_member_use_from_same_package
    kds,
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogTag &&
          runtimeType == other.runtimeType &&
          label == other.label;

  @override
  int get hashCode => label.hashCode;

  @override
  String toString() => label;
}
