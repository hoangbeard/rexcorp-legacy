#!/usr/bin/env bash
# Kiểm tra bằng máy phần "SBOM" của SCVS Level 1 (OWASP Software Component Verification Standard, family V2)
# trên một SBOM dạng CycloneDX JSON hoặc SPDX JSON của dự án npm. Dùng ở Lab 05b.
#
#   labs/scripts/lab-05b-scvs-l1-check.sh SBOM.json package-lock.json [--include-dev]
#
# Các yêu cầu kiểm được bằng máy:
#   2.1  SBOM có định dạng có cấu trúc, đọc được bằng máy
#   2.3  mỗi SBOM có mã định danh duy nhất (CycloneDX: serialNumber; SPDX: documentNamespace)
#   2.7  SBOM có dấu thời gian
#   2.9  danh sách component đầy đủ và chính xác: so với package-lock.json (xem ghi chú bên dưới)
#   2.12 định danh component lấy từ hệ sinh thái gốc (npm: purl bắt đầu bằng pkg:npm/)
#   2.14 component có thông tin giấy phép
# Yêu cầu 2.8 (SBOM được phân tích rủi ro) kiểm bằng cách chạy một scanner trên chính SBOM: xem bài lab.
#
# Ghi chú về 2.9: script so tập "tên@phiên bản" duy nhất của các package npm trong SBOM với package-lock.json,
# bỏ package gốc (chính dự án). Mặc định lockfile chỉ tính package production, vì Syft và Trivy mặc định
# không đưa devDependencies vào SBOM; thêm --include-dev nếu SBOM của bạn có cả dev.
#
# Exit 0 nếu không có FAIL, 1 nếu có. Cần jq 1.6 trở lên. Chỉ đọc file, không gọi mạng.
# Giấy phép: MIT (xem LICENSE-CODE của repo khóa học).

set -uo pipefail

usage() { echo "Cách dùng: $0 SBOM.json package-lock.json [--include-dev]" >&2; exit 2; }
[ $# -ge 2 ] || usage
SBOM="$1"; LOCK="$2"; INCLUDE_DEV=false
[ "${3:-}" = "--include-dev" ] && INCLUDE_DEV=true
[ -r "$SBOM" ] && [ -r "$LOCK" ] || usage
command -v jq >/dev/null 2>&1 || { echo "Lỗi: không tìm thấy jq" >&2; exit 1; }

fails=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; fails=$((fails + 1)); }

if jq -e '.bomFormat == "CycloneDX"' "$SBOM" >/dev/null 2>&1; then
  FORMAT="CycloneDX $(jq -r '.specVersion' "$SBOM")"
  ID_FIELD='serialNumber'; ID_VALUE="$(jq -r '.serialNumber // empty' "$SBOM")"
  TS_FIELD='metadata.timestamp'; TS_VALUE="$(jq -r '.metadata.timestamp // empty' "$SBOM")"
  PURLS="$(jq -r '.components[]? | select(.purl != null) | .purl' "$SBOM")"
  LIB_TOTAL="$(jq '[.components[]? | select(.purl != null and (.purl | startswith("pkg:npm/")))] | length' "$SBOM")"
  LIB_NOPURL="$(jq '[.components[]? | select(.type == "library" and .purl == null)] | length' "$SBOM")"
  LIC_OK="$(jq '[.components[]? | select(.purl != null and (.purl | startswith("pkg:npm/"))) | select((.licenses // []) | length > 0)] | length' "$SBOM")"
elif jq -e '.spdxVersion != null' "$SBOM" >/dev/null 2>&1; then
  FORMAT="$(jq -r '.spdxVersion' "$SBOM")"
  ID_FIELD='documentNamespace'; ID_VALUE="$(jq -r '.documentNamespace // empty' "$SBOM")"
  TS_FIELD='creationInfo.created'; TS_VALUE="$(jq -r '.creationInfo.created // empty' "$SBOM")"
  PURLS="$(jq -r '.packages[]? | .externalRefs[]? | select(.referenceType == "purl") | .referenceLocator' "$SBOM")"
  LIB_TOTAL="$(jq '[.packages[]? | select(any(.externalRefs[]?; .referenceType == "purl" and (.referenceLocator | startswith("pkg:npm/"))))] | length' "$SBOM")"
  LIB_NOPURL="$(jq '[.packages[]? | select(.primaryPackagePurpose == "LIBRARY" and (any(.externalRefs[]?; .referenceType == "purl") | not))] | length' "$SBOM")"
  LIC_OK="$(jq '[.packages[]? | select(any(.externalRefs[]?; .referenceType == "purl" and (.referenceLocator | startswith("pkg:npm/")))) | select(.licenseDeclared != null and .licenseDeclared != "NOASSERTION")] | length' "$SBOM")"
