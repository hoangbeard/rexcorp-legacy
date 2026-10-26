# SECURITY-GATE: `rexcorp-legacy`

## Phạm vi và người chịu trách nhiệm

| Mục | Giá trị |
|---|---|
| Repo | `rexcorp-legacy`: cổng phúc lợi nhân viên, hệ thống đang chạy (brownfield), repo public |
| Người phụ trách bảo mật | Kỹ sư DevOps phụ trách bảo mật |
| Người triage | Kỹ sư DevOps phụ trách bảo mật |
| Áp dụng từ | 2026-10-05 |

## Quy tắc chung

### Gate là gì và chặn như thế nào

- **Gate** là một job CI có điều kiện chặn viết sẵn trong mục control bên dưới. Job fail (exit code khác 0) nghĩa là gate chặn. Tiêu chí chặn của từng control nằm ở hàng "Điều kiện chặn" của mục đó; file này là nơi duy nhất ghi chúng.
- Job đỏ chỉ ngăn được merge khi nó là **required status check** của nhánh `main`. Ruleset `main: security gates` ([`docs/rulesets/main-protection.json`](docs/rulesets/main-protection.json)) đòi: pull request bắt buộc; 1 approval, gồm code owner; commit mới đẩy lên thì hủy approval cũ và người đẩy commit cuối không tự duyệt; thảo luận phải được giải quyết; 12 check bắt buộc ở bảng dưới; nhánh phải cập nhật với `main`; cấm force push và xóa nhánh. Người học làm một mình dùng bản `main-protection-solo.json` (không bắt buộc approval, vì tác giả pull request không tự duyệt được pull request của mình).
- Check bắt buộc có trạng thái `success`, `skipped` hoặc `neutral` đều được tính là đạt. Workflow bị bỏ qua vì bộ lọc `paths` làm check kẹt ở "Pending" và chặn merge; một job bị bỏ qua bởi `if:` lại báo "Success" và im lặng cho qua. Vì vậy mọi workflow gate chạy trên **mọi** `pull_request` (không dùng bộ lọc `paths`), không có `if:` ở mức job làm bỏ qua job, và tên job là duy nhất trong cả repo (hai workflow cùng một tên job làm kết quả check mơ hồ). Job chỉ chạy theo lịch (triage) không đặt làm check bắt buộc.
- **Gate trên pull request phải tất định:** chỉ dựa vào đầu ra của công cụ và file baseline/ngoại lệ nằm trong repo. EPSS và KEV đổi hằng ngày nên **không** nằm trong điều kiện chặn của pull request (ADR-0008 của `rexcorp-app`); chúng dùng ở triage hằng tuần.

| Check bắt buộc (tên job) | Workflow | Module | Chặn khi |
|---|---|---|---|
| Secret scan (Gitleaks, baseline) | `secret-scan.yml` | 02 | Có secret mới ngoài baseline |
| SAST (Semgrep CE, chỉ chặn finding mới) | `sast.yml` | 04 | Finding ERROR mới so với commit gốc của pull request |
| SCA (OSV-Scanner, baseline) | `dependency-scan.yml` | 05 | Lỗ hổng chưa nằm trong `osv-scanner.toml` |
| Dockerfile and compose (hadolint, Trivy config, KICS) | `container.yml` | 06 | hadolint từ warning, Trivy config và KICS từ HIGH |
| Image scan (Trivy, baseline) | `container.yml` | 06 | HIGH hoặc CRITICAL đã có bản vá, không nằm trong `.trivyignore.yaml` |
| DAST legacy (ZAP baseline) | `dast.yml` | 07 | Rule `FAIL` mới (không nằm trong `.zap/progress.json`) |
| Requirements ratchet | `requirements-ratchet.yml` | 03 | Requirement kiểm được mà tụt so với `.security/requirements-baseline.txt` |
| Exceptions register | `exceptions-check.yml` | 08 | Ngoại lệ thiếu trường, tự duyệt, quá hạn hoặc vượt trần thời hạn |

Chưa là check bắt buộc: `SBOM (Syft, advisory)` (đang ở giai đoạn advisory) và hai job cùng tên `Node.js` của workflow cũ `e2e-test.yml` và `lint.yml` (tên trùng nhau làm kết quả check mơ hồ; đổi tên rồi mới đặt làm bắt buộc).

