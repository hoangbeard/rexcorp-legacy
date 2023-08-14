# rexcorp-legacy

Cổng phúc lợi nhân viên của **RexCorp** (công ty hư cấu): đóng góp hưu trí, phân bổ quỹ, phúc lợi, ghi chú nội bộ. Đây là hệ thống "brownfield" của khóa **DevSecOps Nền tảng** (RexLearn): một ứng dụng đang chạy, nhiều nợ kỹ thuật và nợ bảo mật.

> **Cảnh báo.** Ứng dụng này **cố ý chứa lỗ hổng** và secret giả. Chỉ chạy trên máy của bạn, chỉ bind `127.0.0.1`. Không deploy ra Internet. Không dùng lại mã nguồn cho hệ thống thật.

## Nguồn gốc và giấy phép

Mã nguồn được sửa đổi từ [OWASP NodeGoat](https://github.com/OWASP/NodeGoat) (Apache License 2.0), giữ nguyên lịch sử git của dự án gốc. Giấy phép: [LICENSE](LICENSE) (Apache-2.0). Ghi công: [NOTICE](NOTICE). Danh sách thay đổi so với bản gốc: [CHANGES.md](CHANGES.md). RexCorp và RexLearn không liên quan và không được OWASP bảo trợ.

## Chạy trên máy (Docker)

```bash
docker compose up --build      # http://127.0.0.1:4000
docker compose down
```

Tài khoản mẫu (dữ liệu seed): `admin` / `Admin_123`, `user1` / `User1_123`, `user2` / `User2_123`.

## Hiện trạng (đừng sửa vội)

Khóa học dùng chính các vấn đề của repo này làm đề bài: dependency cũ, base image hết hỗ trợ, workflow CI pin theo tag và không khai báo `permissions`, CI cũ trên Travis song song với GitHub Actions, secret từng bị commit vào lịch sử. Mỗi module áp một control lên repo này theo cách triển khai dần: đo baseline, chỉ chặn finding mới, rồi siết dần.
