#!/usr/bin/env bash
# Kiểm tra sổ ngoại lệ (docs/security-exceptions.md) theo quy định trong SECURITY-GATE.md. Chạy ở gốc repo.
#
#   scripts/check-exceptions.sh [SỔ_NGOẠI_LỆ]        (mặc định: docs/security-exceptions.md)
#
# Mỗi dòng ngoại lệ của sổ là một hàng bảng Markdown bắt đầu bằng "| EXC-" với 11 cột:
#   ID | Control | Finding | Bậc | Lý do và biện pháp tạm thời | Người xin | Người duyệt | Ngày duyệt | Hết hạn | Nơi cấu hình | Trạng thái
# Chỉ kiểm hàng có Trạng thái "Đang hiệu lực". Các kiểm tra, mỗi kiểm tra FAIL làm script thoát với mã 1:
#   1. Đủ cả 11 trường, ngày đúng dạng YYYY-MM-DD.
#   2. Bậc thuộc P1, P2, P3, P4 hoặc FP (báo nhầm).
#   3. Người duyệt khác người xin.
#   4. Chưa quá hạn. Còn dưới 14 ngày thì WARN (nhắc xử lý hoặc gia hạn qua quy trình duyệt lại).
#   5. Ngày duyệt không ở tương lai; thời gian từ ngày duyệt tới hạn không vượt trần của bậc: P1 14 ngày, P2 30, P3 90, P4 và FP 183 (6 tháng).
#   6. "Nơi cấu hình" là file có thật; nếu file không chứa mã EXC-... thì WARN (công cụ không nhận ra ngoại lệ này).
# Thêm một kiểm tra ngược (WARN): mục ngoại lệ trong file cấu hình của công cụ không nhắc tới mã EXC- và cũng không ghi là
# "Baseline" (nợ cũ của repo brownfield, xử lý bằng backlog chứ không bằng sổ ngoại lệ).
#
# Biến môi trường: TODAY=YYYY-MM-DD (mặc định: ngày hôm nay theo UTC) để kiểm thử.
#                  ADVISORY=1: giai đoạn 1 của triển khai dần. Vẫn in đủ FAIL/WARN nhưng luôn thoát 0 (không chặn), để đo số vi phạm trước khi chặn.
# Trần thời hạn và mốc nhắc là đề xuất của khóa học (ADR-0008), không phải chuẩn; sửa trong script nếu policy của bạn khác.
# Chỉ cần bash, awk, grep. Giấy phép: MIT (xem LICENSE-CODE của repo khóa học).

set -uo pipefail

REGISTER="${1:-docs/security-exceptions.md}"
TODAY="${TODAY:-$(date -u +%Y-%m-%d)}"
[ -r "$REGISTER" ] || { echo "Lỗi: không đọc được $REGISTER (chạy ở gốc repo, hoặc truyền đường dẫn)" >&2; exit 2; }
case "$TODAY" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;; *) echo "Lỗi: TODAY phải có dạng YYYY-MM-DD" >&2; exit 2 ;; esac

fail=0; warn=0; pass=0; active=0
report() { # report LEVEL ID message
  case "$1" in FAIL) fail=$((fail + 1)) ;; WARN) warn=$((warn + 1)) ;; PASS) pass=$((pass + 1)) ;; esac
  printf '%-5s %s: %s\n' "$1" "$2" "$3"
}

# Số ngày kể từ 1970-01-01 của một ngày YYYY-MM-DD (thuật toán days_from_civil), để trừ ngày không cần date -d.
days() { awk -v d="$1" 'BEGIN {
  split(d, a, "-"); y = a[1] + 0; m = a[2] + 0; dd = a[3] + 0
  if (m <= 2) y -= 1
  era = int(y / 400); yoe = y - era * 400
  doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + dd - 1
  doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
  print era * 146097 + doe - 719468 }'; }
valid_date() { case "$1" in [0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]) return 0 ;; *) return 1 ;; esac; }
trim() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^`//' -e 's/`$//'; }

today_n="$(days "$TODAY")"

