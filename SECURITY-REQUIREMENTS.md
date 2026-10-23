# Yêu cầu bảo mật của `rexcorp-legacy`: bảng kiểm brownfield

`rexcorp-legacy` là hệ thống đang chạy, chưa có threat model. Tài liệu này **không** đòi nâng cả hệ thống lên chuẩn mới. Nó làm hai việc: (1) đo hiện trạng so với một nhóm nhỏ requirement OWASP ASVS **5.0.0** L1 (và một requirement L2), kèm bằng chứng; (2) chặn **không cho tình trạng xấu đi** bằng script `scripts/requirements-ratchet.sh`. Nội dung requirement lấy từ file CSV chính thức của ASVS 5.0.0 (CC BY-SA 4.0); phần tiếng Việt là diễn giải.

| Mục | Giá trị |
|---|---|
| Repo | `rexcorp-legacy` (brownfield, public) |
| Chuẩn và phiên bản | OWASP ASVS 5.0.0, ID dạng `v5.0.0-x.y.z` |
| Người phụ trách | Kỹ sư DevOps phụ trách bảo mật |
| Cập nhật lần cuối | 2026-10-06 |
| Threat model | Chưa có. Làm theo lát cắt sau khi có đánh giá tổng thể (module 11) |

## Bảng kiểm

Số đếm lấy từ `scripts/requirements-ratchet.sh --print` ngày 2026-10-06.

| ID ratchet | ASVS | Level | Diễn giải | Bằng chứng trong mã nguồn | Trạng thái | Việc cần làm |
|---|---|---|---|---|---|---|
| LEG-1.3.2 | `v5.0.0-1.3.2` | L1 | Tránh `eval()` và thực thi mã động; nếu bắt buộc phải làm sạch dữ liệu người dùng | 3 dòng gọi `eval(req.body...)` trong `app/routes/contributions.js` (dòng 32 đến 34) | Chưa đạt | LEG-007 |
| LEG-1.2.4 | `v5.0.0-1.2.4` | L1 | Truy vấn dữ liệu dùng tham số hóa hoặc được bảo vệ khỏi injection | Truy vấn `$where` ghép chuỗi từ `threshold` trong `app/data/allocations-dao.js`. Grep đếm 2 dòng, trong đó dòng 73 nằm trong khối comment chứa bản sửa; 1 dòng chạy thật | Chưa đạt | LEG-008 |
| LEG-8.2.2 | `v5.0.0-8.2.2` | L1 | Quyền truy cập dữ liệu theo từng đối tượng (chống IDOR) | `app/routes/allocations.js`: `userId` lấy từ `req.params` (URL), không từ phiên đăng nhập; mã sửa nằm trong comment | Chưa đạt | LEG-009 |
| LEG-13.3.1 | `v5.0.0-13.3.1` | **L2** | Secret không nằm trong mã nguồn | `config/env/all.js` có `cookieSecret` và `cryptoKey` là chuỗi viết cứng. **Gitleaks (module 02) không báo hai dòng này**; `gitleaks dir config/env/all.js` trả `no leaks found` | Chưa đạt, gate secret không thấy | LEG-010 |

Đã thấy nhưng chưa đưa vào ratchet: `v5.0.0-3.3.1` (cookie phiên phải có thuộc tính `Secure`): khối cấu hình `cookie` trong `server.js` đang bị comment (LEG-011). Lý do chưa đưa vào ratchet: grep không đếm "có cấu hình" một cách đáng tin; để module 04 và 07.

## Ratchet: không để xấu đi

`scripts/requirements-ratchet.sh` đếm số dòng khớp mỗi mẫu lỗi và so với `.security/requirements-baseline.txt`. Quy tắc:

- Số đếm **tăng** so với baseline: job `requirements-ratchet` fail, chặn merge.
- Số đếm **giảm**: không fail; script nhắc hạ baseline qua pull request (người phụ trách duyệt).
- Đổi baseline để **tăng** số đếm không được phép; muốn thêm ngoại lệ phải có ADR.

Giới hạn đã biết: grep đếm dòng và không hiểu cú pháp (dòng trong khối `/* ... */` vẫn bị đếm, đổi cách viết là qua mặt được). Module 04 thay bước này bằng SAST.

## Backlog

Xem `docs/security-backlog.lab-03.md` (thêm vào `docs/security-backlog.md`).

## Lịch sử thay đổi

| Ngày | Người sửa | Thay đổi |
|---|---|---|
| 2026-10-06 | Kỹ sư DevOps phụ trách bảo mật | Tạo bảng kiểm 4 requirement và ratchet (Lab 03) |
