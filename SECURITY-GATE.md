# SECURITY-GATE: `rexcorp-legacy`

<!--
Cách dùng mẫu:
1. Chép file này vào GỐC repo, đặt tên SECURITY-GATE.md. Một repo một file.
2. Mỗi module của khóa học điền MỘT mục control, đúng lúc bạn triển khai control đó.
   Mục chưa áp dụng thì để nguyên dòng "Chưa áp dụng", đừng xóa: người đọc cần thấy cả những gì CHƯA có.
3. Viết quy định đủ cụ thể để hai người đọc ra cùng một quyết định: chặn khi nào, ai duyệt ngoại lệ, hạn bao lâu.
4. File này là policy: mọi thay đổi đi qua pull request và được người phụ trách bảo mật duyệt
   (module 08 thêm CODEOWNERS cho file này).
5. Xóa các comment hướng dẫn khi đã điền xong một mục.
-->

## Phạm vi và người chịu trách nhiệm

| Mục | Giá trị |
|---|---|
| Repo | `rexcorp-legacy`: cổng phúc lợi nhân viên, hệ thống đang chạy (brownfield), repo public |
| Người phụ trách bảo mật | Kỹ sư DevOps phụ trách bảo mật |
| Người triage | Kỹ sư DevOps phụ trách bảo mật |
| Áp dụng từ | 2026-10-05 |

## Quy tắc chung

- Repo có nợ cũ, nên mỗi control đi theo ba bước: đo baseline, chỉ chặn finding mới, rồi thu nhỏ baseline dần.
- Gate mới nằm trong workflow riêng (`.github/workflows/secret-scan.yml`), chạy trên mọi `pull_request` và push lên `main`. Các workflow cũ chưa sửa ở bước này.
- Mỗi finding trong baseline có một mục trong `docs/security-backlog.md`. Baseline nghĩa là "đã biết, đang xử lý", không phải "đã chấp nhận".

## Control

### Quét secret (module 02)

| Hạng mục | Quy định |
|---|---|
| Công cụ và phiên bản | Gitleaks CLI v8.30.1, image `ghcr.io/gitleaks/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f`, cấu hình mặc định. Bổ sung: secret scanning và push protection của GitHub |
| Chạy ở đâu | CI: job `gitleaks` trong `secret-scan.yml`, quét toàn bộ lịch sử mà `HEAD` mang theo (`--log-opts="--full-history --diff-filter=tuxdb HEAD"`), không quét nhánh khác. Server: push protection của GitHub; secret scanning của GitHub quét mọi nhánh sau khi push. Đánh giá định kỳ: chạy TruffleHog (`--no-verification`) đối chiếu mỗi quý |
| Điều kiện chặn | Mọi finding **không có trong baseline** làm job fail (exit code 1). Finding đã có trong baseline không chặn |
| Baseline / ngoại lệ | Baseline: `.security/gitleaks-baseline.json`, tạo ngày 2026-10-05 bằng `gitleaks git --redact --report-format json`, gồm 6 finding (không chứa giá trị secret). Chỉ được tạo lại để **bớt** finding, qua pull request do người phụ trách bảo mật duyệt, kèm giải thích từng finding bị bỏ. Không bao giờ tạo lại baseline để "cho qua" một finding mới. Ngoại lệ lẻ dùng `.gitleaksignore` theo cùng quy định với `rexcorp-app` (lý do, người chịu trách nhiệm, hạn tối đa 6 tháng) |
| Đóng alert secret scanning | Chỉ sau khi triage như một finding: secret là gì, của ai, còn trong HEAD không, thu hồi được không. Lý do phải đúng với điều đã chứng minh; comment (tối đa 280 ký tự, không sửa được sau khi đóng) trỏ về mục backlog. Ghi vào bảng "Nhật ký đóng alert" ngay dưới |
| Bypass push protection | Chỉ với lý do "It's used in tests" hoặc "It's a false positive", sau khi đã xác minh và ghi vào bảng "Nhật ký bypass push protection" ngay dưới bảng này. Lý do "I'll fix it later" xử lý như sự cố. Không bypass một secret mà chưa biết nó là gì |
| Bằng chứng | Artifact `gitleaks-sarif` (SARIF 2.1.0, đã redact), giữ 30 ngày; log job; alert trong tab Security (alert của lần bypass có trạng thái đóng kèm lý do) |
| Triage và thời hạn xử lý | Finding mới: xử lý theo runbook xử lý secret bị lộ (bản của `rexcorp-app`), thu hồi trong ngày. Finding trong baseline: theo hạn trong `docs/security-backlog.md` |
| Giới hạn đã biết (chưa enforce) | Như `rexcorp-app`: job chưa là required status check (module 08); pull request tự sửa được baseline, `.gitleaksignore` và workflow của chính nó cho tới khi có `CODEOWNERS` và required review (module 08); Gitleaks không đọc ngày hết hạn. Baseline bỏ qua mọi đường dẫn `node_modules` theo cấu hình mặc định của Gitleaks, nên finding trong `node_modules` cũ chỉ thấy qua TruffleHog và push protection |
| Căn cứ trực tiếp | MITRE CWE-798 (secret viết cứng); GitHub Docs về push protection (bypass có lý do, alert được tạo và đóng theo lý do) |
| Căn cứ framework | Như `rexcorp-app` (ánh xạ của khóa học): NIST SSDF 1.1 PS.1.1, PO.3.1, PO.3.2, PO.3.3, PO.4.1, PO.4.2. Bản đồ pipeline NCCoE: Secret Scanner, phase Develop |

