#!/usr/bin/env bash
# gcov table helper for shave-libs sources
#
# CHANGELOG
# 1.0.1 - 2026-08-18 - Union per-suite gcov JSON instead of gcov-tool merge
# 1.0.0 - 2026-08-18 - Merge per-suite gcov data and render a coverage table

if [[ -n "${SHAVE_COVERAGE_GUARD:-}" ]]; then
    return 0
fi
SHAVE_COVERAGE_GUARD=1

SHAVE_COVERAGE_MIN=50

shave_coverage_json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '"%s"' "${s}"
}

shave_coverage_find_gcno() {
    local build_dir="$1"
    find "${build_dir}/shave-libs" -path '*/CMakeFiles/*.dir/shave_*.c.gcno' -type f 2>/dev/null | sort
}

shave_coverage_source_for_gcno() {
    local gcno="$1"
    local repo_root="$2"
    local base
    base="$(basename "${gcno}" .c.gcno)"
    find "${repo_root}/shave-libs" -name "${base}.c" -type f | head -n 1
}

shave_coverage_gcda_dirs() {
    local logs_dir="$1"
    local dir
    local gcda
    while IFS= read -r dir; do
        [[ -d "${dir}" ]] || continue
        gcda=""
        gcda="$(find "${dir}" -name '*.gcda' -type f -print -quit)"
        if [[ -n "${gcda}" ]]; then
            printf '%s\n' "${dir}"
        fi
    done < <(find "${logs_dir}" -mindepth 2 -maxdepth 2 -type d -name gcda 2>/dev/null | sort)
}