while IFS= read -r line; do
  case "$line" in "| EXC-"*) ;; *) continue ;; esac
  IFS='|' read -r _ id control finding klass reason owner approver approved expires where status _rest <<< "$line"
  id="$(trim "$id")"; klass="$(trim "$klass")"; owner="$(trim "$owner")"; approver="$(trim "$approver")"
  approved="$(trim "$approved")"; expires="$(trim "$expires")"; where="$(trim "$where")"; status="$(trim "$status")"
  [ "$status" = "Đang hiệu lực" ] || continue
  active=$((active + 1))
  ok=1

  empty=""
  for pair in "Control:$control" "Finding:$finding" "Bậc:$klass" "Lý do:$reason" "Người xin:$owner" "Người duyệt:$approver" "Nơi cấu hình:$where"; do
    [ -n "$(trim "${pair#*:}")" ] || empty="$empty ${pair%%:*}"
  done
  if [ -n "$empty" ]; then report FAIL "$id" "thiếu trường:$empty"; continue; fi
  if ! valid_date "$approved" || ! valid_date "$expires"; then report FAIL "$id" "ngày duyệt/hết hạn phải có dạng YYYY-MM-DD (đang là '$approved' / '$expires')"; continue; fi

  case "$klass" in P1) cap=14 ;; P2) cap=30 ;; P3) cap=90 ;; P4|FP) cap=183 ;; *) report FAIL "$id" "bậc '$klass' không thuộc P1, P2, P3, P4, FP"; continue ;; esac

  if [ "$owner" = "$approver" ]; then report FAIL "$id" "người xin và người duyệt cùng là '$owner'"; ok=0; fi

  if [ "$(days "$approved")" -gt "$today_n" ]; then report FAIL "$id" "ngày duyệt $approved ở tương lai"; ok=0; fi
  left=$(( $(days "$expires") - today_n ))
  span=$(( $(days "$expires") - $(days "$approved") ))
  if [ "$left" -lt 0 ]; then report FAIL "$id" "đã quá hạn $((-left)) ngày (hết hạn $expires): sửa hẳn, hoặc duyệt lại từ đầu"; ok=0
  elif [ "$left" -lt 14 ]; then report WARN "$id" "còn $left ngày (hết hạn $expires): sửa hẳn, hoặc đưa đi duyệt lại"; ok=0; fi
  if [ "$span" -gt "$cap" ]; then report FAIL "$id" "thời hạn $span ngày vượt trần $cap ngày của bậc $klass"; ok=0; fi

  if [ ! -f "$where" ]; then report FAIL "$id" "nơi cấu hình '$where' không phải file có thật"; ok=0
  elif ! grep -qF "$id" "$where"; then report WARN "$id" "file '$where' không nhắc mã $id: công cụ chưa biết ngoại lệ này"; ok=0; fi

  [ "$ok" = 1 ] && report PASS "$id" "hợp lệ, còn $left ngày, bậc $klass, duyệt bởi $approver"
done < "$REGISTER"

# Kiểm tra ngược: mục ngoại lệ trong file cấu hình của công cụ mà không có mã EXC- và không phải baseline.
unlisted=0
count_unlisted() { # count_unlisted FILE LABEL PATTERN_ENTRY  (đếm mục vào, trừ mục nhắc EXC- hoặc Baseline)
  local f="$1" label="$2" n
  [ -f "$f" ] || return 0
  n="$(awk -v mode="$3" '
    mode == "gitleaks" { if ($0 ~ /^#/) { ctx = ctx $0 "\n" } else if ($0 ~ /[^[:space:]]/) { if (ctx !~ /EXC-|Baseline/) bad++; ctx = "" } else { } }
    mode == "osv"      { if ($0 ~ /^\[\[IgnoredVulns\]\]/) { inb = 1; next } if (inb && $0 ~ /^reason[[:space:]]*=/) { if ($0 !~ /EXC-|Baseline/) bad++; inb = 0 } }
    mode == "trivy"    { if ($0 ~ /^[[:space:]]*-[[:space:]]*id:/) { inb = 1; blk = "" } if (inb) blk = blk $0 "\n"; if (inb && $0 ~ /expired_at/) { if (blk !~ /EXC-|Baseline/) bad++; inb = 0 } }
    mode == "zap"      { if ($0 !~ /^#/ && $2 == "IGNORE" && $0 !~ /EXC-|Baseline/) bad++ }
    END { print bad + 0 }' "$f")"
  if [ "$n" -gt 0 ]; then report WARN "(ngược)" "$label có $n mục ngoại lệ không nhắc mã EXC- và không phải baseline"; unlisted=$((unlisted + n)); fi
}
count_unlisted .gitleaksignore ".gitleaksignore" gitleaks
count_unlisted osv-scanner.toml "osv-scanner.toml" osv
count_unlisted .trivyignore.yaml ".trivyignore.yaml" trivy
count_unlisted .zap/rules.tsv ".zap/rules.tsv (IGNORE)" zap
nosem="$(grep -rn --include='*.js' --include='*.ts' --include='*.py' 'nosemgrep' . 2>/dev/null | grep -v -E '^\./(node_modules|\.git)/' | grep -v -E 'EXC-|Baseline' | wc -l | tr -d ' ')"
[ "$nosem" -gt 0 ] && report WARN "(ngược)" "$nosem dòng nosemgrep trong mã nguồn không nhắc mã EXC-"

echo
echo "Tổng kết ($TODAY): $active ngoại lệ đang hiệu lực; $pass PASS, $warn WARN, $fail FAIL"
if [ "${ADVISORY:-0}" = 1 ]; then
  echo "ADVISORY=1: chỉ báo cáo, không chặn ($fail FAIL sẽ chặn ở giai đoạn 2)"
  exit 0
fi
[ "$fail" -eq 0 ]
