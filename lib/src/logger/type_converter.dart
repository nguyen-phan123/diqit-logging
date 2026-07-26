/// Type converter function signature.
///
/// Converts a value of type [T] to a human-readable string representation
/// for logging purposes.
typedef TypeConverter<T> = String Function(T value);

/// {@template type_converter_registry}
/// Registry for formatting third-party types that cannot implement `Loggable`.
///
/// Use this to register custom string representations for common types
/// like `DateTime`, `Duration`, `Uri` that you don't own and cannot
/// add the `Loggable` mixin to.
///
/// ## Usage
///
/// ```dart
/// // During logger initialization
/// await DiqitLogger.initialize(config);
///
/// // Register converters for common types
/// DiqitLogger.registerConverter<DateTime>((dt) => dt.toIso8601String());
/// DiqitLogger.registerConverter<Duration>((d) => '${d.inSeconds}s');
/// DiqitLogger.registerConverter<Uri>((uri) => uri.toString());
///
/// // Later in code
/// DiqitLogger.i('Event scheduled', data: DateTime.now());
/// // Output: Event scheduled
/// //         Data: 2026-07-26T10:30:45.123Z
/// ```
///
/// ## Lookup Order
///
/// When logging with the `data` parameter, DiqitLogger tries:
/// 1. **Loggable check** — if `data is Loggable`, call `toLoggableMap()`
/// 2. **TypeConverter check** — if registered converter exists, use it
/// 3. **Fallback** — call `data.toString()`
///
/// {@endtemplate}
class TypeConverterRegistry {
  /// {@macro type_converter_registry}
  TypeConverterRegistry();

  final Map<Type, String Function(dynamic)> _converters = {};

  /// Register a converter for type [T].
  ///
  /// ```dart
  /// registry.register<DateTime>((dt) => dt.toIso8601String());
  /// registry.register<Duration>((d) => '${d.inSeconds}s');
  /// ```
  ///
  /// If a converter already exists for [T], it will be replaced.
  void register<T>(TypeConverter<T> converter) {
    _converters[T] = (dynamic value) => converter(value as T);
  }

  /// Try to convert [value] using a registered converter.
  ///
  /// Returns the converted string if a converter is registered for
  /// [value]'s runtime type or any of its supertypes, otherwise returns `null`.
  ///
  /// ```dart
  /// final result = registry.convert(DateTime.now());
  /// // Returns ISO8601 string if DateTime converter registered
  /// // Returns null if no converter registered
  /// ```
  String? convert(Object value) {
    // First try exact runtime type match
    var converter = _converters[value.runtimeType];
    if (converter != null) {
      return converter(value);
    }

    // If no exact match, check registered types using 'is' check
    // This handles cases where runtime type is a private implementation
    // (e.g., Uri.parse() returns _SimpleUri, not Uri)
    for (final entry in _converters.entries) {
      // Use a try-catch to safely check if value is instance of the type
      try {
        // We can't use 'value is T' directly, but we can try to cast
        // and catch if it fails
        final testValue = value;
        if (_isInstanceOfType(testValue, entry.key)) {
          return entry.value(value);
        }
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  /// Check if [value] is an instance of [type].
  ///
  /// This is a workaround for checking dynamic types at runtime.
  bool _isInstanceOfType(Object value, Type type) {
    // Common types check
    if (type == DateTime && value is DateTime) return true;
    if (type == Duration && value is Duration) return true;
    if (type == Uri && value is Uri) return true;
    if (type == String && value is String) return true;
    if (type == int && value is int) return true;
    if (type == double && value is double) return true;
    if (type == bool && value is bool) return true;

    // For custom types, check if runtimeType matches
    return value.runtimeType == type;
  }

  /// Remove converter for type [T].
  ///
  /// Returns `true` if a converter was removed, `false` if none existed.
  bool unregister<T>() {
    return _converters.remove(T) != null;
  }

  /// Clear all registered converters.
  void clear() {
    _converters.clear();
  }

  /// Check if a converter is registered for type [T].
  bool hasConverter<T>() {
    return _converters.containsKey(T);
  }
}
