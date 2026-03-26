## Why

Cần tracking source code dễ vị trí gọi log hơn khi sử dụng các logger đầy đủ (`info`, `warning`, `debug`, `trace`, `fatal`). Hiện tại chỉ có hàm `error` cho phép tuỳ chỉnh số lượng method trace qua tham số `countMethod`, việc bổ sung cho các hàm khác sẽ giúp developer debug nhanh hơn.

## What Changes

- Thêm tham số tuỳ chọn `countMethod` (kiểu `int?`) vào các hàm static: `info`, `warning`, `trace`, `debug`, `fatal` trong `DiqitLogger`.
- Tạo một `DPrettyPrinter` mới hoặc chỉnh sửa cách gọi `DPrettyPrinter.trace()` trong nội bộ để nhận tham số `methodCount` động tuỳ theo input của user.

## Capabilities

### New Capabilities
- `method-count-trace`: Tuỳ chỉnh số lượng method trace (stack trace frames) cho tất cả các loggers chi tiết.

### Modified Capabilities

## Impact

- API của `DiqitLogger` (`lib/src/diqit_logging.dart`).
- Không gây breaking change do `countMethod` là tham số optional (mặc định lấy theo cấu hình cũ).