shave_coverage_file_stats() {
    local src="$1"
    local gcno="$2"
    local work_dir="$3"
    shift 3
    local gcda_dir
    local stem
    local objdir
    local gcda
    local tmp
    local json
    local total=0
    local line
    local -A hit_lines=()

    stem="$(basename "${gcno}" .gcno)"
    objdir="$(dirname "${gcno}")"
    tmp="${work_dir}/gcov-$(basename "${stem}")"
    mkdir -p "${tmp}"
    cp "${gcno}" "${tmp}/${stem}.gcno"

    for gcda_dir in "$@"; do
        gcda="${gcda_dir}/${objdir#/}/${stem}.gcda"
        if [[ ! -f "${gcda}" ]]; then
            continue
        fi
        cp "${gcda}" "${tmp}/${stem}.gcda"
        json=""
        json="$(gcov -t -j -o "${tmp}/${stem}.gcno" "${src}" 2>/dev/null || true)"
        if [[ -z "${json}" ]]; then
            continue
        fi
        if [[ "${total}" -eq 0 ]]; then
            total="$(printf '%s\n' "${json}" | jq --arg src "${src}" '
                [ .files[]
                  | select((.file | tostring) == $src or (.file | tostring | endswith($src)))
                  | .lines
                ]
                | add // []
                | length
            ')"
            if [[ ! "${total}" =~ ^[0-9]+$ ]]; then
                total=0
            fi
        fi
        while IFS= read -r line; do
            [[ -n "${line}" ]] || continue
            hit_lines["${line}"]=1
        done < <(printf '%s\n' "${json}" | jq -r --arg src "${src}" '
            .files[]
            | select((.file | tostring) == $src or (.file | tostring | endswith($src)))
            | .lines[]?
            | select((.count // 0) > 0)
            | .line_number
        ')
    done

    printf '%s %s\n' "${total}" "${#hit_lines[@]}"
}

shave_coverage_render() {
    local repo_root="$1"
    local table_file="$2"
    local logs_dir="$3"
    local build_dir="${4:-${repo_root}/build}"
    local work_dir="${5:-}"
    local layout_file
    local data_file
    local results_file="${table_file%.table}.results"
    local timestamp
    local gcno
    local src
    local stats
    local total
    local hit
    local pct
    local status
    local color
    local rows="["
    local first=1
    local sum_total=0
    local sum_hit=0
    local file_count=0
    local fail_count=0
    local -a gcda_dirs=()
    local -a gcnos=()

    if ! command -v gcov >/dev/null 2>&1; then
        echo "gcov not available" >&2
        return 1
    fi
    if ! command -v tables >/dev/null 2>&1; then
        echo "tables not available" >&2
        return 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo "jq not available" >&2
        return 1
    fi

    if [[ -z "${work_dir}" ]]; then
        work_dir="$(mktemp -d "${TMPDIR:-/tmp}/shave-coverage.XXXXXX")"
    fi
    layout_file="${work_dir}/layout.json"
    data_file="${work_dir}/data.json"
    mkdir -p "${work_dir}" "$(dirname "${table_file}")"

    mapfile -t gcda_dirs < <(shave_coverage_gcda_dirs "${logs_dir}")
    if [[ ${#gcda_dirs[@]} -eq 0 ]]; then
        echo "no gcov data from prior suites" >&2
        return 1
    fi

    timestamp="$(date '+%Y-%b-%d %H:%M:%S')"
    : > "${results_file}"
    mapfile -t gcnos < <(shave_coverage_find_gcno "${build_dir}")
    if [[ ${#gcnos[@]} -eq 0 ]]; then
        echo "no instrumented shave-libs objects" >&2
        return 1
    fi

    for gcno in "${gcnos[@]}"; do
        src=""
        src="$(shave_coverage_source_for_gcno "${gcno}" "${repo_root}")"
        [[ -n "${src}" && -f "${src}" ]] || continue
        stats=""
        stats="$(shave_coverage_file_stats "${src}" "${gcno}" "${work_dir}" "${gcda_dirs[@]}")"
        total="${stats%% *}"
        hit="${stats##* }"
        if [[ ! "${total}" =~ ^[0-9]+$ || "${total}" -eq 0 ]]; then
            continue
        fi
        if [[ ! "${hit}" =~ ^[0-9]+$ ]]; then
            hit=0
        fi
        file_count=$((file_count + 1))
        sum_total=$((sum_total + total))
        sum_hit=$((sum_hit + hit))
        pct="$(awk -v h="${hit}" -v t="${total}" 'BEGIN { printf "%.1f", (h * 100) / t }')"
        if (( hit * 100 / total >= SHAVE_COVERAGE_MIN )); then
            status="PASS"
            color="{GREEN}PASS{RESET}"
        else
            status="FAIL"
            color="{RED}FAIL{RESET}"
            fail_count=$((fail_count + 1))
        fi
        if [[ "${first}" -eq 0 ]]; then
            rows+=","
        fi
        first=0
        rows+="$(printf '{"section":%s,"file":%s,"lines":%s,"hit":%s,"coverage":%s,"status":%s}' \
            "$(shave_coverage_json_escape "libs")" \
            "$(shave_coverage_json_escape "${src#${repo_root}/}")" \
            "${total}" \
            "${hit}" \
            "$(shave_coverage_json_escape "${pct} %")" \
            "$(shave_coverage_json_escape "${color}")")"
        printf '%s|%s|%s|%s|%s\n' "${src#${repo_root}/}" "${total}" "${hit}" "${pct}" "${status}" >> "${results_file}"
    done

    if [[ "${file_count}" -eq 0 ]]; then
        echo "no instrumented shave-libs sources" >&2
        return 1
    fi

    pct="0.0"
    if [[ "${sum_total}" -gt 0 ]]; then
        pct="$(awk -v h="${sum_hit}" -v t="${sum_total}" 'BEGIN { printf "%.1f", (h * 100) / t }')"
    fi
    if [[ "${first}" -eq 0 ]]; then
        rows+=","
    fi
    color="{GREEN}{BOLD}PASS{RESET}"
    if [[ "${fail_count}" -gt 0 ]]; then
        color="{RED}{BOLD}FAIL{RESET}"
    fi
    rows+="$(printf '{"section":%s,"file":%s,"lines":%s,"hit":%s,"coverage":%s,"status":%s}' \
        "$(shave_coverage_json_escape "totals")" \
        "$(shave_coverage_json_escape "Totals")" \
        "${sum_total}" \
        "${sum_hit}" \
        "$(shave_coverage_json_escape "${pct} %")" \
        "$(shave_coverage_json_escape "${color}")")"
    rows+="]"

    cat > "${layout_file}" <<EOF
{
  "theme": "Red",
  "title": $(shave_coverage_json_escape "Shave gcov Coverage"),
  "title_position": "left",
  "footer": $(shave_coverage_json_escape "Minimum ${SHAVE_COVERAGE_MIN}%  ·  Generated ${timestamp}"),
  "footer_position": "right",
  "columns": [
    {"header": "Section", "key": "section", "datatype": "text", "visible": false, "break": true},
    {"header": "File", "key": "file", "datatype": "text", "justification": "left"},
    {"header": "Lines", "key": "lines", "datatype": "int", "justification": "right"},
    {"header": "Hit", "key": "hit", "datatype": "int", "justification": "right"},
    {"header": "Coverage", "key": "coverage", "datatype": "text", "justification": "right"},
    {"header": "Status", "key": "status", "datatype": "text", "justification": "center"}
  ]
}
EOF
    printf '%s\n' "${rows}" > "${data_file}"
    tables "${layout_file}" "${data_file}" > "${table_file}"
    if [[ "${fail_count}" -gt 0 ]]; then
        return 2
    fi
    return 0
}
