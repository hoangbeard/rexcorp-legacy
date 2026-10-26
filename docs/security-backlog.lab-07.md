<!--
Các dòng backlog của Lab 07 cho rexcorp-legacy. Thêm vào docs/security-backlog.md (hoặc để riêng, không ghi đè file của lab khác).
.zap/progress.json ở gốc repo trỏ tới các mã DAST-1xx dưới đây.
-->

# Backlog DAST của rexcorp-legacy

Các rule trong `.zap/progress.json` (state `inprogress`) **không** có nghĩa là chấp nhận rủi ro. Chúng có nghĩa là "đã biết, đang xử lý, có người phụ trách": ZAP in chúng là `FAIL-IN_PROGRESS` và không tính vào exit code, để gate chỉ chặn rule `FAIL` **mới**. Khi một mục đóng, xóa nó khỏi `progress.json` để gate chặt lại.

| ID | Rule ZAP (ID) | Quan sát trong lần quét ẩn danh | Việc cần làm | Người phụ trách | Hạn | Trạng thái |
|---|---|---|---|---|---|---|
| DAST-101 | 10020 Anti-clickjacking, 10021 X-Content-Type-Options, 10038 CSP | Không có cả ba header trên mọi trang HTML. Ứng dụng dùng Express 4 và `helmet` 2.x (đã cũ) nhưng chưa bật; một số trang nạp script từ nguồn ngoài nên CSP cần được thiết kế, không chép từ `rexcorp-app` | Nâng `helmet` (cần module 05), bật từng header, CSP bắt đầu ở chế độ report-only | Trưởng nhóm phát triển | 60 ngày | Mở |
| DAST-102 | 10037 `X-Powered-By` | Mọi phản hồi có `X-Powered-By: Express` | `app.disable('x-powered-by')` (một dòng) | Trưởng nhóm phát triển | 14 ngày | Mở |
| DAST-103 | 10028 Off-site Redirect | `/learn?url=…` chuyển hướng tới URL do người dùng đưa vào (đây là lỗ hổng open redirect cố ý của dự án gốc) | Chỉ cho phép đích trong allowlist; sửa hoặc bỏ route | Trưởng nhóm phát triển | 30 ngày | Mở |
| DAST-104 | 90022 Application Error Disclosure | `/allocations/<id>?threshold=…` trả lỗi 500 kèm chi tiết khi tham số không hợp lệ. **Chỉ xuất hiện khi spider đi tới trang này**, không xuất hiện ở mọi lần quét | Trả thông báo lỗi chung, ghi chi tiết vào log phía server | Trưởng nhóm phát triển | 30 ngày | Mở |
| DAST-105 | (WARN, không chặn) 10003 thư viện JS cũ, 10017 script từ miền khác, 10054 cookie thiếu SameSite, 10055 CSP, 10063 Permissions-Policy, 90004 CORP | Xem báo cáo `zap-report-legacy` | Triage hằng tuần: quyết định sửa, nâng lên `FAIL`, hay `IGNORE` có hạn | Kỹ sư DevOps phụ trách bảo mật | Hằng tuần | Mở |
| DAST-106 | Cookie phiên `connect.sid` chưa có `Secure` và `SameSite` | Ứng dụng chạy HTTP trong lab. Chỉ kiểm được khi có TLS | Quét lại ở staging có TLS | Kỹ sư DevOps phụ trách bảo mật | Khi có staging | Mở |