### Chỉ chặn finding mới, và chuyển từ cảnh báo sang chặn

- Repo này là repo cũ (brownfield): finding đã có nằm trong baseline (nợ đã biết, có mục backlog và hạn), gate chỉ chặn finding **mới**. Baseline chỉ được tạo lại để **bớt** mục, qua pull request do người phụ trách bảo mật duyệt, không bao giờ để "cho qua" một finding mới.
- Một gate mới đi qua ba giai đoạn: (1) **advisory**: chạy, lưu báo cáo, không chặn, đủ lâu để đo số finding và tỷ lệ báo nhầm; (2) **chặn finding mới**: fail với mọi finding ngoài baseline, chưa phải required check; (3) **required check**: ruleset đòi job xanh mới được merge. Sang giai đoạn sau khi giai đoạn trước chạy ổn trên ít nhất hai tuần pull request thật.

### Ai làm gì

- File policy (file này, `docs/security-exceptions.md`, `.security/`, `osv-scanner.toml`, `.trivyignore.yaml`, `.zap/`, `.semgrep/`, workflow) do người phụ trách bảo mật duyệt qua `CODEOWNERS`. Người sửa file không tự duyệt thay đổi của mình.
- Người triage xem finding mỗi thứ Hai sau lần chạy theo lịch, xếp bậc theo mục "Triage và ưu tiên", giao việc và ghi vào backlog.
- Người chịu rủi ro kinh doanh (CTO) duyệt ngoại lệ P1 và P2.

### Đo lường

| Chỉ số | Cách lấy | Nhịp |
|---|---|---|
| Backlog theo bậc (P1 đến P4) và số mục quá hạn | Bảng triage, backlog | Hằng tuần |
| Thời gian xử lý trung vị theo bậc | Ngày mở và ngày đóng mục backlog | Hằng tháng |
| Tỷ lệ báo nhầm theo rule | Bảng triage của từng control (ví dụ `docs/sast-triage.md`) | Hằng tháng |
| Số ngoại lệ đang hiệu lực và tuổi trung bình | `scripts/check-exceptions.sh` | Hằng tuần |
| Tỷ lệ pull request có check bảo mật đỏ, và thời gian từ đỏ về xanh | `labs/scripts/lab-08-run-durations.sh` hoặc `gh run list` | Hằng tháng |
| Năm metric DORA (lead time, tần suất deploy, thời gian khôi phục, tỷ lệ deploy lỗi, tỷ lệ deploy phải làm lại) trước và sau khi bật gate | Công cụ đo của đội hoặc DORA Quick Check | Hằng quý |

Các chỉ số này để cải tiến quy trình, không phải mục tiêu để đạt: đặt chỉ số làm mục tiêu thì người ta sẽ làm đẹp chỉ số.

## Triage và ưu tiên

Mỗi finding còn mở được xếp vào một **bậc** để biết sửa lúc nào. Thang xếp bậc (ADR-0008 của `rexcorp-app`):

1. **Bối cảnh.** Thành phần có mặt trong sản phẩm chạy thật không (presence)? Đường khai thác có đến được trong cách chạy hiện tại không (reachability)? Hậu quả nếu bị khai thác (consequence)? Không có mặt trong sản phẩm chạy thật (ví dụ chỉ trong `devDependencies`): bậc tối đa P4. Chưa rõ thì coi như đến được và ghi "chưa rõ".
2. **CISA KEV.** Có trong KEV thì tra bảng bên dưới (bốn điểm: KEV, publicly exposed, automatable, technical impact). `Automatable` và `Technical Impact` lấy từ CISA Vulnrichment; `Publicly exposed` là tài sản của mình. Có bằng chứng viết ra và được người duyệt ký rằng đường khai thác không tồn tại ở cấu hình này: hạ một bậc và ghi vào sổ ngoại lệ, không hạ về P4.
3. **EPSS** (CVE không thuộc KEV): ≥ 0.04 và đến được (hoặc chưa rõ), tài sản publicly exposed: **P2**; ≥ 0.04 nhưng chắc chắn không đến được hoặc tài sản không exposed: **P3**; từ 0.008 đến dưới 0.04: **P3**; dưới 0.008: **P4**. Ngưỡng là kết quả của ADR-0008; xem lại mỗi quý.
4. **CVSS.** Ghi kèm phiên bản và nhóm metric (ví dụ "CVSS v4.0 6.9, nhóm BT"; CVSS v3.1 thì ghi "Base"). Dùng để xếp thứ tự **trong cùng bậc** và khi không có EPSS. Không nhân CVSS với EPSS.
5. **Finding không có CVE** (secret, SAST, DAST, cấu hình): secret thật là P1 (runbook `docs/runbooks/leaked-secret.md của `rexcorp-app``); các finding khác dùng cùng bảng bên dưới với `KEV = không`, và `Automatable`, `Technical Impact` do người triage đánh giá, ghi lý do.

