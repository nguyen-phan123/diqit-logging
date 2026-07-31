/// {@template loggable}
/// Protocol for objects that can format themselves for logging.
///
/// Implement this mixin on domain entities to provide structured
/// key-value representation instead of opaque toString() output.
///
/// ## Usage
///
/// ```dart
/// class OrderEntity with Loggable {
///   final String uuid;
///   final double total;
///   final List<OrderDetailEntity> orderDetails;
///
///   @override
///   Map<String, dynamic> toLoggableMap() => {
///     'uuid': uuid,
///     'total': '\$${total.toStringAsFixed(2)}',
///     'items_count': orderDetails.length,
///   };
/// }
///
/// // Log with data parameter
/// DiqitLogger.i('Order created', data: orderEntity);
/// // Output: [10:30:45] ℹ [ORDER] Order created
/// //         Data: {uuid: abc-123, total: $45.50, items_count: 3}
/// ```
///
/// ## Nested Loggable Objects
///
/// Values in the map can be primitives, strings, or nested Loggable objects:
///
/// ```dart
/// class PaymentEntity with Loggable {
///   @override
///   Map<String, dynamic> toLoggableMap() => {
///     'amount': '\$${amount.toStringAsFixed(2)}',
///     'method': method.name,
///   };
/// }
///
/// class OrderEntity with Loggable {
///   final PaymentEntity payment;
///
///   @override
///   Map<String, dynamic> toLoggableMap() => {
///     'uuid': uuid,
///     'payment': payment, // Nested Loggable - automatically formatted
///   };
/// }
/// ```
///
/// ## Best Practices
///
/// - Keep maps small (5-10 keys) for readability
/// - Format numbers/dates as human-readable strings
/// - Use `_count` suffix for list lengths instead of logging full lists
/// - For enums, use `.name` property
/// - Avoid sensitive data (passwords, tokens, PII)
///
/// {@endtemplate}
mixin Loggable {
  /// Returns a map of loggable key-value pairs.
  ///
  /// Keys should be human-readable field names (e.g., 'uuid', 'total').
  /// Values can be:
  /// - Primitives (int, double, bool)
  /// - Strings (already formatted)
  /// - Nested Loggable objects (recursively formatted)
  /// - Lists/Maps (will be formatted by printer)
  ///
  /// Called automatically by DiqitLogger when logging with `data` parameter.
  Map<String, dynamic> toLoggableMap();
}
