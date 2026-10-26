# Backlog bảo mật: container và cấu hình của rexcorp-legacy

Việc phát sinh từ baseline của Lab 06. Baseline `.trivyignore.yaml` là "đã biết, đang xử lý", **không** phải "đã chấp nhận". Mỗi nhóm mục baseline có một việc ở đây. Hạn xử lý nên nằm trước hạn `expired_at` tương ứng.

| ID | Mô tả | Mức độ | Người phụ trách | Hạn | Trạng thái |
|---|---|---|---|---|---|
| SEC-L01 | Base image `node:12-alpine`: Node.js 12 hết hỗ trợ 2022-04-30 (lịch phát hành Node.js), Alpine 3.15 hết hỗ trợ (Trivy cảnh báo), tag cuối cùng được đẩy 2022-04-11. Cần chuyển sang bản LTS còn hỗ trợ, cần kiểm thử ứng dụng (Cypress `test:ci`) trước khi đổi; chưa làm trong Lab 06 | Cao | CTO chỉ định người phụ trách | Kế hoạch trong 30 ngày | Mở |
| SEC-L02 | 80 phát hiện HIGH/CRITICAL trong dependency npm của image (53 CVE khác nhau; nhiều nhất ở `brace-expansion`, `tar`, `minimatch`, `kind-of`, `minimist`). Xử lý cùng backlog dependency của module 05: `docs/security-backlog-dependencies.md` | Cao | Nhóm phát triển | Theo hạn của baseline: CRITICAL 2026-11-24, HIGH 2026-12-24 | Mở |
| SEC-L03 | 9 phát hiện HIGH/CRITICAL ở gói Alpine (`libcrypto1.1`, `libssl1.1`, …): chỉ hết khi đổi base image (SEC-L01) | Cao | Cùng SEC-L01 | Cùng SEC-L01 | Mở |
| SEC-L04 | Khóa riêng TLS mẫu `artifacts/cert/server.key` nằm trong image (Trivy `private-key`, HIGH). `server.js` đọc file này khi khởi động nên không thể chỉ loại khỏi `.dockerignore`: cần đưa khóa vào lúc chạy (mount secret) và sửa `server.js`. Khóa này cũng nằm trong lịch sử git (Lab 02) | Trung bình | Nhóm phát triển | 2026-11-24 (hạn baseline của secret) | Mở |
| SEC-L05 | Trivy không quét chính binary Node.js 12 (không phải gói quản lý bởi apk/npm). Grype báo thêm 42 CVE cho `node 12.22.12`, gồm CVE-2023-44487 nằm trong danh mục KEV của CISA. Không có bản vá trong nhánh 12: chỉ hết khi nâng Node.js (SEC-L01) | Cao | Cùng SEC-L01 | Cùng SEC-L01 | Mở |
| SEC-L06 | KICS báo 10 finding cho `docker-compose.yml` (8 MEDIUM, 2 LOW): `Container Capabilities Unrestricted`, `Healthcheck Not Set`, `Memory Not Limited`, `Security Opt Not Set`, `Cpus Not Limited`. Gate chỉ chặn từ HIGH; sửa dần: thêm `cap_drop`, `security_opt`, giới hạn bộ nhớ và CPU cho hai service | Trung bình | Nhóm phát triển | 2026-12-24 | Mở |
| SEC-L07 | Hai job của `container.yml` chưa là required status check của `main` | Trung bình | Kỹ sư DevOps phụ trách bảo mật | Module 08 | Mở |