Bảng bên dưới tóm tắt Table 1 của BOD 26-04 của CISA (cùng nội dung với cây quyết định "CISA BOD 26-04 Response Model" của CERT/CC SSVC). Khóa học đặt tên bậc: **P1** = 3 ngày, **P2** = 14 ngày, **P3** = 60 ngày (chỉ khi triage hạ bậc và ghi lý do; mặc định theo mức nghiêm trọng là Critical 7, High 14, Medium 30 ngày, Low vào backlog: bảng SLA duy nhất `docs/frameworks/remediation-sla.md` của repo khóa học), **P4** = khi nâng cấp hoặc dựng lại hệ thống; "forensic triage" nghĩa là ngoài việc xử lý còn phải kiểm tra tài sản có bị xâm phạm chưa.

| KEV | Publicly exposed | Automatable | Technical impact: partial | Technical impact: total |
|---|---|---|---|---|
| Không | Không | Không | P4 | P4 |
| Không | Không | Có | P3 | P3 |
| Không | Có | Không | P3 | P2 |
| Không | Có | Có | P2 | P1 |
| Có | Không | Không | P2 | P2 |
| Có | Không | Có | P2 | P1 và forensic triage |
| Có | Có | Không | P2 | P1 và forensic triage |
| Có | Có | Có | P1 | P1 và forensic triage |

BOD 26-04 ràng buộc cơ quan liên bang Mỹ; RexCorp mượn bảng làm điểm xuất phát vì chính FIRST gọi nó là "a model for other organizations to use or adapt". Hạn xử lý này là quy định nội bộ của RexCorp, không phải nghĩa vụ pháp lý.

Triage hằng tuần: sau lần chạy `triage-enrichment.yml`, người triage đọc artifact `kev-epss`, cập nhật bảng triage (`docs/triage/`) và backlog, gom các finding cùng nguyên nhân gốc thành một việc. KEV hoặc EPSS vừa đổi bậc của một mục thì ghi ngày và lý do.

## Ngoại lệ

Quy định đầy đủ và các ngoại lệ đang hiệu lực nằm ở [`docs/security-exceptions.md`](docs/security-exceptions.md). Tóm tắt:

- Ngoại lệ là quyết định chấp nhận rủi ro **có thời hạn, có người chịu trách nhiệm, có người duyệt khác người xin**. Mỗi ngoại lệ có mã `EXC-NNNN`, lý do, biện pháp tạm thời, ngày duyệt, ngày hết hạn và nơi cấu hình công cụ thực thi nó; mã `EXC-NNNN` phải xuất hiện trong chính file cấu hình đó.
- Trần thời hạn từ ngày duyệt: P1 14 ngày, P2 30 ngày, P3 90 ngày, P4 và báo nhầm (FP) 6 tháng. Người duyệt: P1, P2 là CTO; P3 là trưởng nhóm phát triển; P4, FP là người phụ trách bảo mật (trưởng nhóm phát triển nếu chính người phụ trách bảo mật xin).
- Trần này là thời gian tối đa được **chấp nhận rủi ro vượt hạn SLA** của bậc, tính từ ngày duyệt; nó không thay bảng SLA duy nhất (`docs/frameworks/remediation-sla.md` của repo khóa học). Baseline brownfield (ngoại lệ tập thể Critical 30, High 60, còn lại 90 ngày) là một ngoại lệ riêng có ADR và kế hoạch trả nợ, không tính vào trần này.
- Gia hạn là một ngoại lệ mới, không sửa ngày của dòng cũ. Hết hạn mà chưa sửa thì job `Exceptions register` đỏ.
- Cơ chế của từng công cụ (`.gitleaksignore`, `nosemgrep`, `osv-scanner.toml`, `.trivyignore.yaml`, `.zap/rules.tsv`, `.zap/progress.json`) chỉ là nơi thực thi; thời hạn tối đa và người duyệt theo mục này, không theo mặc định của công cụ.

