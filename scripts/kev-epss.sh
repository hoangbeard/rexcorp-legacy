#!/usr/bin/env bash
# Ghép danh sách CVE với CISA KEV (có trong danh mục khai thác thực tế hay không) và EPSS của FIRST
# (xác suất bị khai thác trong 30 ngày tới), rồi in bảng TSV đã sắp xếp. Dùng ở Bước 3 của Lab 08.
#
#   labs/scripts/lab-08-kev-epss.sh [--epss api|csv] [--json] FILE...
#   labs/scripts/lab-08-kev-epss.sh - < danh-sach-cve.txt
#
# FILE là file bất kỳ có chứa mã CVE (báo cáo SARIF, JSON của OSV-Scanner, Trivy, Retire.js, hoặc file
# mỗi dòng một CVE). Script chỉ lấy các chuỗi dạng CVE-YYYY-NNNN, nên không phụ thuộc định dạng báo cáo.
#
# Nguồn dữ liệu (đã xem điều khoản ở bài Lab 08):
#   KEV   https://raw.githubusercontent.com/cisagov/kev-data/develop/known_exploited_vulnerabilities.json
#         Bản sao chính thức của CISA trên GitHub, giấy phép CC0. Đổi nguồn bằng KEV_URL, hoặc dùng file
#         đã tải bằng KEV_FILE (chạy offline).
#   EPSS  --epss api (mặc định): https://api.first.org/data/v1/epss?cve=... (tra cứu từng lô nhỏ, tối đa
#         100 CVE mỗi lần gọi; FIRST ghi API dùng để tra cứu, không để tải toàn bộ dữ liệu).
#         --epss csv: https://epss.empiricalsecurity.com/epss_scores-current.csv.gz (file CSV mỗi ngày;
#         dùng khi có nhiều CVE hoặc chạy theo lịch). Đổi nguồn bằng EPSS_CSV_URL, hoặc dùng file đã tải
#         bằng EPSS_CSV_FILE (.csv.gz hoặc .csv).
#
# Đầu ra (stdout): các dòng chú thích bắt đầu bằng "#" (ngày chạy, phiên bản KEV, ngày/mô hình EPSS), tiếp
# theo là TSV: cve, kev (yes/no), dateAdded, ransomware, epss, percentile. Sắp xếp: KEV trước, rồi EPSS giảm dần.
# Với --json: một mảng JSON cùng các trường đó. CVE không có trong dữ liệu EPSS có epss/percentile là "n/a".
#
# EPSS và KEV thay đổi hằng ngày: kết quả hôm nay khác kết quả tuần sau. Luôn ghi lại ngày chạy.
# Cần: bash, curl, jq (1.6 trở lên), gzip. Giấy phép: MIT (xem LICENSE-CODE của repo khóa học).

set -euo pipefail

KEV_URL="${KEV_URL:-https://raw.githubusercontent.com/cisagov/kev-data/develop/known_exploited_vulnerabilities.json}"
EPSS_API_URL="${EPSS_API_URL:-https://api.first.org/data/v1/epss}"
EPSS_CSV_URL="${EPSS_CSV_URL:-https://epss.empiricalsecurity.com/epss_scores-current.csv.gz}"
BATCH=100

mode=api
as_json=0
inputs=()
while [ $# -gt 0 ]; do
  case "$1" in
    --epss) mode="${2:-}"; shift 2 ;;
    --json) as_json=1; shift ;;
    -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
    -) inputs+=("-"); shift ;;
    -*) echo "Lỗi: không hiểu tùy chọn $1" >&2; exit 2 ;;
    *) inputs+=("$1"); shift ;;
  esac
done
[ "${#inputs[@]}" -gt 0 ] || { echo "Cách dùng: $0 [--epss api|csv] [--json] FILE... (hoặc -)" >&2; exit 2; }
case "$mode" in api|csv) ;; *) echo "Lỗi: --epss phải là api hoặc csv" >&2; exit 2 ;; esac
for c in curl jq gzip; do command -v "$c" >/dev/null 2>&1 || { echo "Lỗi: không tìm thấy $c" >&2; exit 1; }; done

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# 1. Gom mã CVE từ mọi đầu vào, bỏ trùng.
for f in "${inputs[@]}"; do
  if [ "$f" = "-" ]; then cat; else [ -r "$f" ] || { echo "Lỗi: không đọc được $f" >&2; exit 2; }; cat "$f"; fi
done | grep -oE 'CVE-[0-9]{4}-[0-9]{4,}' | sort -u > "$tmp/cves.txt" || true
total="$(wc -l < "$tmp/cves.txt" | tr -d ' ')"
[ "$total" -gt 0 ] || { echo "Lỗi: không tìm thấy mã CVE nào trong đầu vào" >&2; exit 1; }