else
  fail "2.1  không nhận ra định dạng (cần CycloneDX JSON hoặc SPDX JSON): $SBOM"
  exit 1
fi

pass "2.1  định dạng có cấu trúc, đọc được bằng máy: $FORMAT"

if [ -n "$ID_VALUE" ]; then pass "2.3  có mã định danh duy nhất ($ID_FIELD = $ID_VALUE)"; else fail "2.3  thiếu $ID_FIELD"; fi
if [ -n "$TS_VALUE" ]; then pass "2.7  có dấu thời gian ($TS_FIELD = $TS_VALUE)"; else fail "2.7  thiếu $TS_FIELD"; fi

# 2.9: tập tên@phiên bản duy nhất của package npm, SBOM so với lockfile (bỏ package gốc).
ROOT="$(jq -r '.packages[""] | "\(.name // "")@\(.version // "")"' "$LOCK")"
SBOM_SET="$(printf '%s\n' "$PURLS" | grep '^pkg:npm/' | sed -e 's#^pkg:npm/##' -e 's#%40#@#g' -e 's#?.*$##' | sort -u | grep -vxF "$ROOT" || true)"
LOCK_SET="$(jq -r --argjson dev "$INCLUDE_DEV" '
  .packages | to_entries[] | select(.key != "") | select($dev or (.value.dev != true))
  | "\(.key | split("node_modules/") | last)@\(.value.version)"' "$LOCK" | sort -u)"
ONLY_SBOM="$(comm -23 <(printf '%s\n' "$SBOM_SET") <(printf '%s\n' "$LOCK_SET") | sed '/^$/d')"
ONLY_LOCK="$(comm -13 <(printf '%s\n' "$SBOM_SET") <(printf '%s\n' "$LOCK_SET") | sed '/^$/d')"
N_SBOM="$(printf '%s\n' "$SBOM_SET" | sed '/^$/d' | wc -l | tr -d ' ')"
N_LOCK="$(printf '%s\n' "$LOCK_SET" | sed '/^$/d' | wc -l | tr -d ' ')"
if [ -z "$ONLY_SBOM" ] && [ -z "$ONLY_LOCK" ]; then
  pass "2.9  danh sách component khớp lockfile: $N_SBOM package npm duy nhất (bỏ package gốc $ROOT)"
else
  fail "2.9  SBOM có $N_SBOM package npm duy nhất, lockfile có $N_LOCK; chỉ có trong SBOM: $(printf '%s\n' "$ONLY_SBOM" | sed '/^$/d' | wc -l | tr -d ' '), chỉ có trong lockfile: $(printf '%s\n' "$ONLY_LOCK" | sed '/^$/d' | wc -l | tr -d ' ')"
  [ -n "$ONLY_SBOM" ] && printf '        chỉ có trong SBOM:     %s\n' "$(printf '%s\n' "$ONLY_SBOM" | head -5 | paste -sd' ' -)"
  [ -n "$ONLY_LOCK" ] && printf '        chỉ có trong lockfile: %s\n' "$(printf '%s\n' "$ONLY_LOCK" | head -5 | paste -sd' ' -)"
fi

if [ "$LIB_NOPURL" -eq 0 ] && [ "$LIB_TOTAL" -gt 0 ]; then
  pass "2.12 $LIB_TOTAL component npm đều có purl dạng pkg:npm/…, không có library nào thiếu purl"
else
  fail "2.12 có $LIB_NOPURL library không có purl, hoặc không có component npm nào"
fi

if [ "$LIB_TOTAL" -gt 0 ] && [ "$LIC_OK" -eq "$LIB_TOTAL" ]; then
  pass "2.14 $LIC_OK/$LIB_TOTAL component npm có thông tin giấy phép"
else
  fail "2.14 chỉ $LIC_OK/$LIB_TOTAL component npm có thông tin giấy phép"
fi

[ "$fails" -eq 0 ] || exit 1
