#!/usr/bin/env bash
# analyze_logs.sh — генерирует access.log и выводит статистику:
# общее число запросов, топ-3 IP, количество кодов 4xx и 5xx.
set -euo pipefail

LOG_FILE="access.log"
NUM_LINES=350

echo "Генерация тестового лога: $LOG_FILE ($NUM_LINES строк)..."

awk -v n="$NUM_LINES" 'BEGIN {
    srand(42);
    split("GET POST PUT DELETE", m, " ");
    split("/api/users /api/login /api/orders /api/health /api/items /api/stats", p, " ");
    codesN = split("200 200 200 200 200 200 201 204 301 400 400 401 403 404 404 500 502 503", c, " ");

    for (i = 1; i <= n; i++) {
        ip  = int(rand()*254 + 1) "." int(rand()*254 + 1) "." int(rand()*254 + 1) "." int(rand()*254 + 1);
        if (i % 7 == 0)  ip = "192.168.1.10";
        if (i % 11 == 0) ip = "10.0.0.5";
        if (i % 13 == 0) ip = "172.16.0.99";

        sec = int(rand()*86400);
        hh = sprintf("%02d", int(sec/3600));
        mm = sprintf("%02d", int(sec%3600/60));
        ss = sprintf("%02d", sec%60);
        method = m[int(rand()*4 + 1)];
        path   = p[int(rand()*6 + 1)];
        code   = c[int(rand()*codesN + 1)];
        printf "%s - - [15/Aug/2026:%s:%s:%s] \"%s %s HTTP/1.1\" %s\n", ip, hh, mm, ss, method, path, code;
    }
}' > "$LOG_FILE"

echo "Сгенерировано строк: $(wc -l < "$LOG_FILE" | awk '{print $1}')"

# Регулярное выражение для IPv4
IP_REGEX='([0-9]{1,3}\.){3}[0-9]{1,3}'

echo
echo "================ АНАЛИЗ ACCESS.LOG ================"

total=$(grep -cE "$IP_REGEX - - \[" "$LOG_FILE")
echo
echo "Общее количество запросов: $total"

echo
echo "Топ-3 IP-адреса с наибольшим числом запросов:"
awk '{print $1}' "$LOG_FILE" | grep -E "$IP_REGEX" | sort | uniq -c | sort -rn | head -3 | \
    awk '{printf "  %s — %d запросов\n", $2, $1}'

awk4xx=$(awk '$NF ~ /^4[0-9][0-9]$/ {count++} END {print count+0}' "$LOG_FILE")
awk5xx=$(awk '$NF ~ /^5[0-9][0-9]$/ {count++} END {print count+0}' "$LOG_FILE")

echo
echo "Запросов с кодами 4xx: $awk4xx"
echo "Запросов с кодами 5xx: $awk5xx"

echo
echo "Распределение кодов ответов:"
grep -oE 'HTTP/1\.[01]" [0-9]{3}$' "$LOG_FILE" | awk '{print $2}' | sort | uniq -c | sort -rn | \
    awk '{printf "  %s — %d\n", $2, $1}'

echo
echo "================= КОНЕЦ АНАЛИЗА =================="
