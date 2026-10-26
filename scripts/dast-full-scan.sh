#!/usr/bin/env bash
# Quét ĐẦY ĐỦ (có quét chủ động) rexcorp-legacy bằng ZAP, trên bản sao tự dựng trong mạng Docker nội bộ.
#
#   scripts/dast-full-scan.sh                  # tối đa 40 phút, ghi báo cáo vào ./zap-out/full
#   DAST_FULL_MAX_MIN=15 scripts/dast-full-scan.sh
#
# Đây là bước TẤN CÔNG: chỉ chạy trên thứ bạn tự dựng (ứng dụng cố ý có lỗ hổng, không publish cổng,
# không có đường ra Internet). Không bao giờ trỏ nó vào hệ thống dùng chung hoặc production.
#
# Vì sao có "đồng hồ canh" riêng: cờ -T của zap-full-scan.py KHÔNG giới hạn thời gian quét chủ động
# (xem Lab 07, Bước 12). Thứ duy nhất chắc chắn dừng được lần quét là dừng container ZAP. Khi hết giờ script
# dừng container, in "HẾT GIỜ" và exit 124; báo cáo ZAP có thể chưa được ghi.
#
# Dùng project và mạng riêng (rxfull-*), nên không đụng scripts/dast-scan.sh và không để lại gì khi kết thúc.
# Exit code: như ZAP (0, 1, 2, 3), hoặc 124 khi hết giờ.
# Giấy phép: MIT (xem LICENSE-CODE của repo khóa học).

set -euo pipefail

ZAP_IMAGE="ghcr.io/zaproxy/zaproxy:stable@sha256:5ccfff9a411743ab2615136a2edd7416bec9ce41572fa94e935df38c14adb2b6"
MAX_MIN="${DAST_FULL_MAX_MIN:-40}"
SPIDER_MIN="${DAST_FULL_SPIDER_MIN:-2}"
RUN_ID="${DAST_RUN_ID:-$$}"
PROJECT="rxfull-$RUN_ID"
export DAST_NET="rxfull-net-$RUN_ID"
COMPOSE=(docker compose -p "$PROJECT" -f compose.dast.yaml)
OUT="${DAST_OUT:-$PWD/zap-out/full}"
cid=""

cleanup() {
  [ -z "$cid" ] || docker rm -f "$cid" >/dev/null 2>&1 || true
  "${COMPOSE[@]}" down --volumes --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

command -v docker >/dev/null 2>&1 || { echo "Lỗi: không tìm thấy docker" >&2; exit 3; }
[ -f compose.dast.yaml ] && [ -f .zap/rules.tsv ] || { echo "Lỗi: chạy từ gốc repo (cần compose.dast.yaml và .zap/rules.tsv)" >&2; exit 3; }

echo "== Dựng rexcorp-legacy + MongoDB (project $PROJECT, mạng $DAST_NET)"
"${COMPOSE[@]}" up --detach --build --quiet-pull >/dev/null 2>&1
ready=""
for _ in $(seq 1 45); do
  if "${COMPOSE[@]}" exec -T web wget -q -O /dev/null http://127.0.0.1:4000/login 2>/dev/null; then ready=1; break; fi
  sleep 2
done
[ -n "$ready" ] || { echo "Lỗi: ứng dụng không trả lời" >&2; "${COMPOSE[@]}" logs web >&2; exit 3; }

# Báo cáo nằm trong zap-out/ (đã có trong .gitignore), nên git status vẫn sạch sau khi chạy.
[ -n "${DAST_OUT:-}" ] || rm -rf "$OUT"
[ ! -d "$OUT" ] || [ -z "$(ls -A "$OUT")" ] || { echo "Lỗi: $OUT không rỗng" >&2; exit 3; }
mkdir -p "$OUT"
chmod a+rwx "$OUT"
cp .zap/rules.tsv "$OUT/"

# -T chỉ đặt thời gian chờ ZAP khởi động và quét thụ động, không giới hạn quét chủ động (Lab 07, Bước 12): chỉ truyền khi bạn đặt DAST_FULL_T_MIN.
T_ARGS=()
[ -z "${DAST_FULL_T_MIN:-}" ] || T_ARGS=(-T "$DAST_FULL_T_MIN")
cid="$(docker create --network "$DAST_NET" -v "$OUT":/zap/wrk:rw "$ZAP_IMAGE" \
  zap-full-scan.py -t http://legacy:4000 -c rules.tsv -m "$SPIDER_MIN" ${T_ARGS[@]+"${T_ARGS[@]}"} \
  -J full.json -r full.html -w full.md -s)"
docker network connect bridge "$cid"   # chỉ để ZAP tải add-on lúc khởi động

# Đồng hồ canh: sau MAX_MIN phút thì dừng container ZAP.
flag="$(mktemp)"
( sleep $((MAX_MIN * 60)); echo timeout > "$flag"; docker stop -t 10 "$cid" >/dev/null 2>&1 || true ) &
watcher=$!

start=$(date +%s)
rc=0
echo "== ZAP full scan (spider ${SPIDER_MIN} phút, rồi quét chủ động; tối đa ${MAX_MIN} phút)"
docker start --attach "$cid" || rc=$?
kill "$watcher" 2>/dev/null || true
wait "$watcher" 2>/dev/null || true
elapsed=$(( $(date +%s) - start ))
if [ -s "$flag" ]; then
  echo "HẾT GIỜ sau ${elapsed} giây: đã dừng container ZAP (exit 124). Báo cáo có thể chưa đầy đủ."
  rc=124
else
  echo "ZAP kết thúc sau ${elapsed} giây, exit $rc (0 sạch, 1 có FAIL, 2 chỉ WARN, 3 lỗi công cụ)"
fi
rm -f "$flag"
exit "$rc"