#### Nhật ký bypass push protection

| Ngày | Secret (loại, vị trí, không ghi giá trị) | Đã xác minh gì | Lý do chọn | Người bypass | Bằng chứng |
|---|---|---|---|---|---|
| 2026-10-23 | Cặp "Amazon AWS Access Key ID" và "Amazon AWS Secret Access Key", commit `a7b556d` (2013-12-02, "Included node_modules…"), `node_modules/forever/…/request/tests/test-s3.js` dòng 5–6 (5 bản sao của thư viện `request` 2.9.203 và 2.16.6) | (1) Commit 2013 của dự án gốc NodeGoat, không phải của RexCorp. (2) File nằm trong thư mục `tests/` của thư viện bên thứ ba `request`, là test gọi S3 mẫu. (3) Hai dòng key giống hệt file `tests/test-s3.js` trong repo công khai `request/request` (thư viện tự xóa test này ngày 2013-12-13). (4) `node_modules` đã bị xóa khỏi repo từ 2015 (commit `54baea0`). (5) TruffleHog ở Bước 8 báo đúng 5 kết quả AWS này. Kết luận: fixture test công khai của thư viện, RexCorp không sở hữu và không thu hồi được | It's used in tests | Kỹ sư DevOps phụ trách bảo mật | Output GH013; alert secret scanning đóng với lý do "used in tests"; log push thành công. Không viết lại lịch sử (lý do trong backlog LEG-005) |

#### Nhật ký đóng alert secret scanning không do bypass

| Ngày | Alert (loại, vị trí, không ghi giá trị) | Đã xác minh gì | Lý do đóng | Người đóng | Bằng chứng |
|---|---|---|---|---|---|
| 2026-10-23 | Alert 2: "MongoDB Atlas Database URI with credentials", `config/env/all.js:6`, commit `5ab0088` (2020) | (1) Commit của dự án gốc NodeGoat, có trong repo công khai `OWASP/NodeGoat`. (2) Chuỗi chỉ dùng khi `NODE_ENV === 'test'`: cluster test của dự án gốc. (3) Bỏ khỏi file từ commit `1957f9a` (2021); HEAD không còn. (4) Cấu hình của RexCorp đọc `MONGODB_URI` từ biến môi trường. Kết luận: credential của bên thứ ba, RexCorp không sở hữu, không thu hồi được | `wont_fix` (không chọn `used_in_tests`, vì đây không phải fixture giả mà là credential thật của bên thứ ba, chưa rõ còn hiệu lực) | Kỹ sư DevOps phụ trách bảo mật | Alert 2 `resolved`/`wont_fix` với comment trỏ về backlog LEG-006 |

### Yêu cầu bảo mật (module 03)

