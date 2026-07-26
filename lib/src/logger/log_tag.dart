class LogTag {
  final String label;

  const LogTag(this.label);

  static const LogTag none = LogTag('');

  // Layers
  static const LogTag ui = LogTag('UI');
  static const LogTag bloc = LogTag('BLOC');
  static const LogTag state = LogTag('STATE');
  static const LogTag usecase = LogTag('USECASE');
  static const LogTag repository = LogTag('REPO');
  static const LogTag network = LogTag('NETWORK');
  static const LogTag database = LogTag('DB');
  static const LogTag mqtt = LogTag('MQTT');

  // Features
  static const LogTag navigation = LogTag('NAV');
  static const LogTag event = LogTag('EVENT');
  static const LogTag sync = LogTag('SYNC');
  static const LogTag order = LogTag('ORDER');
  static const LogTag payment = LogTag('PAYMENT');
  static const LogTag printer = LogTag('PRINTER');
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
    navigation,
    event,
    sync,
    order,
    payment,
    printer,
    mqtt,
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
