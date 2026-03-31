## 1. Custom Inline Log Printer

- [ ] 1.1 Khảo sát luồng gọi của `DPrettyPrinter.minimal()` trong `lib/src/logger/diqit_pretty_printer.dart`.
- [ ] 1.2 Viết (hoặc update) Printer chuyên chém gió cho shorthand log (d(), i(), w(), e()) không chèn khung box, nhưng PHẢI inject được màu mè (ANSI colors) và Text style để tách biệt `Time`, `Tag`, và `Level`.
- [ ] 1.3 Cập nhật mảng emoji: Tái sử dụng (hoặc tuỳ chỉnh) `symbolsEmojis` hoặc `mixedEmojis` để log có 1 cái icon bé xíu phía trước (vd: ✔, ⚠, ⚡).

## 2. DiqitLogger integration Update

- [ ] 2.1 Cập nhật `_minimalPrinter` getter bên trong `diqit_logging.dart` để trỏ vào Printer mới vừa build.
- [ ] 2.2 Xử lý graceful degradation: Đảm bảo `isColorSupported` vẫn handle mượt trên iOS (fall back về ASCII char/text không màu rực).

## 3. Demo & Testing

- [ ] 3.1 Dùng test script in một list các log shorthand liên hoàn (dùng các level khác nhau, có tag) để quan sát UI trên MacOS/Android console. Đảm bảo clean, ko line break bậy bạ.
- [ ] 3.2 So sánh benchmark thị giác với log "nặng" (debug()).
