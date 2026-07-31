---
name: analyze-log-tag-vs-path
description: Analyze whether a log classification belongs as a LogTag (architectural layer/subsystem) or a Scoped Path (module/component namespace) in diqit-logging. Use when deciding between LogTag or path, or refactoring log categories.
---

# Analyze LogTag vs. Scoped Path (`diqit-logging`)

This skill provides a sharp, deterministic decision matrix for classifying log identifiers into either a **`LogTag`** (Architectural Layer / Subsystem) or a **`path`** (Scoped Module / Component Namespace).

---

## Core Mental Model: 3 Orthogonal Dimensions

In `diqit-logging`, every log line is structured across three non-overlapping dimensions:

1. **WHERE in Architecture? (`LogTag`)** — The technical layer or major domain subsystem.
2. **WHERE in Code Hierarchy? (`path`)** — The specific file, component, or widget module path.
3. **WHICH Business Operation? (`TraceId`)** — The correlation identity of the order/event flow.

```text
[HH:mm:ss.mmm] [LEVEL] [SOURCE / TAG / PATH] [#TRACE_ID] Message
                        └───────┬────────┘
             ┌──────────────────┴──────────────────┐
        source (App)         tag (Layer)       path (Module)
         "OTM"               "KDS"             "kds/order_grid"
```

---

## Decision Matrix: LogTag vs. Scoped Path

Use the following test suite to determine placement:

### 1. Classification Tests

| Question | If YES ➔ **`LogTag`** | If YES ➔ **`path`** |
| :--- | :--- | :--- |
| **Is it a technical layer?** (`UI`, `BLOC`, `REPO`, `NETWORK`, `DB`) | ✅ YES | ❌ NO |
| **Is it a top-level subsystem?** (`KDS`, `ORDER`, `PRINTER`, `SYNC`, `MQTT`) | ✅ YES | ❌ NO |
| **Is it a specific widget/class/file location?** (`order_grid`, `cart_dialog`) | ❌ NO | ✅ YES |
| **Does it form a slash-delimited hierarchy?** (`kds/grid/cell`) | ❌ NO | ✅ YES |
| **Is it used for coarse log suppression/filtering?** (e.g. hide all `UI` logs) | ✅ YES | ❌ NO |

---

## Detailed Rules

### 1. LogTag (Tầng & Subsystem)
- **Type**: Strongly-typed static constant (`LogTag.network`, `LogTag.bloc`, `LogTag.kds`).
- **Scope**: Coarse-grained, finite vocabulary across the entire monorepo.
- **Purpose**: High-level category filtering.
- **Rule**: If removing this identifier would break system-wide filtering or tag toggles, it MUST be a `LogTag`.

### 2. Scoped Path (Module & Component Namespace)
- **Type**: Hierarchical String (`'kds/order_grid'`, `'cart/checkout_button'`).
- **Scope**: Fine-grained, unbounded, created dynamically via `logger.createChild('submodule')`.
- **Purpose**: Code locality and exact component identification.
- **Rule**: If the identifier represents a file, class, widget, or nested component tree, it MUST be a `path`.

---

## Anti-Pattern Refactoring Guide

### ❌ Anti-Pattern 1: Path encoded as Tag
- **Wrong**: `LogTag.custom('kds_order_grid_cell_item')`
- **Right**: Tag = `LogTag.kds`, Path = `'kds/order_grid/cell'`

### ❌ Anti-Pattern 2: Layer encoded as Path
- **Wrong**: `logger.createChild('network_layer')`
- **Right**: Tag = `LogTag.network`, Path = `'http_client'`

---

## Decision Protocol

When analyzing a candidate identifier:

1. **Check if it matches pre-defined `LogTag` constants**:
   `UI`, `BLOC`, `STATE`, `USECASE`, `REPO`, `NETWORK`, `DB`, `MQTT`, `NAV`, `EVENT`, `SYNC`, `ORDER`, `PAYMENT`, `PRINTER`, `KDS`.
2. **If it is a component hierarchy**: Recommend `path` (`parent.createChild('child')`).
3. **If it is a new cross-cutting subsystem**: Propose adding a new static constant to `LogTag`.
