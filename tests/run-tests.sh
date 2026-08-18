#!/usr/bin/env bash
# Shave Test Orchestrator
# Runs tests/0000 first, then remaining numbered suites in parallel via xargs
#
# CHANGELOG
# 1.2.0 - 2026-08-18 - CMake 0000, selector syntax, colored footer, Fail+Skip exit
# 1.1.0 - 2026-08-18 - xargs parallelism, tables summary, per-test logs
# 1.0.0 - 2026-08-18 - Initial orchestrator for numbered test.sh suites

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOGS_DIR="${SCRIPT_DIR}/logs"
VERSION_FILE="${REPO_ROOT}/VERSION"

SKIP_0000=false
SEQUENTIAL=false
LIST_ONLY=false
RUN_ONE=""
JOBS=""
SELECTED=()

usage() {
    cat <<'EOF'
Usage: ./tests/run-tests.sh [options] [selector ...]

Runs the Shave test suite. Suite 0000 always runs first (unless skipped)
as the CMake project build gate. Remaining suites then run in parallel
via xargs using one worker per available core.

Options:
  -h, --help         Show this help and exit
  -l, --list         List discovered test suites and exit
  -j, --jobs N       Maximum parallel suites after 0000 (default: nproc)
  --sequential       Run remaining suites one at a time
  --skip-0000        Skip the 0000 CMake build gate

Selectors:
  0001               Run one suite
  1,3,5              Run a set of suites
  1-10               Run an inclusive range
  1,4-6,9            Mix sets and ranges

Numbers may be given with or without leading zeros.
0000 still runs first unless --skip-0000 is set.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -l|--list)
            LIST_ONLY=true
            shift
            ;;
        -j|--jobs)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --jobs requires a number" >&2
                exit 2
            fi
            JOBS="$2"
            shift 2
            ;;
        --sequential)
            SEQUENTIAL=true
            shift
            ;;
        --skip-0000)
            SKIP_0000=true
            shift
            ;;
        --run-one)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --run-one requires a test id" >&2
                exit 2
            fi
            RUN_ONE="$2"
            shift 2
            ;;
        --)
            shift
            SELECTED+=("$@")
            break
            ;;
        -*)
            echo "Error: unknown option $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            SELECTED+=("$1")
            shift
            ;;
    esac
done

discover_suites() {
    local path id
    SUITES=()
    for path in "${SCRIPT_DIR}"/[0-9][0-9][0-9][0-9]/test.sh; do
        [[ -f "${path}" ]] || continue
        id="$(basename "$(dirname "${path}")")"
        SUITES+=("${id}")
    done
}

suite_exists() {
    local id="$1"
    local candidate
    for candidate in "${SUITES[@]}"; do
        if [[ "${candidate}" == "${id}" ]]; then
            return 0
        fi
    done
    return 1
}

pad_test_id() {
    local raw="$1"
    if [[ ! "${raw}" =~ ^[0-9]+$ ]]; then
        echo "Error: invalid test number '${raw}'" >&2
        return 1
    fi
    if (( raw > 9999 )); then
        echo "Error: test number '${raw}' is out of range" >&2
        return 1
    fi
    printf '%04d' "${raw}"
}

add_unique_id() {
    local -n dest=$1
    local id="$2"
    local existing
    for existing in "${dest[@]+"${dest[@]}"}"; do
        if [[ "${existing}" == "${id}" ]]; then
            return 0
        fi
    done
    dest+=("${id}")
}

