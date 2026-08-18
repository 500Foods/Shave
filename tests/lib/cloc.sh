#!/usr/bin/env bash
# CLOC table helper adapted from Hydrogen's cloc_tables flow
#
# CHANGELOG
# 1.0.3 - 2026-08-18 - Drop retired oldtests exclude
# 1.0.2 - 2026-08-18 - Exclude vendored Unity under tests/unity/framework
# 1.0.1 - 2026-08-18 - Escape JSON in bash; Python is banned
# 1.0.0 - 2026-08-18 - Lean cloc-to-tables renderer for Shave

if [[ -n "${SHAVE_CLOC_GUARD:-}" ]]; then
    return 0
fi
SHAVE_CLOC_GUARD=1

shave_cloc_json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '"%s"' "${s}"
}

shave_cloc_exclude_list() {
    local ignore_file="${1:-.lintignore}"
    local out_file="$2"
    local pattern
    : > "${out_file}"
    if [[ -f "${ignore_file}" ]]; then
        while IFS= read -r pattern; do
            pattern="${pattern%%#*}"
            pattern="${pattern#"${pattern%%[![:space:]]*}"}"
            pattern="${pattern%"${pattern##*[![:space:]]}"}"
            [[ -z "${pattern}" ]] && continue
            printf '%s\n' "${pattern%/\*}" >> "${out_file}"
        done < "${ignore_file}"
    fi
}

shave_cloc_render() {
    local repo_root="$1"
    local table_file="$2"
    local ignore_file="${3:-${repo_root}/.lintignore}"
    local exclude_list
    local cloc_json
    local layout_file
    local data_file
    local cloc_header
    local timestamp

    if ! command -v cloc >/dev/null 2>&1; then
        echo "cloc not available" >&2
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

    exclude_list="$(mktemp)"
    cloc_json="$(mktemp)"
    layout_file="$(mktemp)"
    data_file="$(mktemp)"
    # shellcheck disable=SC2064
    # Justification: temp paths are fixed for this invocation
    trap 'rm -f "${exclude_list}" "${cloc_json}" "${layout_file}" "${data_file}"' RETURN

    shave_cloc_exclude_list "${ignore_file}" "${exclude_list}"
    timestamp="$(date '+%Y-%b-%d %H:%M:%S')"

    if ! (
        cd "${repo_root}" || exit 1
        env LC_ALL=en_US.UTF_8 cloc . --quiet --json \
            --exclude-list-file="${exclude_list}" \
            --not-match-d='build' \
            --not-match-d='tests/unity/framework' \
            --force-lang=C,c --force-lang=C,h \
            > "${cloc_json}"
    ); then
        echo "cloc command failed" >&2
        return 1
    fi

    cloc_header="$(jq -r '.header | if type == "object" then "\(.cloc_url) v \(.cloc_version)" else . end // "cloc"' "${cloc_json}" 2>/dev/null || echo "cloc")"

    cat > "${layout_file}" <<EOF
{
  "theme": "Red",
  "title": $(shave_cloc_json_escape "${cloc_header}"),
  "title_position": "left",
  "footer": $(shave_cloc_json_escape "Generated ${timestamp}"),
  "footer_position": "right",
  "columns": [
    {"header": "Section", "key": "section", "datatype": "text", "visible": false, "break": true},
    {"header": "Language", "key": "language", "datatype": "text", "justification": "left"},
    {"header": "Files", "key": "files", "datatype": "int", "justification": "right"},
    {"header": "Blank", "key": "blank", "datatype": "int", "justification": "right"},
    {"header": "Comment", "key": "comment", "datatype": "int", "justification": "right"},
    {"header": "Code", "key": "code", "datatype": "int", "justification": "right"},
    {"header": "C/C %", "key": "comment_code_percentage", "datatype": "text", "justification": "right"},
    {"header": "Lines", "key": "lines", "datatype": "int", "justification": "right"}
  ]
}
EOF

    jq '
      def pct:
        if (.code // 0) > 0 and (.comment // 0) > 0
        then (((.comment // 0) / (.code // 0) * 100 * 10 | round / 10 | tostring) + " %")
        else ""
        end;
      def row($section; $name; $entry):
        {
          section: $section,
          language: $name,
          files: ($entry.nFiles // 0),
          blank: ($entry.blank // 0),
          comment: ($entry.comment // 0),
          code: ($entry.code // 0),
          comment_code_percentage: ($entry | pct),
          lines: (($entry.blank // 0) + ($entry.comment // 0) + ($entry.code // 0))
        };
      . as $root
      | [
          (if $root.C then row("primary"; "C/Headers"; $root.C) else empty end),
          (if $root["Bourne Shell"] then row("primary"; "Bourne Shell"; $root["Bourne Shell"]) else empty end),
          (if $root.CMake then row("primary"; "CMake"; $root.CMake) else empty end),
          (if $root.Markdown then row("secondary"; "Markdown"; $root.Markdown) else empty end),
          ($root
            | to_entries[]
            | select(.key != "header" and .key != "SUM" and .key != "C" and .key != "Bourne Shell" and .key != "CMake" and .key != "Markdown")
            | row("secondary"; .key; .value))
        ]
      | map(select(. != null))
      | sort_by(.section, -.lines)
      + [{
          section: "totals",
          language: "Totals",
          files: (map(.files) | add),
          blank: (map(.blank) | add),
          comment: (map(.comment) | add),
          code: (map(.code) | add),
          comment_code_percentage: (
            if (map(.code) | add) > 0 and (map(.comment) | add) > 0
            then (((map(.comment) | add) / (map(.code) | add) * 100 * 10 | round / 10 | tostring) + " %")
            else ""
            end
          ),
          lines: (map(.lines) | add)
        }]
    ' "${cloc_json}" > "${data_file}"

    tables "${layout_file}" "${data_file}" > "${table_file}"
}
