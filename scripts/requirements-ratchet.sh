#!/usr/bin/env bash
# "Ratchet" (bánh cóc) cho requirement ASVS trên repo brownfield: số lần xuất hiện của mẫu lỗi
# KHÔNG được tăng so với .security/requirements-baseline.txt. Có thể giảm; khi giảm, hạ baseline.
#
#   scripts/requirements-ratchet.sh            kiểm tra (exit 1 nếu có mẫu tăng)
#   scripts/requirements-ratchet.sh --print    in số đếm hiện tại theo định dạng baseline
#
# Giới hạn (cố ý nêu rõ): grep đếm dòng, không hiểu cú pháp. Dòng nằm trong khối /* ... */ vẫn bị đếm,
# và đổi cách viết (ví dụ ["ev"+"al"]) là qua mặt được. Module 04 thay bước này bằng SAST.
# Giấy phép: Apache-2.0 như rexcorp-legacy.

set -euo pipefail
cd "$(dirname "$0")/.."
BASELINE=".security/requirements-baseline.txt"

# Mỗi mục: ID|requirement ASVS v5.0.0|đường dẫn|mẫu grep -E
CHECKS=(
  'LEG-1.3.2|v5.0.0-1.3.2 tránh eval()|app server.js config|(^|[^[:alnum:]_.])eval\('
  'LEG-1.2.4|v5.0.0-1.2.4 truy vấn tham số hóa|app|\$where'
  'LEG-8.2.2|v5.0.0-8.2.2 quyền theo dữ liệu (userId lấy từ URL)|app|= req\.params'
  'LEG-13.3.1|v5.0.0-13.3.1 không có secret trong mã nguồn|config|(cookieSecret|cryptoKey):[[:space:]]*"'
)

count() { # count <đường dẫn...> -- <mẫu>; đếm dòng khớp, bỏ dòng chú thích bắt đầu bằng //, * hoặc /*
  local pattern="${*: -1}"; local paths=("${@:1:$#-1}")
  { grep -rnE "$pattern" "${paths[@]}" 2>/dev/null || true; } \
    | { grep -vE ':[0-9]+:[[:space:]]*(//|\*|/\*)' || true; } | wc -l | tr -d ' '
}

if [ "${1:-}" = "--print" ]; then
  for c in "${CHECKS[@]}"; do
    IFS='|' read -r id _ paths pattern <<<"$c"
    # shellcheck disable=SC2086
    echo "$id=$(count $paths "$pattern")"
  done
  exit 0
fi

[ -f "$BASELINE" ] || { echo "Lỗi: thiếu $BASELINE (tạo bằng: $0 --print > $BASELINE)" >&2; exit 2; }

status=0
for c in "${CHECKS[@]}"; do
  IFS='|' read -r id label paths pattern <<<"$c"
  # shellcheck disable=SC2086
  now=$(count $paths "$pattern")
  base=$(grep -E "^$id=" "$BASELINE" | cut -d= -f2)
  if [ "$now" -gt "$base" ]; then
    printf 'FAIL  %-11s %s: %s (baseline %s) — thêm mẫu lỗi MỚI\n' "$id" "$label" "$now" "$base"; status=1
  elif [ "$now" -lt "$base" ]; then
    printf 'DOWN  %-11s %s: %s (baseline %s) — đã giảm, hạ baseline qua pull request\n' "$id" "$label" "$now" "$base"
  else
    printf 'OK    %-11s %s: %s (baseline %s)\n' "$id" "$label" "$now" "$base"
  fi
done
exit "$status"
