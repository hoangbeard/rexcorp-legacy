# Backlog SBOM của rexcorp-legacy

Bổ sung cho `docs/security-backlog-dependencies.md` (Lab 05a). Số liệu đo ngày 2026-10-06 bằng Syft v1.54.0; chạy lại 2026-10-23 bằng Syft v1.55.0 cho cùng số.

| ID | Mô tả | Mức độ | Người phụ trách | Hạn | Trạng thái |
|---|---|---|---|---|---|
| DEP-006 | SBOM của `rexcorp-legacy` (1224 component npm) chỉ có thông tin giấy phép cho 386 component (SCVS 2.14 chưa đạt). Thử `SYFT_JAVASCRIPT_SEARCH_REMOTE_LICENSES=true` (Syft hỏi registry npm): 387 trên 413 component khi SBOM chỉ có phần production, chạy mất khoảng 1 phút 45 giây | Trung bình | Kỹ sư DevOps phụ trách bảo mật | 90 ngày | Mở |
| DEP-007 | Mọi package trong `package-lock.json` của repo cũ là npm; ngoài ra thư mục `app/assets/vendor/` (bootstrap, chart, theme) chứa file JavaScript chép tay: OSV-Scanner quét thư mục đó và báo "found 0 packages" cho cả ba thư mục con, tức là không nhận ra thư viện nào. Cần kiểm tra thủ công xem đó là thư viện nào, phiên bản nào; hiện chúng không được quét lỗ hổng | Trung bình | Trưởng nhóm phát triển | 60 ngày | Mở |
