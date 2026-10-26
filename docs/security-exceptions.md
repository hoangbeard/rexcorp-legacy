# Sổ ngoại lệ bảo mật: `rexcorp-legacy`

Sổ ghi mọi quyết định chấp nhận rủi ro có thời hạn của repo này. Quy định đầy đủ nằm trong [`SECURITY-GATE.md`](../SECURITY-GATE.md), mục "Ngoại lệ". Kiểm tra bằng `scripts/check-exceptions.sh`.

**Baseline không phải ngoại lệ.** Các file baseline (`.security/gitleaks-baseline.json`, `osv-scanner.toml`, `.trivyignore.yaml`, `.zap/progress.json`) ghi nợ đã biết, mỗi mục có hạn và một mục trong backlog. Một mục baseline chỉ được chuyển thành dòng trong sổ này khi sắp quá hạn xử lý của bậc mà chưa sửa kịp, và khi đó cần có người duyệt.

## Quy định

| Câu hỏi | Quy định |
|---|---|
| Ngoại lệ dùng khi nào? | Giống `rexcorp-app`: chưa sửa kịp trong thời hạn của bậc, báo nhầm đã xác nhận, hoặc có bằng chứng viết ra rằng đường khai thác không tồn tại ở cấu hình này |
| Trần thời hạn từ ngày duyệt | P1: 14 ngày. P2: 30 ngày. P3: 90 ngày. P4 và FP: 6 tháng (tối đa 183 ngày) |
| Ai duyệt | P1 và P2: CTO. P3: trưởng nhóm phát triển. P4 và FP: người phụ trách bảo mật, hoặc trưởng nhóm phát triển khi chính người phụ trách bảo mật là người xin. Người xin không tự duyệt |
| Gia hạn | Mở dòng mới, ghi vì sao lần trước không sửa được; chuyển dòng cũ xuống "Đã đóng" |
| Ai xem lại sổ | Người phụ trách bảo mật, mỗi thứ Hai và trong buổi triage hằng tuần |

## Đang hiệu lực

| ID | Control | Finding | Bậc | Lý do và biện pháp tạm thời | Người xin | Người duyệt | Ngày duyệt | Hết hạn | Nơi cấu hình | Trạng thái |
|---|---|---|---|---|---|---|---|---|---|---|
| EXC-0001 | Container | Base image `node:12-alpine` (SEC-L01): CVE-2023-44487 trong Node.js 12.22.12 (KEV) và 9 phát hiện HIGH ở gói Alpine (`libcrypto1.1`, `libssl1.1`) | P2 | Chỉ hết khi đổi base image sang bản LTS còn hỗ trợ, cần chạy Cypress `test:ci` trước, không kịp trong 14 ngày. CVE-2023-44487 chỉ ảnh hưởng người dùng máy chủ HTTP/2 (thông báo bảo mật của Node.js, 13/10/2023); ứng dụng chỉ dùng `http.createServer` (HTTP/1.1) và không có `require('http2')` (đã grep). Biện pháp tạm thời: đội vận hành xác nhận trong 3 ngày rằng proxy phía trước không bật HTTP/2 tới ứng dụng; không mở thêm cổng nào khác | Kỹ sư DevOps phụ trách bảo mật | CTO | 2026-10-26 | 2026-11-25 | `.trivyignore.yaml` | Đang hiệu lực |
| EXC-0002 | SAST | SAST-L03: ba finding `detected-bcrypt-hash` ở `artifacts/db-reset.js` dòng 19, 28, 36 | FP | Hash bcrypt nằm trong dòng chú thích của script seed dữ liệu thử, ngay cạnh mật khẩu thô `Admin_123`: hash không thêm thông tin gì. Việc cần làm thật (mật khẩu mặc định trong seed) nằm ở backlog SEC-L08, không ở ngoại lệ này | Trưởng nhóm phát triển | Kỹ sư DevOps phụ trách bảo mật | 2026-10-26 | 2027-04-24 | `artifacts/db-reset.js` | Đang hiệu lực |
| EXC-0003 | DAST | Bốn rule ZAP đặt `IGNORE` (10049, 10109, 10111, 10112): thông tin, không phải lỗ hổng | FP | Cùng lý do và cùng bộ rule với `rexcorp-app` (EXC-0002 của repo đó): ZAP nhận diện tính năng của ứng dụng, không báo lỗi. Đã đọc từng cảnh báo ở Lab 07. Xem lại khi đổi cách xác thực | Kỹ sư DevOps phụ trách bảo mật | Trưởng nhóm phát triển | 2026-10-26 | 2027-04-25 | `.zap/rules.tsv` | Đang hiệu lực |

## Đã đóng

| ID | Control | Finding | Bậc | Lý do và biện pháp tạm thời | Người xin | Người duyệt | Ngày duyệt | Hết hạn | Nơi cấu hình | Trạng thái |
|---|---|---|---|---|---|---|---|---|---|---|