## Control

### Quét secret (module 02)

| Hạng mục | Quy định |
|---|---|
| Công cụ và phiên bản | Gitleaks CLI v8.30.1, image `ghcr.io/gitleaks/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f`, cấu hình mặc định. Bổ sung: secret scanning và push protection của GitHub |
| Chạy ở đâu | CI: job `gitleaks` trong `secret-scan.yml`, quét toàn bộ lịch sử. Server: push protection của GitHub. Đánh giá định kỳ: chạy TruffleHog (`--no-verification`) đối chiếu mỗi quý |
| Điều kiện chặn | Mọi finding **không có trong baseline** làm job fail (exit code 1). Finding đã có trong baseline không chặn |
| Baseline / ngoại lệ | Baseline: `.security/gitleaks-baseline.json`, tạo ngày 2026-10-05 bằng `gitleaks git --redact --report-format json`, gồm 6 finding (không chứa giá trị secret). Chỉ được tạo lại để **bớt** finding, qua pull request do người phụ trách bảo mật duyệt, kèm giải thích từng finding bị bỏ. Không bao giờ tạo lại baseline để "cho qua" một finding mới. Ngoại lệ lẻ dùng `.gitleaksignore` theo cùng quy định với `rexcorp-app` (lý do, người chịu trách nhiệm, hạn tối đa 6 tháng) |
| Bằng chứng | Artifact `gitleaks-sarif` (SARIF 2.1.0, đã redact), giữ 30 ngày; log job |
| Triage và thời hạn xử lý | Finding mới: xử lý theo runbook xử lý secret bị lộ (bản của `rexcorp-app`), thu hồi trong ngày. Finding trong baseline: theo hạn trong `docs/security-backlog.md` |
| Căn cứ framework | Như `rexcorp-app` (ánh xạ của khóa học): NIST SSDF 1.1 PS.1.1, PO.3.1, PO.3.2, PO.3.3, PO.4.1, PO.4.2. Bản đồ pipeline NCCoE: Secret Scanner, phase Develop |

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
| Baseline | `osv-scanner.toml` tạo ngày 2026-10-25 bằng `labs/scripts/lab-05a-osv-baseline.sh`: 194 mục, mỗi mục có `ignoreUntil` theo mức độ (Critical 30 ngày, High 60 ngày, còn lại 90 ngày). Baseline là ngoại lệ có thời hạn cho nợ cũ (không phải SLA; lỗ hổng mới chịu bảng SLA duy nhất của khóa học). Nó là "đã biết, đang xử lý", không phải "đã chấp nhận": xem `docs/security-backlog-dependencies.md` (DEP-001 đến DEP-005) |
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

| Hạng mục | Quy định |
|---|---|
| Công cụ và phiên bản | Như `rexcorp-app`: Trivy v0.76.1, hadolint v2.15.1, KICS v2.1.20, đều pin theo digest. `Dockerfile` pin `node:12-alpine` theo digest `sha256:d4b15b3d…` |
| Chạy ở đâu | Workflow mới `.github/workflows/container.yml`, chạy song song với các workflow cũ: mọi pull request, push lên `main`, và lần chạy theo lịch thứ Hai hằng tuần |
| Điều kiện chặn | Chỉ finding **mới**: HIGH hoặc CRITICAL đã có bản vá và không nằm trong baseline `.trivyignore.yaml`; secret mới trong image; hadolint từ mức warning; Trivy config và KICS từ mức HIGH. Gate "xanh" của image không có nghĩa là an toàn: Alpine 3.15 và Node.js 12 đã hết hỗ trợ, nguồn dữ liệu của Trivy cho Alpine 3.15 không còn cập nhật (Trivy tự cảnh báo) |
| Baseline / ngoại lệ | `.trivyignore.yaml` sinh bằng `labs/scripts/lab-06-trivy-baseline.sh` ngày 2026-10-25: 58 CVE (89 phát hiện) và 1 secret. Hạn: CRITICAL và secret 30 ngày (2026-11-24), HIGH 60 ngày (2026-12-24). Baseline là "đã biết, đang xử lý", không phải "đã chấp nhận": theo `docs/frameworks/remediation-sla.md` (repo khóa học) nó là ngoại lệ tập thể có thời hạn và kế hoạch trả nợ, còn lỗ hổng mới chịu bảng SLA. Chỉ tạo lại baseline để **bớt** mục, qua pull request, do người phụ trách bảo mật duyệt |
| Bằng chứng | Artifact `image-scan-reports` (`trivy-image-all.json`) và `config-scan-reports`, giữ 30 ngày |
| Triage và thời hạn xử lý | Backlog: `docs/security-backlog-containers.md`. Mỗi mục baseline thuộc một việc trong backlog; mục hết hạn mà chưa xong thì người phụ trách bảo mật quyết định gia hạn có lý do hoặc nâng ưu tiên |
| Căn cứ framework | Như `rexcorp-app` (NIST SSDF 1.1: PW.4.4, RV.1.1, RV.2.2, PO.4). Kế hoạch thay base image là phần "plan and implement risk responses" của RV.2.2 |

