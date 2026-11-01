# infra-monitoring-project

Учебный проект: система мониторинга доступности API-сервиса (echo-сервер).

Включает в себя:

- **check_api.sh** — Bash-скрипт мониторинга доступности API (HTTP-проверка кода ответа)
- **analyze_logs.sh** — Bash-скрипт анализа access-логов (топ IP, коды ответов)
- **docker-compose.yml** — контейнеризированный стек: echo-API (hashicorp/http-echo) + reverse-proxy (nginx:alpine)
- **.github/workflows/ci.yml** — CI/CD пайплайн (GitHub Actions): проверка синтаксиса и тестирование скриптов

## Структура проекта

```
infra-monitoring-project/
├── README.md
├── .gitignore
├── check_api.sh              # мониторинг API
├── analyze_logs.sh           # анализ логов
├── docker-compose.yml        # стек мониторинга
└── .github/
    └── workflows/
        └── ci.yml            # CI/CD пайплайн
```

## Быстрый старт

### 1. Мониторинг API

```bash
chmod +x check_api.sh
./check_api.sh https://httpbin.org/status/200   # API доступен (код 0)
./check_api.sh https://httpbin.org/status/500   # API недоступен (код 1)
```

### 2. Анализ логов

```bash
chmod +x analyze_logs.sh
./analyze_logs.sh        # генерирует access.log и выводит статистику
```

### 3. Запуск стека мониторинга (Docker Compose)

```bash
docker compose up -d
curl http://localhost:80
# -> Monitoring Service Active
docker compose ps
docker compose down
```

Схема работы: запрос → **nginx:80** (proxy) → внутренняя Docker-сеть `monitoring-net` → **http-echo:8080** (api).

## CI/CD

Пайплайн GitHub Actions (`.github/workflows/ci.yml`) запускается при создании Pull Request:

1. `bash -n check_api.sh` — проверка синтаксиса скрипта мониторинга
2. `bash -n analyze_logs.sh` — проверка синтаксиса скрипта анализа логов
3. `./check_api.sh https://httpbin.org/status/200` — функциональный тест (ожидается код возврата 0)

## SSH и SCP: безопасный деплой на удалённый сервер

### Шаг 1. Генерация SSH-ключей

На рабочей машине генерируем пару ключей (ed25519 — современный и компактный алгоритм):

```bash
ssh-keygen -t ed25519 -C "deploy@infra-monitoring" -f ~/.ssh/id_ed25519
```

- `~/.ssh/id_ed25519` — приватный ключ (никогда никому не передаётся)
- `~/.ssh/id_ed25519.pub` — публичный ключ (копируется на сервер)

Для старых систем, не поддерживающих ed25519:

```bash
ssh-keygen -t rsa -b 4096 -C "deploy@infra-monitoring" -f ~/.ssh/id_rsa
```

### Шаг 2. Копирование публичного ключа на сервер

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@server.example.com
```

Проверка входа без пароля:

```bash
ssh user@server.example.com 'echo OK'
```

Если `ssh-copy-id` недоступен, можно добавить ключ вручную:

```bash
cat ~/.ssh/id_ed25519.pub | ssh user@server.example.com \
  'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

### Шаг 3. Передача проекта на сервер

**Вариант A — архив проекта через tar + ssh:**

```bash
tar --exclude='.git' --exclude='*.log' --exclude='*.pcapng' \
    -czf infra-monitoring-project.tar.gz infra-monitoring-project/

scp infra-monitoring-project.tar.gz user@server.example.com:/opt/deploy/

# на сервере: распаковка и запуск
ssh user@server.example.com 'tar -xzf /opt/deploy/infra-monitoring-project.tar.gz -C /opt/deploy && cd /opt/deploy/infra-monitoring-project && docker compose up -d'
```

**Вариант B — копирование файлов по одному через scp:**

```bash
scp check_api.sh analyze_logs.sh docker-compose.yml user@server.example.com:/opt/deploy/infra-monitoring-project/
```

**Вариант C — деплой через git (рекомендуется):**

```bash
# на сервере (после добавления его deploy-ключа в GitHub)
git clone git@github.com:Jsqadro/infra-monitoring-project.git /opt/deploy/infra-monitoring-project
cd /opt/deploy/infra-monitoring-project
docker compose up -d
```

### Шаг 4. Проверка деплоя

```bash
ssh user@server.example.com 'cd /opt/deploy/infra-monitoring-project && docker compose ps && curl -s http://localhost:80'
```
