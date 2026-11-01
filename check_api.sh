#!/usr/bin/env bash
# check_api.sh — проверка доступности API. Использование: ./check_api.sh <URL>
set -u

URL="${1:-}"
TIMEOUT=10

if [[ -z "$URL" ]]; then
    echo "Использование: $0 <URL>"
    exit 1
fi

http_code=$(curl -s -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT" "$URL")
curl_rc=$?

if [[ $curl_rc -ne 0 || -z "$http_code" ]]; then
    echo "API недоступен, код ответа: 000"
    exit 1
fi

if [[ ! "$http_code" =~ ^[0-9]{3}$ ]]; then
    echo "API недоступен, код ответа: некорректный ('$http_code')"
    exit 1
fi

if [[ "$http_code" -eq 200 ]]; then
    echo "API доступен"
    exit 0
else
    echo "API недоступен, код ответа: $http_code"
    exit 1
fi