# 2. KEV.
if [ -n "${KEV_FILE:-}" ]; then cp "$KEV_FILE" "$tmp/kev.json"; else curl -fsS --retry 3 -m 60 -o "$tmp/kev.json" "$KEV_URL"; fi
jq -e '.vulnerabilities | type == "array"' "$tmp/kev.json" >/dev/null || { echo "Lỗi: KEV không đúng định dạng mong đợi" >&2; exit 1; }
kev_version="$(jq -r '.catalogVersion' "$tmp/kev.json")"
kev_count="$(jq -r '.count' "$tmp/kev.json")"

# 3. EPSS -> $tmp/epss.tsv (cve, epss, percentile), $tmp/epss.meta (một dòng mô tả nguồn)
if [ "$mode" = api ]; then
  : > "$tmp/epss.tsv"
  split -l "$BATCH" "$tmp/cves.txt" "$tmp/batch."
  for b in "$tmp"/batch.*; do
    q="$(paste -sd, "$b")"
    curl -fsS --retry 3 -m 60 -G --data-urlencode "cve=$q" "$EPSS_API_URL" -o "$tmp/resp.json"
    jq -e '.status == "OK"' "$tmp/resp.json" >/dev/null || { echo "Lỗi: API EPSS trả về trạng thái khác OK" >&2; exit 1; }
    jq -r '.data[] | [.cve, .epss, .percentile] | @tsv' "$tmp/resp.json" >> "$tmp/epss.tsv"
    last_date="$(jq -r '.data[0].date // "unknown"' "$tmp/resp.json")"
  done
  echo "EPSS: api.first.org, ngày điểm ${last_date:-unknown}" > "$tmp/epss.meta"
else
  if [ -n "${EPSS_CSV_FILE:-}" ]; then cp "$EPSS_CSV_FILE" "$tmp/epss.raw"; else curl -fsSL --retry 3 -m 120 -o "$tmp/epss.raw" "$EPSS_CSV_URL"; fi
  if gzip -t "$tmp/epss.raw" 2>/dev/null; then gzip -dc "$tmp/epss.raw" > "$tmp/epss.csv"; else cp "$tmp/epss.raw" "$tmp/epss.csv"; fi
  header="$(head -1 "$tmp/epss.csv")"
  case "$header" in "#"*) ;; *) header="(không có dòng mô hình)" ;; esac
  awk -F, 'NR==FNR { want[$1]; next } ($1 in want) { print $1 "\t" $2 "\t" $3 }' "$tmp/cves.txt" "$tmp/epss.csv" > "$tmp/epss.tsv"
  echo "EPSS: csv, $header" > "$tmp/epss.meta"
fi

# 4. Ghép và sắp xếp.
jq -n -r --rawfile cves "$tmp/cves.txt" --slurpfile kev "$tmp/kev.json" --rawfile epss "$tmp/epss.tsv" '
  ($kev[0].vulnerabilities | map({key: .cveID, value: .}) | from_entries) as $k
  | ($epss | split("\n") | map(select(length > 0) | split("\t") | {key: .[0], value: {epss: (.[1]|tonumber), percentile: (.[2]|tonumber)}}) | from_entries) as $e
  | $cves | split("\n") | map(select(length > 0))
  | map(. as $c | {
      cve: $c,
      kev: (if $k[$c] then "yes" else "no" end),
      dateAdded: ($k[$c].dateAdded // "-"),
      ransomware: ($k[$c].knownRansomwareCampaignUse // "-"),
      epss: ($e[$c].epss // "n/a"),
      percentile: ($e[$c].percentile // "n/a")
    })
  | sort_by([(if .kev == "yes" then 0 else 1 end), (if .epss == "n/a" then 1 else -.epss end)])' > "$tmp/joined.json"

echo "# Ngày chạy (UTC): $(date -u +%Y-%m-%dT%H:%MZ)"
echo "# KEV: catalogVersion $kev_version, $kev_count mục (nguồn: $( [ -n "${KEV_FILE:-}" ] && echo "file $KEV_FILE" || echo "$KEV_URL"))"
echo "# $(cat "$tmp/epss.meta")"
echo "# CVE trong đầu vào: $total; có trong KEV: $(jq '[.[]|select(.kev=="yes")]|length' "$tmp/joined.json"); có điểm EPSS: $(jq '[.[]|select(.epss!="n/a")]|length' "$tmp/joined.json")"
if [ "$as_json" = 1 ]; then
  cat "$tmp/joined.json"
else
  printf 'cve\tkev\tdateAdded\transomware\tepss\tpercentile\n'
  jq -r '.[] | [.cve, .kev, .dateAdded, .ransomware, .epss, .percentile] | @tsv' "$tmp/joined.json"
fi
