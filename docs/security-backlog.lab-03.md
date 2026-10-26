<!--
Các dòng backlog của Lab 03 cho rexcorp-legacy. Cách dùng: thêm vào bảng trong docs/security-backlog.md
(giữ nguyên LEG-001 đến LEG-006 từ Lab 02). Cột khác với bảng của Lab 02: bảng này nói về requirement ASVS, không phải finding secret.
-->

| ID | Requirement và bằng chứng | Đánh giá ban đầu | Việc cần làm | Người phụ trách | Hạn | Trạng thái |
|---|---|---|---|---|---|---|
| LEG-007 (cùng việc với SAST-L01, Lab 04) | `v5.0.0-1.3.2`: `eval(req.body.preTax)`, `afterTax`, `roth` trong `app/routes/contributions.js:32-34` | Cao: người dùng đăng nhập chạy được mã JavaScript tùy ý trên server | Thay `eval` bằng phân tích số (`parseInt`, hoặc thư viện parse), kèm test | Đội `rexcorp-legacy` | 30 ngày | Mở. Ratchet chặn thêm `eval` mới |
| LEG-008 (cùng việc với SAST-L10, Lab 04) | `v5.0.0-1.2.4`: `$where` ghép chuỗi từ `threshold` trong `app/data/allocations-dao.js` | Cao: NoSQL injection | Dùng bản sửa đã có trong comment (ép kiểu `parseInt`, kiểm tra 0 đến 99) rồi bỏ `$where` | Đội `rexcorp-legacy` | 30 ngày | Mở |
| LEG-009 | `v5.0.0-8.2.2`: `/allocations/:userId` lấy `userId` từ URL | Cao: người dùng xem được phân bổ của người khác | Lấy `userId` từ phiên (bản sửa có trong comment) kèm test | Đội `rexcorp-legacy` | 30 ngày | Mở |
| LEG-010 | `v5.0.0-13.3.1` (L2): `cookieSecret`, `cryptoKey` viết cứng trong `config/env/all.js`; Gitleaks không báo | Cao: secret ký phiên dùng chung và biết trước | Đọc từ biến môi trường, xoay vòng giá trị; thêm rule Gitleaks riêng hoặc thử thêm công cụ khác (module 04, 09) | Kỹ sư DevOps phụ trách bảo mật | 30 ngày | Mở |
| LEG-011 | `v5.0.0-3.3.1`: cấu hình cookie `Secure` trong `server.js` đang bị comment | Trung bình: cookie phiên có thể đi qua HTTP thường | Bật cấu hình cookie cùng với HTTPS; kiểm bằng DAST (module 07) | Đội `rexcorp-legacy` | 60 ngày | Mở |
