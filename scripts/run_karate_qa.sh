#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR="${QA_ARTIFACTS_DIR:-${ROOT_DIR}/qa-artifacts/latest}"
LOGS_DIR="${ARTIFACTS_DIR}/logs"
REPORTS_DIR="${ARTIFACTS_DIR}/reports"
PAGES_DIR="${REPORTS_DIR}/karate-pages"
TARGET_CLONE_DIR="${TARGET_CLONE_DIR:-${ROOT_DIR}/target-under-test}"

TARGET_REPO_URL="${TARGET_REPO_URL:-https://github.com/EGgames/HOTEL-MVP.git}"
TARGET_REPO_BRANCH="${TARGET_REPO_BRANCH:-dev}"
QA_DB_PORT="${QA_DB_PORT:-5540}"
QA_API_PORT="${QA_API_PORT:-3100}"

DB_USER="${DB_USER:-hotel_user}"
DB_PASSWORD="${DB_PASSWORD:-hotel_pass}"
DB_NAME="${DB_NAME:-hotel_booking}"
HOLD_DURATION_MINUTES="${HOLD_DURATION_MINUTES:-10}"
PAYMENT_SIMULATOR_DECLINE_RATE="${PAYMENT_SIMULATOR_DECLINE_RATE:-0.2}"

API_PID=''
COMPOSE_FILE=''
COMPOSE_BIN=''

log() {
  printf '[db-qa] %s\n' "$*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log "Falta el comando requerido: $1"
    exit 1
  }
}

detect_compose() {
  if docker compose version >/dev/null 2>&1; then
    COMPOSE_BIN='docker compose'
    return
  fi

  if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_BIN='docker-compose'
    return
  fi

  log 'Docker Compose no esta disponible'
  exit 1
}

compose() {
  if [[ -z "${COMPOSE_BIN}" ]]; then
    detect_compose
  fi

  if [[ "${COMPOSE_BIN}" == 'docker compose' ]]; then
    docker compose -f "${COMPOSE_FILE}" "$@"
  else
    docker-compose -f "${COMPOSE_FILE}" "$@"
  fi
}

find_compose_file() {
  local candidate
  for candidate in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
    if [[ -f "${TARGET_CLONE_DIR}/${candidate}" ]]; then
      COMPOSE_FILE="${TARGET_CLONE_DIR}/${candidate}"
      return
    fi
  done

  log 'No se encontro archivo de Docker Compose en el repo objetivo'
  exit 1
}

wait_for_postgres() {
  local attempts=0
  until compose exec -T postgres pg_isready -U "${DB_USER}" -d "${DB_NAME}" >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if (( attempts > 30 )); then
      log 'PostgreSQL no quedo listo a tiempo'
      return 1
    fi
    sleep 2
  done
}

wait_for_http() {
  local url="$1"
  local label="$2"
  local attempts=0
  until curl --fail --silent --show-error "$url" >/dev/null; do
    attempts=$((attempts + 1))
    if (( attempts > 45 )); then
      log "${label} no respondio a tiempo: ${url}"
      return 1
    fi
    sleep 2
  done
}

collect_reports() {
  mkdir -p "${REPORTS_DIR}" "${PAGES_DIR}" "${LOGS_DIR}"

  if [[ -d "${ROOT_DIR}/target/karate-reports/karate-reports" ]]; then
    rm -rf "${REPORTS_DIR}/karate-report" "${PAGES_DIR}"
    mkdir -p "${REPORTS_DIR}/karate-report" "${PAGES_DIR}"
    cp -R "${ROOT_DIR}/target/karate-reports/karate-reports/." "${REPORTS_DIR}/karate-report/"
    cp -R "${ROOT_DIR}/target/karate-reports/karate-reports/." "${PAGES_DIR}/"
  fi

  if [[ -d "${ROOT_DIR}/target/gradle-test-report" ]]; then
    rm -rf "${REPORTS_DIR}/gradle-report"
    mkdir -p "${REPORTS_DIR}/gradle-report"
    cp -R "${ROOT_DIR}/target/gradle-test-report/." "${REPORTS_DIR}/gradle-report/"
  fi

  if [[ -d "${ROOT_DIR}/target/surefire-reports" ]]; then
    rm -rf "${REPORTS_DIR}/surefire-reports"
    mkdir -p "${REPORTS_DIR}/surefire-reports"
    cp -R "${ROOT_DIR}/target/surefire-reports/." "${REPORTS_DIR}/surefire-reports/"
  fi
}

