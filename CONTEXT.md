# Diqit Logging Context

Provides structured, zone-based diagnostic logging and distributed correlation across mobile POS applications.

## Language

**DiqitLogger**:
The central logging entrypoint that unifies console printing, file logging, and trace correlation across the application lifecycle.
_Avoid_: Logger instance, Log manager, Print service

**LoggerConfig**:
The configuration blueprint governing log levels, tag filters, file output paths, and visual formatting rules for the logger.
_Avoid_: Log options, Printer settings, Logger params

**TraceZone**:
An execution context powered by Dart `Zone` that carries and propagates asynchronous diagnostic correlation metadata across futures, streams, and event boundaries.
_Avoid_: Logger scope, Request context, Thread local

**Trace Envelope**:
The standardized Socket.IO event transport wrapper carrying metadata (including `traceId` and source application) alongside the event payload across mobile POS apps.
_Avoid_: Custom payload header, Trace DTO

**LogTag**:
A categorization label assigned to log statements to identify the subsystem or feature module producing the event.
_Avoid_: Log category, Event module, Channel

**Log History**:
An in-memory rolling buffer of formatted log events maintained for real-time inspection and on-device debugging.
_Avoid_: Log cache, Memory store, Event queue
