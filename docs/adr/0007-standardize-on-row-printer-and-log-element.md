# 7. Standardize Console Rendering on `RowPrinter` and `LogElement` Architecture

Date: 2026-07-30

## Status

Accepted

## Context

Previously, `diqit_logging` contained two competing console log printers:
1. `DShorthandPrinter`: A hardcoded inline printer that formatted time, emojis, and ANSI colors directly in `log()`. It ignored `LogTag`, `TraceId`, `path`, and structured context metadata in `DLogMessage`.
2. `RowPrinter` + `LogElement`: A modular, component-based rendering pipeline where `RowPrinter` executes an ordered list of `LogElement` building blocks (`LogNumElement`, `LogLevelElement`, `LogTimeElement`, `LogPathElement`, `LogTraceIdElement`, `LogMessageElement`).

Furthermore, `DiqitLogger.log()` forcibly defaulted all shorthand calls to `DShorthandPrinter`, overriding `LoggerConfig.printer` even when developers explicitly passed `printer: RowPrinter(...)`.

## Decision

1. **Standardize on `RowPrinter`**: `RowPrinter` powered by `LogElement` components is the sole canonical console printer in `diqit_logging`.
2. **Deprecate `DShorthandPrinter`**: `DShorthandPrinter` is marked `@Deprecated` in favor of `RowPrinter`. All factory methods in `DPrettyPrinter` (`trace()`, `minimal()`, `compact()`, etc.) return `RowPrinter`.
3. **Respect `LoggerConfig.printer`**: `DiqitLogger.log()` and static shortcuts (`DiqitLogger.i()`, `d()`, `e()`, etc.) no longer force `DShorthandPrinter`. If no per-call `printer` is passed, logging delegates directly to `_config.printer` (`RowPrinter`).
4. **Structured Metadata Support**: All console logs consistently include sequence numbers, level characters (`T`, `D`, `I`, `W`, `E`, `F`), timestamps, tags, namespace paths, and trace IDs (`{#traceId}`).

## Consequences

- **Single Rendering Engine**: Eliminates code duplication across ANSI color maps, timestamp formatting, and level badges.
- **Full Traceability**: All log methods (`i()`, `d()`, `e()`, `w()`, `t()`, `ft()`) automatically reflect active `LogTag`s, `TraceId`s, and namespace `path`s.
- **Customizability**: Developers can fully customize console layout by configuring `RowPrinter(children: [...])` in `LoggerConfig`.
