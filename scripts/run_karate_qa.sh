#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR="${QA_ARTIFACTS_DIR:-${ROOT_DIR}/qa-artifacts/latest}"
LOGS_DIR="${ARTIFACTS_DIR}/logs"
REPORTS_DIR="${ARTIFACTS_DIR}/reports"
PIPELINE_DIR="${ARTIFACTS_DIR}/pipeline"
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
KARATE_EXIT='99'
ZAP_EXIT='99'
TARGET_COMMIT=''

# QA_MODE controls which phase(s) this invocation executes:
#   all     - full lifecycle (default, backward-compatible)
#   infra   - clone target, start postgres/API, write state file, exit without cleanup
#   karate  - source state, run Karate suite only
#   zap     - source state, run OWASP ZAP only
#   cleanup - source state, collect reports, tear down infrastructure
QA_MODE="${QA_MODE:-all}"
STATE_FILE="${ARTIFACTS_DIR}/.qa-state"

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
  mkdir -p "${REPORTS_DIR}" "${PAGES_DIR}" "${LOGS_DIR}" "${PIPELINE_DIR}"

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

generate_execution_summary() {
  mkdir -p "${REPORTS_DIR}" "${PIPELINE_DIR}"

  local karate_status='FAIL'
  local zap_status='FAIL'
  local overall_status='FAIL'
  local scenarios_line='Sin datos de escenarios'
  local features_line='Sin datos de features'
  local warn_count='0'
  local fail_count='0'
  local error_count='0'
  local summary_file="${REPORTS_DIR}/execution-summary.md"
  local json_file="${PIPELINE_DIR}/execution-summary.json"

  if [[ "${KARATE_EXIT}" -eq 0 ]]; then
    karate_status='PASS'
  fi

  case "${ZAP_EXIT}" in
    0)
      zap_status='PASS'
      ;;
    2)
      zap_status='WARN'
      ;;
    *)
      zap_status='FAIL'
      ;;
  esac

  if [[ "${karate_status}" == 'PASS' && ( "${zap_status}" == 'PASS' || "${zap_status}" == 'WARN' ) ]]; then
    overall_status='PASS'
  fi

  if [[ -f "${LOGS_DIR}/gradle-karate.log" ]]; then
    scenarios_line=$(grep -E 'scenarios:[[:space:]]+[0-9]+ \| passed:' "${LOGS_DIR}/gradle-karate.log" | tail -1 || true)
    features_line=$(grep -E 'features:[[:space:]]+[0-9]+ \| skipped:' "${LOGS_DIR}/gradle-karate.log" | tail -1 || true)
    [[ -n "${scenarios_line}" ]] || scenarios_line='Sin datos de escenarios'
    [[ -n "${features_line}" ]] || features_line='Sin datos de features'
  fi

  if [[ -f "${LOGS_DIR}/zap.log" ]]; then
    warn_count=$(grep -c '^WARN-NEW:' "${LOGS_DIR}/zap.log" || true)
    fail_count=$(grep -cE '^(FAIL-NEW|FAIL-INPROG):' "${LOGS_DIR}/zap.log" || true)
    error_count=$(grep -cE 'Permission denied|ERROR ' "${LOGS_DIR}/zap.log" || true)
  fi

  cat > "${summary_file}" <<EOF
# Karate QA Summary

- Resultado general: ${overall_status}
- Repositorio objetivo: ${TARGET_REPO_URL}
- Rama objetivo: ${TARGET_REPO_BRANCH}
- Commit objetivo: ${TARGET_COMMIT:-desconocido}
- API base URL: http://127.0.0.1:${QA_API_PORT}/api/v1

| Gate | Status | Evidencia |
|---|---|---|
| Karate availability suite | ${karate_status} | ${scenarios_line} |
| Karate features | ${karate_status} | ${features_line} |
| OWASP ZAP | ${zap_status} | WARN-NEW=${warn_count}, FAIL-NEW=${fail_count}, errores=${error_count} |

## Reportes

- Karate summary HTML: reports/karate-report/karate-summary.html
- Gradle report HTML: reports/gradle-report/index.html
- JUnit XML: reports/surefire-reports
- ZAP HTML: reports/zap-report.html
- ZAP Markdown: reports/zap-report.md
- Pages index: reports/karate-pages/index.html
EOF

  cat > "${json_file}" <<EOF
{
  "overall_status": "${overall_status}",
  "karate": {
    "status": "${karate_status}",
    "exit_code": ${KARATE_EXIT},
    "scenarios": $(printf '%s' "${scenarios_line}" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
  },
  "zap": {
    "status": "${zap_status}",
    "exit_code": ${ZAP_EXIT},
    "warn_new": ${warn_count},
    "fail_new": ${fail_count},
    "errors": ${error_count}
  }
}
EOF

  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    cat "${summary_file}" > "${GITHUB_STEP_SUMMARY}"
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

_teardown() {
  # In split-mode (cleanup phase), load state written by the infra phase.
  if [[ -z "${COMPOSE_FILE}" && -f "${STATE_FILE:-}" ]]; then
    # shellcheck source=/dev/null
    source "${STATE_FILE}" 2>/dev/null || true
  fi

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
  generate_execution_summary || true
}

cleanup() {
  local exit_code=$?
  _teardown
  exit "${exit_code}"
}

# Register cleanup trap only in 'all' mode; split-mode callers manage teardown via explicit step.
[[ "${QA_MODE}" == "all" ]] && trap cleanup EXIT

require_cmd git
require_cmd docker
require_cmd curl
require_cmd node
require_cmd npm
# gradle is only needed for phases that run Karate
case "${QA_MODE}" in all|karate) require_cmd gradle ;; esac

