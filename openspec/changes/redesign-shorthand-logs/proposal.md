## Why

Hiện tại, `diqit-logging` phân tách rạch ròi 2 loại public API:
1. Súp-pe ngắn gọn (`d()`, `i()`, `e()`): Dùng `DPrettyPrinter.minimal()` - không có box, không có emoji, dạng plain text khô khan.
2. Full stack (`debug()`, `info()`, `error()`): Dùng `DPrettyPrinter.trace()` - có box viền nặng nề, kèm stack trace.

Vấn đề: Log dạng tắt (`d()`) hiện tại quá đơn điệu, khó phân biệt bằng mắt thường (không màu sắc rõ rệt, không phân cách Level/Tag tốt). Nhưng nếu gọi sang `debug()` thì lại bị "đóng box" chiếm dòng console.
Yêu cầu: Nâng cấp visual cho nhóm log tắt lột xác, **dễ nhìn, nổi bật, có formatting (màu sắc, spacing, tag rõ ràng)** nhưng **MỘT MỰC KHÔNG DÙNG BOX**.

## What Changes

Thay đổi `DPrettyPrinter.minimal()` (hoặc viết hẳn một `ShorthandPrinter`) để cấu trúc lại inline text cho log tắt. Trộn thêm ANSI color, các ký hiệu nhận diện (hoặc emoji compact) theo từng Level/Tag, đảm bảo 1 dòng log trên console có visual hierarchy (Thứ bậc thị giác): `[Thời gian] [Level/Emoji] [Tag] Nội dung`. Cấm tuyệt đối vẽ box đa dòng.

## Capabilities

### New Capabilities
- `shorthand-log-visual`: Nâng cấp giao diện inline cho các hàm log rút gọn.

### Modified Capabilities

## Impact

Ảnh hưởng đến format console của các hàm rút gọn (`d()`, `i()`, `w()`, v.v.). API usage giữ nguyên, chỉ update core `LogPrinter`.
