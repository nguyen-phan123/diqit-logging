## Context

Hiện tại `DiqitLogger` cung cấp các hàm log chi tiết (`info`, `warning`, `trace`, `debug`, `fatal`) sử dụng `_tracePrinter` có số lượng stack trace frame cố định. Hàm `error` đã hỗ trợ `countMethod` để ghi đè số lượng stack trace này. Việc bổ sung `countMethod` cho các hàm chi tiết khác sẽ giúp debug các flow không phải lỗi (non-error flows) dễ dàng hơn.

## Goals / Non-Goals

**Goals:**
- Thêm tham số optional `int? countMethod` cho các hàm log chi tiết (`info`, `warning`, `trace`, `debug`, `fatal`).
- Format output cần chính xác số lượng trace frame truyền vào.

**Non-Goals:**
- Thay đổi chữ ký của các hàm log ngắn (`i`, `w`, `t`, `d`, `ft`, `e`) vì chúng dùng `_minimalPrinter` không in ra stack trace.
- Refactor cấu trúc nội bộ của package `logger`.

## Decisions

- **Modification của Static Methods:** Thêm tham số optional `int? countMethod` vào các hàm `info`, `warning`, `trace`, `debug`, `fatal`. Giữ tương thích ngược do là tham số tuỳ chọn.
- **Dynamic Printer Assignment:** Nếu user truyền `countMethod`, hàm sẽ truyền override một `DPrettyPrinter.trace(methodCount: countMethod)` vào qua tham số `printer` của hàm nội bộ `_instance._log()`. Cách này tương tự như cách hàm `error` đang thực hiện, không gây affect tới các log call khác.

## Risks / Trade-offs

- **Tạo instance printer mới:** Mỗi lần gọi hàm log có truyền `countMethod` khác `null`, một sub-printer mới sẽ được tạo.
  - *Mitigation:* Trong hệ sinh thái Flutter/Dart, cost để khởi tạo short-lived object như printer là cực thấp. Hơn nữa, việc sử dụng `countMethod` thường chỉ dùng khi đang debug sâu, không phải là case gọi liên tục hàng vạn lần mỗi giây.
