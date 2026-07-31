# 6. Unify Application Identity using `appName`

Date: 2026-07-29

## Status

Accepted

## Context

Previously, `diqit_logging` maintained two separate fields for identifying the originating application:

1. `prefixMessage` (e.g. `"[OTM]"`): A string prefix formatted directly into console log output lines.
2. `appName` (e.g. `"OTM"`): A string identifier stored in `ZoneTrace.sourceAppName` and injected into Socket.IO metadata envelopes (`meta.source`) for cross-app trace attribution.

Having two separate properties led to:
- Redundant and confusing configuration (`prefixMessage: '[OTM]'` vs `appName: 'OTM'`).
- Smashed and duplicated console output lines like `[OTM][OTM] -> message`.
- Lack of a single source of truth for application identity.

## Decision

1. **Deprecate `prefixMessage`**: `prefixMessage` is deprecated in `LoggerConfig` in favor of `appName`.
2. **Single Source of Truth (`appName`)**: `appName` (e.g., `'OTM'`, `'OTC'`, `'KDS'`, `'Dispatch'`) is the single canonical application identifier.
3. **Internal `DLogMessage` Refactoring**: `DLogMessage` eliminates `prefix` internally and relies exclusively on `source` (populated from `ZoneTrace.sourceAppName` / `LoggerConfig.appName`).
4. **Clean Console Formatting**: `DLogMessage.toString()` formats `source` cleanly as `[appName]`, separated by spaces from subsequent tags/paths, without ugly ` -> ` arrows.

## Consequences

- **Backward Compatibility**: Existing code passing `prefixMessage` will automatically map `prefixMessage` to `appName` if `appName` is unspecified.
- **Cross-App Alignment**: Console logs and Socket.IO metadata envelopes (`meta.source`) strictly use the exact same app identity.
- **Cleaner Logs**: Console output is streamlined to `[OTM] message` or `[OTM] [NAV] message`.