### DAST: kiểm thử động (module 07)

Triển khai dần: không sửa lỗi cũ trước, chỉ ngăn rule `FAIL` mới xuất hiện.

| Hạng mục | Quy định |
|---|---|
| Công cụ và phiên bản | ZAP 2.17.0, image `ghcr.io/zaproxy/zaproxy:stable@sha256:5ccfff9a411743ab2615136a2edd7416bec9ce41572fa94e935df38c14adb2b6`, `zap-baseline.py`, chạy bằng `scripts/dast-scan.sh`. Ứng dụng và MongoDB (`mongo:4.4@sha256:4be76f67…`) chạy bằng `compose.dast.yaml` trong mạng `rxdast-net` (`internal: true`, không publish cổng) |
| Chạy ở đâu | Job `zap` trong `.github/workflows/dast.yml`: `pull_request` và theo lịch thứ Hai hằng tuần. Chỉ quét ứng dụng do job dựng. Ứng dụng cố ý chứa lỗ hổng và chạy Node 12 đã hết hỗ trợ: không được chạy ra ngoài mạng nội bộ |
| Điều kiện chặn | Rule đặt `FAIL` trong `.zap/rules.tsv` mà **không** nằm trong `.zap/progress.json` (state `inprogress`): job fail. Rule `WARN` không chặn. Giới hạn: `progress.json` khớp theo mã rule chứ không theo URL, nên một trang mới vi phạm rule đã biết không bị chặn |
| Baseline / ngoại lệ | `.zap/progress.json`: mỗi mục có `link` tới mã trong `docs/security-backlog.lab-07.md`. Chỉ thêm mục khi đã có mã backlog, người phụ trách và hạn; chỉ xóa mục khi lỗi đã sửa. Người xin không tự duyệt |
| Bằng chứng | Artifact `zap-report-legacy` (HTML, JSON, Markdown), giữ 30 ngày |
| Triage và thời hạn xử lý | `FAIL` mới: sửa trong pull request gây ra nó, hoặc (nếu là rule chưa từng thấy vì spider đi tới trang mới, như DAST-104) đưa vào backlog trong 3 ngày làm việc. `WARN`: triage hằng tuần |
| Căn cứ framework | Ánh xạ của khóa học vào NIST SSDF 1.1: PW.8.1 (Example 1: kiểm thử trong môi trường sandbox), PW.8.2 (Example 2, 3), PO.4.1, PO.4.2. Bản đồ pipeline NCCoE: DAST System thuộc phase Test |

### Triage và ngoại lệ (module 08)