parse_selector_token() {
    local token="$1"
    local part start_raw end_raw start_id end_id start_num end_num id
    local -n parsed=$2

    IFS=',' read -r -a parts <<< "${token}"
    if [[ ${#parts[@]} -eq 0 ]]; then
        echo "Error: empty test selector" >&2
        return 1
    fi

    for part in "${parts[@]}"; do
        if [[ -z "${part}" ]]; then
            echo "Error: empty test selector" >&2
            return 1
        fi
        if [[ "${part}" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            start_raw="${BASH_REMATCH[1]}"
            end_raw="${BASH_REMATCH[2]}"
            start_id="$(pad_test_id "${start_raw}")" || return 1
            end_id="$(pad_test_id "${end_raw}")" || return 1
            start_num=$((10#${start_id}))
            end_num=$((10#${end_id}))
            if (( start_num > end_num )); then
                echo "Error: invalid test range '${part}'" >&2
                return 1
            fi
            for id in "${SUITES[@]}"; do
                if (( 10#${id} >= start_num && 10#${id} <= end_num )); then
                    add_unique_id parsed "${id}"
                fi
            done
        elif [[ "${part}" =~ ^[0-9]+$ ]]; then
            id="$(pad_test_id "${part}")" || return 1
            if ! suite_exists "${id}"; then
                echo "Error: test suite not found: ${id}" >&2
                return 1
            fi
            add_unique_id parsed "${id}"
        else
            echo "Error: invalid test selector '${part}'" >&2
            return 1
        fi
    done
}

suite_path() {
    printf '%s/%s/test.sh' "${SCRIPT_DIR}" "$1"
}

suite_name() {
    local id="$1"
    local script name
    script="$(suite_path "${id}")"
    name="$(sed -n "s/^# Test ${id}: //p" "${script}" 2>/dev/null | head -n 1)"
    if [[ -z "${name}" ]]; then
        name="unnamed"
    fi
    printf '%s' "${name}"
}

suite_log_dir() {
    printf '%s/%s' "${LOGS_DIR}" "$1"
}

project_version() {
    if [[ -f "${VERSION_FILE}" ]]; then
        tr -d '[:space:]' < "${VERSION_FILE}"
        return 0
    fi
    printf '%s' "0.0.0"
}

now_seconds() {
    date +%s.%N 2>/dev/null || date +%s
}

elapsed_since() {
    local start="$1"
    local end
    end="$(now_seconds)"
    awk -v s="${start}" -v e="${end}" 'BEGIN { printf "%.3f", e - s }'
}

json_escape() {
    python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

clear_logs() {
    rm -rf "${LOGS_DIR}"
    mkdir -p "${LOGS_DIR}"
}

write_result_file() {
    local id="$1"
    local status="$2"
    local elapsed="$3"
    local log_dir
    local logfile
    local result_line
    local passed=0
    local failed=0
    local skipped=0

    log_dir="$(suite_log_dir "${id}")"
    logfile="${log_dir}/test.log"
    result_line="$(grep -E '^RESULT ' "${logfile}" 2>/dev/null | tail -n 1 || true)"
    if [[ -n "${result_line}" ]]; then
        passed="${result_line##* passed=}"
        passed="${passed%% *}"
        failed="${result_line##* failed=}"
        failed="${failed%% *}"
        skipped="${result_line##* skipped=}"
        skipped="${skipped%% *}"
    fi
    if [[ ! "${passed}" =~ ^[0-9]+$ ]]; then passed=0; fi
    if [[ ! "${failed}" =~ ^[0-9]+$ ]]; then failed=0; fi
    if [[ ! "${skipped}" =~ ^[0-9]+$ ]]; then skipped=0; fi
    if [[ "${status}" -ne 0 && "${failed}" -eq 0 ]]; then
        failed=1
    fi

    {
        printf 'id=%s\n' "${id}"
        printf 'name=%s\n' "$(suite_name "${id}")"
        printf 'status=%s\n' "${status}"
        printf 'elapsed=%s\n' "${elapsed}"
        printf 'passed=%s\n' "${passed}"
        printf 'failed=%s\n' "${failed}"
        printf 'skipped=%s\n' "${skipped}"
    } >"${log_dir}/result.txt"
}

run_suite() {
    local id="$1"
    local script
    local log_dir
    local logfile
    local start
    local status

    script="$(suite_path "${id}")"
    log_dir="$(suite_log_dir "${id}")"
    logfile="${log_dir}/test.log"

    if [[ ! -f "${script}" ]]; then
        echo "Error: missing $(suite_path "${id}")" >&2
        return 1
    fi
    if [[ ! -x "${script}" ]]; then
        chmod +x "${script}"
    fi

    mkdir -p "${log_dir}"
    start="$(now_seconds)"
    (
        cd "${REPO_ROOT}" || exit 1
        "${script}"
    ) >"${logfile}" 2>&1
    status=$?
    write_result_file "${id}" "${status}" "$(elapsed_since "${start}")"
    return "${status}"
}

if [[ -z "${JOBS}" ]]; then
    JOBS="$(nproc 2>/dev/null || echo 4)"
fi
if ! [[ "${JOBS}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: jobs must be a positive integer" >&2
    exit 2
fi

discover_suites

if [[ -n "${RUN_ONE}" ]]; then
    mkdir -p "${LOGS_DIR}"
    run_suite "${RUN_ONE}"
    exit $?
fi

if [[ "${LIST_ONLY}" == true ]]; then
    if [[ ${#SUITES[@]} -eq 0 ]]; then
        echo "No test suites found"
        exit 0
    fi
    echo "Discovered test suites:"
    for id in "${SUITES[@]}"; do
        echo "  ${id}  $(suite_name "${id}")"
    done
    exit 0
fi

REQUESTED_IDS=()
if [[ ${#SELECTED[@]} -gt 0 ]]; then
    for selector in "${SELECTED[@]}"; do
        if ! parse_selector_token "${selector}" REQUESTED_IDS; then
            exit 2
        fi
    done
    if [[ ${#REQUESTED_IDS[@]} -eq 0 ]]; then
        echo "Error: no test suites matched the given selector" >&2
        exit 2
    fi
    PARALLEL_IDS=()
    for id in "${REQUESTED_IDS[@]}"; do
        if [[ "${id}" != "0000" ]]; then
            PARALLEL_IDS+=("${id}")
        fi
    done
else
    PARALLEL_IDS=()
    for id in "${SUITES[@]}"; do
        if [[ "${id}" != "0000" ]]; then
            PARALLEL_IDS+=("${id}")
        fi
    done
fi

if ! command -v tables >/dev/null 2>&1; then
    echo "Error: tables is not installed" >&2
    exit 2
fi

declare -a RUN_IDS=()

SUITE_START="$(now_seconds)"
OVERALL=0

if [[ "${SKIP_0000}" != true ]]; then
    if [[ ! -f "$(suite_path 0000)" ]]; then
        echo "Error: required gate tests/0000/test.sh is missing" >&2
        exit 2
    fi
    clear_logs
    if ! run_suite 0000; then
        OVERALL=1
    fi
    RUN_IDS+=(0000)
else
    mkdir -p "${LOGS_DIR}"
fi

run_remaining_sequential() {
    local id
    for id in "${PARALLEL_IDS[@]}"; do
        if ! run_suite "${id}"; then
            OVERALL=1
        fi
        RUN_IDS+=("${id}")
    done
}

run_remaining_xargs() {
    local id
    local xargs_status=0
    if [[ ${#PARALLEL_IDS[@]} -eq 0 ]]; then
        return 0
    fi
    printf '%s\n' "${PARALLEL_IDS[@]}" | xargs -P "${JOBS}" -I{} \
        "${SCRIPT_DIR}/run-tests.sh" --run-one {} || xargs_status=$?
    if [[ "${xargs_status}" -ne 0 ]]; then
        OVERALL=1
    fi
    for id in "${PARALLEL_IDS[@]}"; do
        RUN_IDS+=("${id}")
        if [[ ! -f "$(suite_log_dir "${id}")/result.txt" ]]; then
            OVERALL=1
        fi
    done
}

if [[ "${OVERALL}" -eq 0 && ${#PARALLEL_IDS[@]} -gt 0 ]]; then
    if [[ "${SEQUENTIAL}" == true ]]; then
        run_remaining_sequential
    else
        run_remaining_xargs
    fi
fi

read_result_field() {
    local file="$1"
    local key="$2"
    local line
    line="$(grep -E "^${key}=" "${file}" 2>/dev/null | tail -n 1 || true)"
    printf '%s' "${line#*=}"
}

TOTAL_ELAPSED="$(elapsed_since "${SUITE_START}")"
TOTAL_SUITES=${#RUN_IDS[@]}
PASSED_SUITES=0
FAILED_SUITES=0
SUM_RUN=0
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0

DATA_ROWS="["
for i in "${!RUN_IDS[@]}"; do
    id="${RUN_IDS[$i]}"
    result_file="$(suite_log_dir "${id}")/result.txt"
    name="$(suite_name "${id}")"
    elapsed="0.000"
    passed=0
    failed=0
    skipped=0
    status=1

    if [[ -f "${result_file}" ]]; then
        elapsed="$(read_result_field "${result_file}" elapsed)"
        passed="$(read_result_field "${result_file}" passed)"
        failed="$(read_result_field "${result_file}" failed)"
        skipped="$(read_result_field "${result_file}" skipped)"
        status="$(read_result_field "${result_file}" status)"
    fi
    if [[ ! "${elapsed}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then elapsed="0.000"; fi
    if [[ ! "${passed}" =~ ^[0-9]+$ ]]; then passed=0; fi
    if [[ ! "${failed}" =~ ^[0-9]+$ ]]; then failed=0; fi
    if [[ ! "${skipped}" =~ ^[0-9]+$ ]]; then skipped=0; fi
    if [[ ! "${status}" =~ ^[0-9]+$ ]]; then status=1; fi

    SUM_RUN="$(awk -v a="${SUM_RUN}" -v b="${elapsed}" 'BEGIN { printf "%.3f", a + b }')"
    TOTAL_PASS=$((TOTAL_PASS + passed))
    TOTAL_FAIL=$((TOTAL_FAIL + failed))
    TOTAL_SKIP=$((TOTAL_SKIP + skipped))

    color_status="{GREEN}PASS{RESET}"
    if [[ "${status}" -ne 0 || "${failed}" -gt 0 || "${skipped}" -gt 0 ]]; then
        color_status="{RED}FAIL{RESET}"
        FAILED_SUITES=$((FAILED_SUITES + 1))
        OVERALL=1
    else
        PASSED_SUITES=$((PASSED_SUITES + 1))
    fi

    if [[ "${i}" -gt 0 ]]; then
        DATA_ROWS+=","
    fi
    DATA_ROWS+="$(printf '{"test":%s,"name":%s,"time":%s,"pass":%s,"fail":%s,"skip":%s,"status":%s}' \
        "$(json_escape "${id}")" \
        "$(json_escape "${name}")" \
        "${elapsed}" \
        "${passed}" \
        "${failed}" \
        "${skipped}" \
        "$(json_escape "${color_status}")")"
done
DATA_ROWS+="]"

PERCENT=0
if [[ "${TOTAL_SUITES}" -gt 0 ]]; then
    PERCENT="$(awk -v p="${PASSED_SUITES}" -v t="${TOTAL_SUITES}" 'BEGIN { printf "%.0f", (p * 100) / t }')"
fi

TITLE="Shave v$(project_version) Results for $(date '+%Y-%b-%d')"
FOOTER="{CYAN}Wall{RESET} {WHITE}${TOTAL_ELAPSED}s{RESET} {YELLOW}───{RESET} {CYAN}Run{RESET} {WHITE}${SUM_RUN}s{RESET} {YELLOW}───{RESET} {WHITE}${PASSED_SUITES}{RESET} {CYAN}passed{RESET} {YELLOW}/{RESET} {WHITE}${FAILED_SUITES}{RESET} {CYAN}failed{RESET} {YELLOW}({RESET}{WHITE}${PERCENT}%{RESET}{YELLOW}){RESET}"

LAYOUT_FILE="$(mktemp "${LOGS_DIR}/layout.XXXXXX.json")"
DATA_FILE="$(mktemp "${LOGS_DIR}/data.XXXXXX.json")"
trap 'rm -f "${LAYOUT_FILE}" "${DATA_FILE}"' EXIT

cat >"${LAYOUT_FILE}" <<EOF
{
  "theme": "Red",
  "title": $(json_escape "${TITLE}"),
  "title_position": "left",
  "footer": $(json_escape "${FOOTER}"),
  "footer_position": "right",
  "columns": [
    {"header": "Test", "key": "test", "datatype": "text", "justification": "left"},
    {"header": "Name", "key": "name", "datatype": "text", "justification": "left"},
    {"header": "Time", "key": "time", "datatype": "float", "justification": "right", "format": "%.3f"},
    {"header": "Pass", "key": "pass", "datatype": "int", "justification": "right", "zero_value": "0", "summary": "sum"},
    {"header": "Fail", "key": "fail", "datatype": "int", "justification": "right", "zero_value": "0", "summary": "sum"},
    {"header": "Skip", "key": "skip", "datatype": "int", "justification": "right", "zero_value": "0", "summary": "sum"},
    {"header": "Status", "key": "status", "datatype": "text", "justification": "center"}
  ]
}
EOF

printf '%s\n' "${DATA_ROWS}" >"${DATA_FILE}"
tables "${LAYOUT_FILE}" "${DATA_FILE}"

if [[ "${OVERALL}" -eq 0 && "${TOTAL_FAIL}" -eq 0 && "${TOTAL_SKIP}" -eq 0 ]]; then
    exit 0
fi

EXIT_CODE=$((TOTAL_FAIL + TOTAL_SKIP))
if [[ "${EXIT_CODE}" -le 0 ]]; then
    EXIT_CODE=1
fi
if [[ "${EXIT_CODE}" -gt 255 ]]; then
    EXIT_CODE=255
fi
exit "${EXIT_CODE}"