mkdir -p "${LOGS_DIR}" "${REPORTS_DIR}" "${PIPELINE_DIR}"

# In cleanup mode: load state and tear down; skip all infra setup.
if [[ "${QA_MODE}" == "cleanup" ]]; then
  _teardown
  exit 0
fi

rm -rf "${TARGET_CLONE_DIR}"

log "Clonando ${TARGET_REPO_URL}#${TARGET_REPO_BRANCH}"
# [RISK-S3] ADVERTENCIA: se ejecuta codigo del repo objetivo (npm ci/build/seed/node dist/main).
# Asegurar que TARGET_REPO_URL apunta a un repositorio de confianza antes de ejecutar en produccion.
git clone --depth 1 --branch "${TARGET_REPO_BRANCH}" "${TARGET_REPO_URL}" "${TARGET_CLONE_DIR}" > "${LOGS_DIR}/git-clone.log" 2>&1
TARGET_COMMIT="$(git -C "${TARGET_CLONE_DIR}" rev-parse HEAD 2>/dev/null || true)"

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

# In infra mode: write state file so subsequent phases can find the running services, then exit.
# Background processes (Docker containers, Node API) survive because they are not children of the
# current shell step — Docker is daemon-managed, and node was disowned by the shell.
if [[ "${QA_MODE}" == "infra" ]]; then
  mkdir -p "$(dirname "${STATE_FILE}")"
  {
    printf 'API_PID=%q\n' "${API_PID}"
    printf 'COMPOSE_FILE=%q\n' "${COMPOSE_FILE}"
    printf 'TARGET_COMMIT=%q\n' "${TARGET_COMMIT}"
  } > "${STATE_FILE}"
  log "Infraestructura lista. Estado guardado en ${STATE_FILE}"
  exit 0
fi
# ─── Karate phase ────────────────────────────────────────────────────────────
if [[ "${QA_MODE}" == "all" || "${QA_MODE}" == "karate" ]]; then
  # In karate mode, source state so _teardown has COMPOSE_FILE / TARGET_COMMIT.
  [[ "${QA_MODE}" == "karate" && -f "${STATE_FILE}" ]] && source "${STATE_FILE}" 2>/dev/null || true

  log 'Ejecutando suite Karate completa'
  pushd "${ROOT_DIR}" >/dev/null
  export BASE_URL="http://127.0.0.1:${QA_API_PORT}/api/v1"
  set +e
  # Para acotar la suite pasar la variable KARATE_FILTER (ej: --tests availability.AvailabilityRunner).
  gradle test ${KARATE_FILTER:-} | tee "${LOGS_DIR}/gradle-karate.log"
  KARATE_EXIT=${PIPESTATUS[0]}
  set -e
  popd >/dev/null

  if [[ "${QA_MODE}" == "karate" ]]; then
    # Persist exit code so the cleanup phase can use it in the execution summary.
    printf 'KARATE_EXIT=%q\n' "${KARATE_EXIT}" >> "${STATE_FILE}"
    if [[ ${KARATE_EXIT} -ne 0 ]]; then
      log 'Karate reporto fallos'
      exit "${KARATE_EXIT}"
    fi
    exit 0
  fi
fi

# ─── ZAP phase ───────────────────────────────────────────────────────────────
if [[ "${QA_MODE}" == "all" || "${QA_MODE}" == "zap" ]]; then
  # In zap mode, source state so _teardown has COMPOSE_FILE / TARGET_COMMIT.
  [[ "${QA_MODE}" == "zap" && -f "${STATE_FILE}" ]] && source "${STATE_FILE}" 2>/dev/null || true

  mkdir -p "${ARTIFACTS_DIR}"
  sed "s/__QA_API_PORT__/${QA_API_PORT}/g" "${ROOT_DIR}/qa/zap/openapi.yaml" > "${ARTIFACTS_DIR}/zap-openapi.generated.yaml"
  # [FIX-S4] Eliminado chmod -R a+rwX: permisos world-writable innecesarios en runner efimero.

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
  ZAP_EXIT=${PIPESTATUS[0]}
  set -e

  if [[ "${QA_MODE}" == "zap" ]]; then
    # Persist exit code so the cleanup phase can use it in the execution summary.
    printf 'ZAP_EXIT=%q\n' "${ZAP_EXIT}" >> "${STATE_FILE}"
    case "${ZAP_EXIT}" in
      0) ;;
      2) log 'OWASP ZAP termino con advertencias no bloqueantes' ;;
      1|3) log 'OWASP ZAP reporto hallazgos bloqueantes o error de ejecucion'; exit "${ZAP_EXIT}" ;;
      *) log "OWASP ZAP devolvio un codigo inesperado: ${ZAP_EXIT}"; exit "${ZAP_EXIT}" ;;
    esac
    exit 0
  fi
fi

# ─── all-mode combined exit logic ────────────────────────────────────────────
if [[ ${KARATE_EXIT} -ne 0 ]]; then
  log 'Karate reporto fallos'
fi

case "${ZAP_EXIT}" in
  0) ;;
  1|3) log 'OWASP ZAP reporto hallazgos bloqueantes o error de ejecucion' ;;
  2)   log 'OWASP ZAP termino con advertencias no bloqueantes' ;;
  *)   log "OWASP ZAP devolvio un codigo inesperado: ${ZAP_EXIT}" ;;
esac

if [[ ${KARATE_EXIT} -ne 0 ]]; then
  exit "${KARATE_EXIT}"
fi

if [[ ${ZAP_EXIT} -eq 1 || ${ZAP_EXIT} -eq 3 || ${ZAP_EXIT} -gt 3 ]]; then
  exit "${ZAP_EXIT}"
fi

log 'Karate QA finalizado correctamente'