| Hạng mục | Quy định |
|---|---|
| Công cụ và phiên bản | Bảng kiểm requirement OWASP ASVS 5.0.0 trong `SECURITY-REQUIREMENTS.md`; ratchet bằng `scripts/requirements-ratchet.sh` (bash, grep), workflow `.github/workflows/requirements-ratchet.yml`. Chưa có threat model đầy đủ (module 11) |
| Chạy ở đâu | CI: job `requirements-ratchet` trên mọi `pull_request` và push lên `main` |
| Điều kiện chặn | Số dòng khớp của bất kỳ mẫu lỗi nào trong `.security/requirements-baseline.txt` **tăng** so với baseline làm job fail. Số đếm bằng hoặc giảm không chặn |
| Baseline / ngoại lệ | `.security/requirements-baseline.txt` (tạo 2026-10-06). Chỉ được sửa để **hạ** số đếm, qua pull request do người phụ trách bảo mật duyệt. Tăng số đếm cần ADR, lý do, người chịu trách nhiệm, hạn xem lại |
| Bằng chứng | Log job `requirements-ratchet`; `SECURITY-REQUIREMENTS.md` (trạng thái từng requirement) |
| Triage và thời hạn xử lý | Mỗi dòng trong bảng kiểm có mục `LEG-007` đến `LEG-011` trong `docs/security-backlog.md`, hạn 30 đến 60 ngày. Ratchet là biện pháp tạm; module 04 thay bằng SAST |
| Căn cứ framework | Ánh xạ của khóa học vào NIST SSDF 1.1: PO.1.2 (tài liệu hóa requirement, trang 5), PW.1.2 (theo dõi requirement, rủi ro, quyết định thiết kế, trang 11), PO.4.2 Ex. 3 (tự động hóa quyết định theo tiêu chí, trang 8). Requirement: OWASP ASVS 5.0.0 |

<!-- Thêm vào bảng "Lịch sử thay đổi":
| 2026-10-06 | Kỹ sư DevOps phụ trách bảo mật | Thêm mục "Yêu cầu bảo mật" và ratchet (Lab 03) |
-->

### SAST: phân tích tĩnh mã nguồn (module 04)

| Hạng mục | Quy định |
|---|---|
| Công cụ và phiên bản | Semgrep CE 1.182.0, image `semgrep/semgrep:1.182.0@sha256:4a34048c04fef049f71665047f074cffb00cc3d89482f965a5cd151d589237af`, gói rule `p/default` (dùng nội bộ theo Semgrep Rules License v1.0), `--metrics off`. Workflow riêng `.github/workflows/sast.yml`; các workflow cũ chưa sửa ở bước này |
| Chạy ở đâu | Pull request: gate so với commit gốc. Push lên `main` và hằng tuần (thứ Hai 03:17 UTC): kiểm kê toàn bộ finding mọi mức, không chặn |
| Điều kiện chặn | Trên pull request: mọi finding mức **ERROR không có ở commit gốc** của pull request (`--baseline-commit`) làm job fail. Finding đã có ở commit gốc không chặn. Lưu ý đã kiểm chứng: sửa chính dòng chứa finding cũ thì finding đó được tính là mới; chèn dòng hoặc đổi tên file thì không |
| Baseline / ngoại lệ | Không có file baseline: baseline là commit gốc của từng pull request. Nợ cũ được kiểm kê trong `docs/sast-backlog.md` (cập nhật từ báo cáo hằng tuần). Ngoại lệ lẻ: `// nosemgrep: <rule-id> -- <ID>: <lý do>; xem lại trước <ngày>`, hạn tối đa 6 tháng, qua pull request do người phụ trách bảo mật duyệt. Cấm `nosemgrep` không kèm rule ID |
| Bằng chứng | Artifact `semgrep-sarif`: `semgrep-gate.sarif` (chỉ trên pull request) và `semgrep-all.sarif` (toàn bộ, mọi mức), giữ 30 ngày; `docs/sast-backlog.md` |
| Triage và thời hạn xử lý | Finding ERROR mới: triage trong 1 ngày làm việc, sửa trước khi merge. Nợ cũ: theo hạn trong `docs/sast-backlog.md`; ưu tiên theo khả năng khai thác, không theo thứ tự công cụ báo |
| Căn cứ framework | Như `rexcorp-app` (NIST SSDF 1.1 PW.7.1, PW.7.2; ánh xạ PO.3, PO.4; bản đồ pipeline NCCoE, SAST System). Cách triển khai dần từng bước cho hệ thống cũ là lựa chọn của khóa học, không phải câu chữ của framework |

### Dependency, SCA và SBOM (module 05)

#### SCA: lỗ hổng trong dependency (triển khai dần)

