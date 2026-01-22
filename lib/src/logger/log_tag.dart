class DLogTag {
  final String label;

  const DLogTag(this.label);

  static const DLogTag none = DLogTag('');
	@deprecated
  static const DLogTag general = DLogTag('GENERAL');

  // Layers
  static const DLogTag ui = DLogTag('UI');
  static const DLogTag bloc = DLogTag('BLOC');
  static const DLogTag state = DLogTag('STATE');
  static const DLogTag usecase = DLogTag('USECASE');
  static const DLogTag repository = DLogTag('REPO');
  static const DLogTag network = DLogTag('NETWORK');
  static const DLogTag database = DLogTag('DB');
	static const DLogTag mqtt = DLogTag('MQTT');

  // Features
  static const DLogTag navigation = DLogTag('NAV');
  static const DLogTag event = DLogTag('EVENT');
  static const DLogTag sync = DLogTag('SYNC');
  static const DLogTag order = DLogTag('ORDER');
  static const DLogTag payment = DLogTag('PAYMENT');
  static const DLogTag printer = DLogTag('PRINTER');

  factory DLogTag.custom(String label) => DLogTag(label);

  static const List<DLogTag> values = [
    none,
    general,
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
      other is DLogTag &&
          runtimeType == other.runtimeType &&
          label == other.label;

  @override
  int get hashCode => label.hashCode;

  @override
  String toString() => label;
}