build_pages_index() {
  if [[ ! -d "${PAGES_DIR}" ]]; then
    return
  fi

  mkdir -p "${PAGES_DIR}/security"

  if [[ -f "${REPORTS_DIR}/zap-report.html" ]]; then
    cp "${REPORTS_DIR}/zap-report.html" "${PAGES_DIR}/security/zap-report.html"
  fi

  if [[ -f "${REPORTS_DIR}/zap-report.md" ]]; then
    cp "${REPORTS_DIR}/zap-report.md" "${PAGES_DIR}/security/zap-report.md"
  fi

  if [[ -f "${REPORTS_DIR}/zap-report.json" ]]; then
    cp "${REPORTS_DIR}/zap-report.json" "${PAGES_DIR}/security/zap-report.json"
  fi

  cat > "${PAGES_DIR}/index.html" <<EOF
<!doctype html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
    <meta http-equiv="Pragma" content="no-cache" />
    <meta http-equiv="Expires" content="0" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Karate QA - Karate Report</title>
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 2rem; color: #111827; background: #f8fafc; }
      main { max-width: 56rem; background: #ffffff; padding: 2rem; border-radius: 1rem; box-shadow: 0 18px 48px rgba(15, 23, 42, 0.08); }
      h1 { margin-top: 0; }
      ul { padding-left: 1.25rem; }
      a { color: #0f766e; }
      code { background: #e2e8f0; padding: 0.1rem 0.35rem; border-radius: 0.25rem; }
      p.meta { color: #475569; font-size: 0.95rem; }
    </style>
  </head>
  <body>
    <main>
      <h1>Karate QA</h1>
      <p class="meta">Pipeline de Karate + OWASP ZAP contra ${TARGET_REPO_URL} (${TARGET_REPO_BRANCH}).</p>
      <ul>
        <li><a href="karate-summary.html">Abrir resumen nativo de Karate</a></li>
        <li><a href="security/zap-report.html">Abrir reporte HTML de OWASP ZAP</a></li>
        <li><a href="security/zap-report.md">Abrir resumen Markdown de OWASP ZAP</a></li>
      </ul>
    </main>
  </body>
</html>
EOF
}

cleanup() {
  local exit_code=$?

  if [[ -n "${API_PID}" ]] && kill -0 "${API_PID}" >/dev/null 2>&1; then
    kill "${API_PID}" >/dev/null 2>&1 || true
    wait "${API_PID}" >/dev/null 2>&1 || true
  fi

  if [[ -n "${COMPOSE_FILE}" ]]; then
    compose logs --no-color > "${LOGS_DIR}/docker-compose.log" 2>&1 || true
    compose down -v > "${LOGS_DIR}/docker-compose-down.log" 2>&1 || true
  fi

  collect_reports || true
  build_pages_index || true
  exit "${exit_code}"
}

trap cleanup EXIT

require_cmd git
require_cmd docker
require_cmd curl
require_cmd node
require_cmd npm
require_cmd gradle

mkdir -p "${LOGS_DIR}" "${REPORTS_DIR}"
rm -rf "${TARGET_CLONE_DIR}"

log "Clonando ${TARGET_REPO_URL}#${TARGET_REPO_BRANCH}"
git clone --depth 1 --branch "${TARGET_REPO_BRANCH}" "${TARGET_REPO_URL}" "${TARGET_CLONE_DIR}" > "${LOGS_DIR}/git-clone.log" 2>&1

find_compose_file

log 'Levantando PostgreSQL del repo objetivo'
export DB_PORT="${QA_DB_PORT}"
compose up -d postgres > "${LOGS_DIR}/docker-compose-up.log" 2>&1
wait_for_postgres

log 'Instalando dependencias y poblando datos del backend objetivo'
pushd "${TARGET_CLONE_DIR}/backend" >/dev/null
export PORT="${QA_API_PORT}"
export NODE_ENV=development
export DB_HOST=127.0.0.1
export DB_PORT="${QA_DB_PORT}"
export DB_USER DB_PASSWORD DB_NAME HOLD_DURATION_MINUTES PAYMENT_SIMULATOR_DECLINE_RATE

npm ci > "${LOGS_DIR}/npm-ci.log" 2>&1
npm run seed > "${LOGS_DIR}/seed.log" 2>&1
npm run build > "${LOGS_DIR}/npm-build.log" 2>&1

node dist/main > "${LOGS_DIR}/backend.log" 2>&1 &
API_PID=$!
popd >/dev/null

wait_for_http "http://127.0.0.1:${QA_API_PORT}/health" 'La API backend'

log 'Ejecutando suite Karate'
pushd "${ROOT_DIR}" >/dev/null
export BASE_URL="http://127.0.0.1:${QA_API_PORT}/api/v1"
set +e
gradle test --tests availability.AvailabilityRunner | tee "${LOGS_DIR}/gradle-karate.log"
karate_exit=${PIPESTATUS[0]}
set -e
popd >/dev/null

mkdir -p "${ARTIFACTS_DIR}"
sed "s/__QA_API_PORT__/${QA_API_PORT}/g" "${ROOT_DIR}/qa/zap/openapi.yaml" > "${ARTIFACTS_DIR}/zap-openapi.generated.yaml"
chmod -R a+rwX "${ARTIFACTS_DIR}"

ZAP_OPENAPI_PATH="${ARTIFACTS_DIR#"${ROOT_DIR}"/}/zap-openapi.generated.yaml"
ZAP_REPORT_HTML_PATH="${REPORTS_DIR#"${ROOT_DIR}"/}/zap-report.html"
ZAP_REPORT_MD_PATH="${REPORTS_DIR#"${ROOT_DIR}"/}/zap-report.md"
ZAP_REPORT_JSON_PATH="${REPORTS_DIR#"${ROOT_DIR}"/}/zap-report.json"

log 'Ejecutando OWASP ZAP API scan'
set +e
docker run --rm --network=host \
  -v "${ROOT_DIR}:/zap/wrk:rw" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-api-scan.py \
  -t "/zap/wrk/${ZAP_OPENAPI_PATH}" \
  -f openapi \
  -r "/zap/wrk/${ZAP_REPORT_HTML_PATH}" \
  -w "/zap/wrk/${ZAP_REPORT_MD_PATH}" \
  -J "/zap/wrk/${ZAP_REPORT_JSON_PATH}" \
  -z "-config api.disablekey=true" | tee "${LOGS_DIR}/zap.log"
zap_exit=${PIPESTATUS[0]}
set -e

if [[ ${karate_exit} -ne 0 ]]; then
  log 'Karate reporto fallos'
fi

case "${zap_exit}" in
  0)
    ;;
  1|3)
    log 'OWASP ZAP reporto hallazgos bloqueantes o error de ejecucion'
    ;;
  2)
    log 'OWASP ZAP termino con advertencias no bloqueantes'
    ;;
  *)
    log "OWASP ZAP devolvio un codigo inesperado: ${zap_exit}"
    ;;
esac

if [[ ${karate_exit} -ne 0 ]]; then
  exit "${karate_exit}"
fi

if [[ ${zap_exit} -eq 1 || ${zap_exit} -eq 3 || ${zap_exit} -gt 3 ]]; then
  exit "${zap_exit}"
fi

log 'Karate QA finalizado correctamente'
