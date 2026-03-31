## ADDED Requirements

### Requirement: Nâng cấp Visual nhưng KHÔNG dùng box (Shorthand logs)
- Các hàm sinh log nhanh `d()`, `i()`, `e()`, v.v. vốn đã không có box nhưng lại quá đơn điệu. Cần phải được nâng cấp style để có thứ bậc thị giác rõ ràng bằng việc phối màu (Colors), icon/emoji siêu nhỏ, tags phân biệt.

#### Scenario: Developer gọi hàm debug nhanh
- **WHEN** DiqitLogger.d('message', tag: LogTag.network)
- **THEN** Format in ra một dòng DUY NHẤT cực nét:
  `[14:22:01] • [NETWORK] message (Màu Cyan/Xanh mượt)`
- **THEN** Không vẽ bất kỳ nét đứt kẽ hộp (box viền ├─ └─) nào lên console.
- **THEN** Fallback về plain string cơ bản nếu OS (iOS) không hỗ trợ màu ANSI.