| Hạng mục | Quy định |
|---|---|
| Công cụ và phiên bản | OSV-Scanner v2.6.0 (image pin digest như `rexcorp-app`), workflow `dependency-scan.yml`; Dependabot version updates giai đoạn 1 (chỉ bản patch) |
| Điều kiện chặn | Mọi lỗ hổng không nằm trong `osv-scanner.toml` làm job fail: tức là chỉ chặn lỗ hổng MỚI |
| Baseline | `osv-scanner.toml` tạo ngày 2026-10-06 bằng `labs/scripts/lab-05a-osv-baseline.sh`: 190 mục, mỗi mục có `ignoreUntil` theo mức độ (Critical 30 ngày, High 60 ngày, còn lại 90 ngày). Baseline là "đã biết, đang xử lý", không phải "đã chấp nhận": xem `docs/security-backlog-dependencies.md` (DEP-001 đến DEP-005) |
| Tạo lại baseline | Chỉ để thu nhỏ (xóa mục đã xử lý hoặc hết lý do), qua pull request, người phụ trách bảo mật duyệt. Không bao giờ chạy script tạo baseline để "làm gate xanh" khi gate đỏ vì lỗ hổng mới |
| Hết hạn | Mục hết hạn mà chưa xử lý: gate đỏ, người phụ trách quyết định xử lý hoặc gia hạn có lý do mới (tối đa một lần, 30 ngày) |
| Căn cứ framework | NIST SSDF 1.1: PW.4.4, RV.1.1, PO.4.2; OpenSSF S2C2F SCA-1, UPD-1 (L1) rồi UPD-2 (L2) khi baseline đã nhỏ |


#### SBOM (triển khai dần)

| Hạng mục | Quy định |
|---|---|
| Công cụ và phiên bản | Syft v1.55.0 (image pin digest), workflow `sbom.yml`; có `SYFT_JAVASCRIPT_INCLUDE_DEV_DEPENDENCIES=true` để SBOM gồm cả `devDependencies` |
| Giai đoạn hiện tại | Chỉ tạo và lưu SBOM (artifact `sbom-rexcorp-legacy`, 90 ngày), chạy `scvs-l1-check.sh` ở chế độ báo cáo (`continue-on-error`). Chưa chặn |
| Khoảng trống đã biết | SCVS 2.14 (giấy phép): 386 trên 1224 component npm có thông tin giấy phép (2026-10-06). Lockfile cũ không ghi `license` cho phần lớn package. Việc cần làm: ghi vào `docs/security-backlog-dependencies.md` (DEP-006) |
| Khi nào chặn | Khi tỷ lệ component có giấy phép đạt mức đã thống nhất với bên pháp chế, hoặc khi khách hàng yêu cầu bằng hợp đồng |
| Căn cứ framework | NIST SSDF 1.1: PS.3.2; OWASP SCVS V2 L1 (2.9, 2.14) |

### Container image và cấu hình (module 06)

Chưa áp dụng.

### DAST: kiểm thử động (module 07)

Chưa áp dụng.

### Bảo vệ chính pipeline CI (module 09)

Chưa áp dụng. Đã biết: các workflow cũ pin action theo tag và không khai báo `permissions`. zizmor 1.31.1 (`--offline`, ngày 2026-10-23) báo 12 finding, 4 bị ẩn theo mặc định, còn lại 2 medium và 6 high. Lần push đầu lên GitHub (2026-10-23), workflow `E2E Test` cũ fail ngay vì GitHub chặn `actions/cache@v2` và `actions/upload-artifact@v2` đã ngừng hỗ trợ (LEG-W01).

### Toàn vẹn artifact: ký và provenance (module 10)

Chưa áp dụng.

## Lịch sử thay đổi

| Ngày | Người sửa | Thay đổi |
|---|---|---|
| 2026-10-05 | Kỹ sư DevOps phụ trách bảo mật | Tạo file; thêm mục "Quét secret" với baseline 6 finding (Lab 02) |
| 2026-10-23 | Kỹ sư DevOps phụ trách bảo mật | Ghi lần bypass push protection khi đẩy repo lên GitHub lần đầu; thêm mục "Giới hạn đã biết" |
| 2026-10-23 | Kỹ sư DevOps phụ trách bảo mật | Triage và đóng alert 2 (MongoDB Atlas, `wont_fix`); thêm quy định đóng alert và nhật ký đóng alert |
