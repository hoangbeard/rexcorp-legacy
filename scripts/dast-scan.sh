#!/usr/bin/env bash
# Quét DAST rexcorp-legacy bằng ZAP baseline trong mạng Docker nội bộ.
#
#   scripts/dast-scan.sh                     # quét ẩn danh (không đăng nhập)
#   DAST_AUTH_USER=user1 DAST_AUTH_PASSWORD='User1_123' scripts/dast-scan.sh   # quét có đăng nhập
#
# Ứng dụng (Node 12) và MongoDB nằm trong mạng `rxdast-net` với `internal: true`, không publish cổng nào ra host,
# không có đường ra Internet: ứng dụng cố ý chứa lỗ hổng (SSRF, RCE…) nên không được để nó nói chuyện với bên ngoài.
# Container ZAP được nối thêm vào mạng `bridge` chỉ để tải add-on quét thụ động lúc khởi động.
#
# Gate "chỉ chặn finding mới": .zap/progress.json liệt kê các rule đã biết và đang xử lý (state "inprogress").
# ZAP in chúng là FAIL-IN_PROGRESS và KHÔNG tính vào exit code; một rule FAIL mới thì exit 1.
# Giới hạn: progress.json khớp theo mã rule, không theo URL; một trang mới vi phạm một rule đã biết sẽ không bị chặn.
#
# DAST_VERBOSE=1 in đầy đủ (mọi rule PASS, "Total of N URLs", URL ví dụ của từng alert); mặc định rút gọn bằng `-s`.
# Exit code của script: 0 = không có FAIL mới (WARN không chặn), 1 = có FAIL mới (gate đỏ), 3 = lỗi công cụ.
# Đặt DAST_FAIL_ON_WARN=1 nếu muốn WARN cũng làm script exit 2 (ZAP gốc luôn exit 2 khi chỉ có WARN).
# Giấy phép: MIT (xem LICENSE-CODE của repo khóa học).

set -euo pipefail

ZAP_IMAGE="ghcr.io/zaproxy/zaproxy:stable@sha256:5ccfff9a411743ab2615136a2edd7416bec9ce41572fa94e935df38c14adb2b6"
CURL_IMAGE="curlimages/curl:8.23.0@sha256:11e64e28c5f58c8d93ee95fcf22ac055f48b0bc440e0ce7d8013bbb5ad6aa8ac"
PROJECT="rxdast"
NETWORK="rxdast-net"
COMPOSE=(docker compose -p "$PROJECT" -f compose.dast.yaml)
OUT="${DAST_OUT:-$PWD/zap-out}"

cleanup() { "${COMPOSE[@]}" down --volumes --remove-orphans >/dev/null 2>&1 || true; }
trap cleanup EXIT

command -v docker >/dev/null 2>&1 || { echo "Lỗi: không tìm thấy docker" >&2; exit 3; }
[ -f compose.dast.yaml ] && [ -f .zap/rules.tsv ] && [ -f .zap/progress.json ] || {
  echo "Lỗi: chạy từ gốc repo (cần compose.dast.yaml, .zap/rules.tsv, .zap/progress.json)" >&2; exit 3; }

echo "== Dựng rexcorp-legacy + MongoDB (mạng nội bộ $NETWORK)"
"${COMPOSE[@]}" up --detach --build --quiet-pull >/dev/null 2>&1

# Chờ ứng dụng trả lời trên cổng 4000 (bên trong container, không qua host).
ready=""
for _ in $(seq 1 45); do
  if "${COMPOSE[@]}" exec -T web wget -q -O /dev/null http://127.0.0.1:4000/login 2>/dev/null; then ready=1; break; fi
  sleep 2
done
[ -n "$ready" ] || { echo "Lỗi: ứng dụng không trả lời" >&2; "${COMPOSE[@]}" logs web >&2; exit 3; }
echo "Ứng dụng sẵn sàng tại http://legacy:4000 (chỉ trong mạng $NETWORK)"

# Chỉ xóa thư mục báo cáo mặc định (./zap-out). Nếu bạn tự đặt DAST_OUT, script không xóa gì của bạn và đòi thư mục rỗng.
[ -n "${DAST_OUT:-}" ] || rm -rf "$OUT"
[ ! -d "$OUT" ] || [ -z "$(ls -A "$OUT")" ] || { echo "Lỗi: $OUT không rỗng" >&2; exit 3; }
mkdir -p "$OUT"
chmod a+rwx "$OUT"
cp .zap/rules.tsv .zap/progress.json "$OUT/"

ENV_ARGS=()
if [ -n "${DAST_AUTH_USER:-}" ]; then
  # Đăng nhập một lần bằng curl, lấy cookie phiên, đưa cho ZAP qua biến môi trường ZAP_AUTH_HEADER*.
  # ZAP không biết gì về đăng nhập: nó chỉ gắn cookie này vào mọi request tới host `legacy`.
  jardir="$(mktemp -d)"; chmod a+rwx "$jardir"
  docker run --rm --network "$NETWORK" -v "$jardir":/jar "$CURL_IMAGE" -s -c /jar/cookies -o /dev/null http://legacy:4000/login
  docker run --rm --network "$NETWORK" -v "$jardir":/jar "$CURL_IMAGE" -s -b /jar/cookies -c /jar/cookies -o /dev/null \
    --data-urlencode "userName=$DAST_AUTH_USER" --data-urlencode "password=${DAST_AUTH_PASSWORD:?cần DAST_AUTH_PASSWORD}" \
    http://legacy:4000/login
  sid="$(awk '$6=="connect.sid"{print $7}' "$jardir/cookies")"
  rm -rf "$jardir"
  [ -n "$sid" ] || { echo "Lỗi: đăng nhập không cho cookie phiên" >&2; exit 3; }
  ENV_ARGS=(--env ZAP_AUTH_HEADER=Cookie --env "ZAP_AUTH_HEADER_VALUE=connect.sid=$sid" --env ZAP_AUTH_HEADER_SITE=legacy)
  echo "Quét có đăng nhập với user $DAST_AUTH_USER"
fi

echo "== ZAP baseline"
SHORT_FLAG=(-s)
[ -z "${DAST_VERBOSE:-}" ] || SHORT_FLAG=()
rc=0
cid="$(docker create --network "$NETWORK" ${ENV_ARGS[@]+"${ENV_ARGS[@]}"} -v "$OUT":/zap/wrk:rw "$ZAP_IMAGE" \
  zap-baseline.py -t http://legacy:4000 -c rules.tsv -p progress.json -m 1 \
  -J baseline.json -r baseline.html -w baseline.md ${SHORT_FLAG[@]+"${SHORT_FLAG[@]}"})"
docker network connect bridge "$cid"
docker start --attach "$cid" || rc=$?
docker rm "$cid" >/dev/null
echo "Exit code của ZAP: $rc (0 sạch, 1 có FAIL mới, 2 chỉ WARN, 3 lỗi công cụ)"
if [ "$rc" -eq 2 ] && [ "${DAST_FAIL_ON_WARN:-0}" != "1" ]; then
  echo "Chỉ có WARN: không chặn (policy trong SECURITY-GATE.md)"
  rc=0
fi
exit "$rc"
