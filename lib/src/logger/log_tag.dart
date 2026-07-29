class LogTag {
  final String label;

  const LogTag(this.label);

  // * --- Special ---

  /// Empty tag for untagged logs.
  static const LogTag none = LogTag('');

  // * --- Architectural Layers ---
  // Where the log originates in the app architecture.

  /// UI layer (widgets, screens).
  static const LogTag ui = LogTag('UI');

  /// BLoC/Cubit state management.
  static const LogTag bloc = LogTag('BLOC');

  /// State management (other patterns).
  static const LogTag state = LogTag('STATE');

  /// Use case / business logic.
  static const LogTag usecase = LogTag('USECASE');

  /// Data repository layer.
  static const LogTag repository = LogTag('REPO');

  /// HTTP/API network calls.
  static const LogTag network = LogTag('NETWORK');

  /// Local database operations.
  static const LogTag database = LogTag('DB');

  /// MQTT protocol operations.
  static const LogTag mqtt = LogTag('MQTT');

  // * --- Domain Features ---
  // What business domain the log relates to.

  /// Route/screen navigation.
  static const LogTag navigation = LogTag('NAV');

  /// App events (lifecycle, user actions).
  static const LogTag event = LogTag('EVENT');

  /// Data synchronization.
  static const LogTag sync = LogTag('SYNC');

  /// Order management.
  static const LogTag order = LogTag('ORDER');

  /// Payment processing.
  static const LogTag payment = LogTag('PAYMENT');

  /// Receipt printing.
  static const LogTag printer = LogTag('PRINTER');

  @Deprecated(
    "Use LogTag.custom('KDS') instead. Will be removed in v2.0.0",
  )
  static const LogTag kds = LogTag('KDS');

  factory LogTag.custom(String label) => LogTag(label);

  /// All predefined tags used as default enabled tags in LoggerConfig.
  static const List<LogTag> values = [
    none,
    ui,
    bloc,
    state,
    usecase,
    repository,
    network,
    database,
    mqtt,
    navigation,
    event,
    sync,
    order,
    payment,
    printer,
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