| Hạng mục | Quy định |
|---|---|
| Công cụ và phiên bản | `scripts/kev-epss.sh` (bash, curl, jq; ghép CISA KEV và EPSS của FIRST) và `scripts/check-exceptions.sh` (bash, awk), workflow `triage-enrichment.yml` và `exceptions-check.yml`. KEV lấy từ `cisagov/kev-data` (bản sao chính thức của CISA, giấy phép CC0); EPSS lấy từ file CSV hằng ngày của FIRST (`epss_scores-current.csv.gz`). OSV-Scanner v2.6.0 pin digest như `dependency-scan.yml` (với `--config` rỗng để thấy cả lỗ hổng đã nằm trong baseline) |
| Chạy ở đâu | `Exceptions register`: mọi pull request, push lên `main`, và thứ Hai hằng tuần. `triage-enrichment.yml`: chỉ theo lịch (thứ Hai 04:41 UTC) và chạy tay; không chạy trên pull request. Triage bằng tay mỗi thứ Hai sau đó |
| Điều kiện chặn | `Exceptions register` fail khi có ngoại lệ đang hiệu lực mà thiếu trường, người xin cũng là người duyệt, quá hạn, vượt trần thời hạn của bậc, hoặc trỏ tới file không có thật. `triage-enrichment.yml` (không phải required check) fail khi có CVE trong KEV: tín hiệu để xếp lại bậc ngay |
| Baseline / ngoại lệ | Sổ `docs/security-exceptions.md`; mỗi ngoại lệ có mã `EXC-NNNN`. Người phụ trách bảo mật duyệt qua `CODEOWNERS`; CTO duyệt P1 và P2. Hiện có 3 ngoại lệ (EXC-0001 đến EXC-0003). Baseline không phải ngoại lệ (xem sổ) |
| Bằng chứng | Artifact `kev-epss` (TSV kèm ngày chạy, phiên bản KEV và mô hình EPSS), giữ 30 ngày; bảng triage `docs/triage/2026-10-07-triage.md` (10 finding); log job `Exceptions register` |
| Triage và thời hạn xử lý | Bậc P1 3 ngày, P2 14 ngày, P3 60 ngày (hạ bậc có lý do ghi trong triage), P4 khi nâng cấp. Mặc định theo mức nghiêm trọng: Critical 7, High 14, Medium 30 ngày, Low vào backlog (bảng SLA duy nhất của khóa học). Người triage xem hằng tuần; ngoại lệ còn dưới 14 ngày là WARN trong job, xử lý trong tuần |
| Căn cứ framework | Ánh xạ của khóa học vào NIST SSDF 1.1: PO.4.1 và PO.4.2 (tiêu chí kiểm tra, tự động ra quyết định, xem lại định kỳ), RV.1.1 (theo dõi lỗ hổng mới), RV.2.1 và RV.2.2 (phân tích rủi ro từng lỗ hổng, quyết định sửa hay chấp nhận). FIRST CVSS v4.0, EPSS và CISA KEV (bảng BOD 26-04) cho thang xếp bậc. OWASP SAMM I-SB-3-A và I-DM-2-A; Microsoft SDL 1.3 và 1.4 (bug bar, ngoại lệ có thời hạn). Bản đồ pipeline NCCoE: control gate; metric đo ở dimension Continuous Improvements, Security, and Monitoring |

### Bảo vệ chính pipeline CI (module 09)

Chưa áp dụng. Đã biết: các workflow cũ pin action theo tag và không khai báo `permissions`. zizmor 1.31.1 (`--offline`, ngày 2026-10-05) báo 12 finding, 4 bị ẩn theo mặc định, còn lại 2 medium và 6 high.

### Toàn vẹn artifact: ký và provenance (module 10)

Chưa áp dụng.

## Lịch sử thay đổi

| Ngày | Người sửa | Thay đổi |
|---|---|---|
| 2026-10-05 | Kỹ sư DevOps phụ trách bảo mật | Tạo file; thêm mục "Quét secret" với baseline 6 finding (Lab 02) |
| 2026-10-06 | Kỹ sư DevOps phụ trách bảo mật | Thêm mục "Yêu cầu bảo mật" và ratchet (Lab 03) |
| 2026-10-06 | Kỹ sư DevOps phụ trách bảo mật | Thêm mục "SAST" (Lab 04) |
| 2026-10-06 | Kỹ sư DevOps phụ trách bảo mật | Thêm mục "Dependency, SCA và SBOM" (Lab 05a, 05b) |
| 2026-10-06 | Kỹ sư DevOps phụ trách bảo mật | Thêm mục "Container image và cấu hình" (Lab 06) |
| 2026-10-07 | Kỹ sư DevOps phụ trách bảo mật | Thêm mục "DAST" (Lab 07) |
| 2026-10-07 | Kỹ sư DevOps phụ trách bảo mật | Hoàn thiện "Quy tắc chung"; thêm mục "Triage và ưu tiên", "Ngoại lệ" và control "Triage và ngoại lệ"; đặt 12 check bắt buộc (Lab 08, ADR-0008) |
