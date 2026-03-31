## Context

Trong code base, `DiqitLogger` định nghĩa:
- Hàm log ngắn (vd `t`, `d`, `i`): Xài `_minimalPrinter` (`noBoxingByDefault: true`, `printEmojis: false`, `methodCount: 0`). 
- Hàm log chi tiết (vd `trace`, `debug`, `info`): Xài `_tracePrinter` (Có method count, stack trace, có viền box mặc định).

Nghĩa là log tắt hiện tại vốn ĐÃ KHÔNG CÓ BOX. Vấn đề là nó quá cơ bản (bare text), không đủ visual hint (màu, emoji, format) để dev quét mắt nhanh trên console.

## Goals / Non-Goals

**Goals:**
- Nâng cấp level visual cho các log `d()`, `i()`, `e()`... ngang ngửa độ "bảnh" của việc format, tag rõ ràng.
- Giữ vững tiêu chí "MỘT DÒNG INLINE" - không bọc box, không line break tràn lan.
- Tận dụng ANSI color / ASCII characters siêu nhỏ để tạo điểm nhấn.

**Non-Goals:**
- Không can thiệp vào cách log full (`debug()`) vẽ box.
- Không thay đổi parameters của các method public `d()`, `i()`.

## Decisions

- Build một `LogPrinter` mới (ví dụ: `InlineBeautyPrinter`) dành riêng cho alias rút gọn thay vì xài lại `PrettyPrinter.minimal` của base logger.
- Pattern hiển thị: `<Color của Level> [Thời gian] [Emoji Level] [Tag] message \u001b[0m`.
- Xử lý Tag: Nếu có, in đậm và bôi background hoặc format riêng để tách bạch với message.

## Risks / Trade-offs

- Custom tự chuốt ANSI code có thể không tương thích 100% các OS (nhất là iOS console không hỗ trợ màu ANSI mạnh). Cần check biến `isColorSupported` rẽ nhánh render fallback plain.
