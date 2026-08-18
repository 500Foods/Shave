#!/bin/bash
# Shave Codegen: Walks the tree-sitter CST and emits C for supported Bash.
#
# CHANGELOG
# 1.0.3 - 2026-08-18 - Emit shave_wc for wc commands
# 1.0.1 - 2026-08-18 - Space-only double-quoted strings keep their spaces
# 1.0.0 - 2026-08-18 - CST walk for echo, printf, prefix env, and for-loops

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
: "${DEBUG_MODE:=false}"
# shellcheck source=./shave-output.sh  # Essential for logging and output handling
# shellcheck disable=SC1091  # File path is dynamically determined at runtime
. "$SCRIPT_DIR/shave-output.sh"

SHAVE_CST_N=0
SHAVE_CST_TYPE=()
SHAVE_CST_FIELD=()
SHAVE_CST_DEPTH=()
SHAVE_CST_SL=()
SHAVE_CST_SC=()
SHAVE_CST_EL=()
SHAVE_CST_EC=()
SHAVE_C_INDENT="    "
SHAVE_GEN_FOR=0
SHAVE_GEN_BUF=0
SHAVE_SRC_LINES=()
SHAVE_ARG_PK=()
SHAVE_ARG_PV=()
SHAVE_ARG_BUF=()

shave_c_escape() {
    local s="$1"
    local out=""
    local c
    local -i i
    local -i n
    n=${#s}
    for ((i = 0; i < n; i++)); do
        c="${s:i:1}"
        case "${c}" in
            \\) out+='\\' ;;
            \") out+='\"' ;;
            $'\n') out+='\n' ;;
            $'\r') out+='\r' ;;
            $'\t') out+='\t' ;;
            *) out+="${c}" ;;
        esac
    done
    printf '%s' "${out}"
}

shave_dquote_unescape() {
    local s="$1"
    local out=""
    local c
    local next
    local -i i
    local -i n
    n=${#s}
    for ((i = 0; i < n; i++)); do
        c="${s:i:1}"
        if [[ "${c}" == '\' ]] && (( i + 1 < n )); then
            next="${s:i+1:1}"
            case "${next}" in
                \\|\"|\$|\`)
                    out+="${next}"
                    i=$((i + 1))
                    ;;
                $'\n')
                    i=$((i + 1))
                    ;;
                *)
                    out+='\'
                    out+="${next}"
                    i=$((i + 1))
                    ;;
            esac
        else
            out+="${c}"
        fi
    done
    printf '%s' "${out}"
}

shave_source_slice() {
    local sl="$1"
    local sc="$2"
    local el="$3"
    local ec="$4"
    local out=""
    local line
    local -i i
    if (( sl == el )); then
        line="${SHAVE_SRC_LINES[sl]-}"
        printf '%s' "${line:sc:$((ec - sc))}"
        return 0
    fi
    line="${SHAVE_SRC_LINES[sl]-}"
    out="${line:sc}"
    for ((i = sl + 1; i < el; i++)); do
        out+=$'\n'
        out+="${SHAVE_SRC_LINES[i]-}"
    done
    line="${SHAVE_SRC_LINES[el]-}"
    out+=$'\n'
    out+="${line:0:ec}"
    printf '%s' "${out}"
}

shave_cst_load() {
    local -n _lines="$1"
    local line
    local leading
    local field
    local typ
    local sl
    local sc
    local el
    local ec
    SHAVE_CST_N=0
    SHAVE_CST_TYPE=()
    SHAVE_CST_FIELD=()
    SHAVE_CST_DEPTH=()
    SHAVE_CST_SL=()
    SHAVE_CST_SC=()
    SHAVE_CST_EL=()
    SHAVE_CST_EC=()
    for line in "${_lines[@]}"; do
        if [[ "${line}" =~ ^([[:space:]]*)(([A-Za-z_][A-Za-z0-9_]*):[[:space:]]*)?\(([A-Za-z_][A-Za-z0-9_]*)\ \[([0-9]+),\ ([0-9]+)\]\ -\ \[([0-9]+),\ ([0-9]+)\] ]]; then
            leading="${BASH_REMATCH[1]}"
            field="${BASH_REMATCH[3]}"
            typ="${BASH_REMATCH[4]}"
            sl="${BASH_REMATCH[5]}"
            sc="${BASH_REMATCH[6]}"
            el="${BASH_REMATCH[7]}"
            ec="${BASH_REMATCH[8]}"
            SHAVE_CST_DEPTH[SHAVE_CST_N]=$(( ${#leading} / 2 ))
            SHAVE_CST_FIELD[SHAVE_CST_N]="${field}"
            SHAVE_CST_TYPE[SHAVE_CST_N]="${typ}"
            SHAVE_CST_SL[SHAVE_CST_N]="${sl}"
            SHAVE_CST_SC[SHAVE_CST_N]="${sc}"
            SHAVE_CST_EL[SHAVE_CST_N]="${el}"
            SHAVE_CST_EC[SHAVE_CST_N]="${ec}"
            SHAVE_CST_N=$((SHAVE_CST_N + 1))
        fi
    done
}

shave_cst_children() {
    local parent="$1"
    local -n _kids="$2"
    local depth
    local -i i
    _kids=()
    if (( parent < 0 || parent >= SHAVE_CST_N )); then
        return 0
    fi
    depth="${SHAVE_CST_DEPTH[parent]}"
    for ((i = parent + 1; i < SHAVE_CST_N; i++)); do
        if (( SHAVE_CST_DEPTH[i] <= depth )); then
            break
        fi
        if (( SHAVE_CST_DEPTH[i] == depth + 1 )); then
            _kids+=("${i}")
        fi
    done
}

shave_cst_child_text() {
    local idx="$1"
    shave_source_slice "${SHAVE_CST_SL[idx]}" "${SHAVE_CST_SC[idx]}" "${SHAVE_CST_EL[idx]}" "${SHAVE_CST_EC[idx]}"
}

shave_eval_static_node() {
    local idx="$1"
    local typ="${SHAVE_CST_TYPE[idx]}"
    local text
    local inner
    local -a kids=()
    local kid
    local out=""
    case "${typ}" in
        word|number)
            shave_cst_child_text "${idx}"
            ;;
        raw_string)
            text=""
            text="$(shave_cst_child_text "${idx}")"
            if (( ${#text} >= 2 )); then
                printf '%s' "${text:1:$((${#text} - 2))}"
            fi
            ;;
        string)
            shave_cst_children "${idx}" kids
            for kid in "${kids[@]}"; do
                if [[ "${SHAVE_CST_TYPE[kid]}" == "simple_expansion" || "${SHAVE_CST_TYPE[kid]}" == "expansion" || "${SHAVE_CST_TYPE[kid]}" == "command_substitution" ]]; then
                    return 1
                fi
            done
            text=""
            text="$(shave_cst_child_text "${idx}")"
            if (( ${#text} >= 2 )) && [[ "${text:0:1}" == '"' && "${text: -1}" == '"' ]]; then
                inner="${text:1:$((${#text} - 2))}"
            else
                inner="${text}"
            fi
            printf '%s' "$(shave_dquote_unescape "${inner}")"
            ;;
        concatenation|simple_expansion|expansion)
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

shave_collect_expand_parts() {
    local idx="$1"
    local -n _kinds="$2"
    local -n _vals="$3"
    local typ="${SHAVE_CST_TYPE[idx]}"
    local text
    local inner
    local -a kids=()
    local -a inner_kids=()
    local kid
    local var_idx
    local varname
    case "${typ}" in
        word|number)
            text=""
            text="$(shave_cst_child_text "${idx}")"
            _kinds+=("lit")
            _vals+=("${text}")
            ;;
        raw_string)
            text=""
            text="$(shave_cst_child_text "${idx}")"
            if (( ${#text} >= 2 )); then
                text="${text:1:$((${#text} - 2))}"
            fi
            _kinds+=("lit")
            _vals+=("${text}")
            ;;
        string)
            shave_cst_children "${idx}" kids
            if [[ ${#kids[@]} -eq 0 ]]; then
                text=""
                text="$(shave_cst_child_text "${idx}")"
                if (( ${#text} >= 2 )) && [[ "${text:0:1}" == '"' && "${text: -1}" == '"' ]]; then
                    inner="${text:1:$((${#text} - 2))}"
                else
                    inner="${text}"
                fi
                _kinds+=("lit")
                _vals+=("$(shave_dquote_unescape "${inner}")")
            else
                for kid in "${kids[@]}"; do
                    if [[ "${SHAVE_CST_TYPE[kid]}" == "string_content" ]]; then
                        inner=""
                        inner="$(shave_cst_child_text "${kid}")"
                        _kinds+=("lit")
                        _vals+=("$(shave_dquote_unescape "${inner}")")
                    elif [[ "${SHAVE_CST_TYPE[kid]}" == "simple_expansion" || "${SHAVE_CST_TYPE[kid]}" == "expansion" ]]; then
                        varname=""
                        shave_cst_children "${kid}" inner_kids
                        for var_idx in "${inner_kids[@]}"; do
                            if [[ "${SHAVE_CST_TYPE[var_idx]}" == "variable_name" || "${SHAVE_CST_TYPE[var_idx]}" == "special_variable_name" ]]; then
                                varname="$(shave_cst_child_text "${var_idx}")"
                                break
                            fi
                        done
                        if [[ -z "${varname}" ]]; then
                            return 1
                        fi
                        _kinds+=("var")
                        _vals+=("${varname}")
                    else
                        return 1
                    fi
                done
            fi
            ;;
        simple_expansion|expansion)
            varname=""
            shave_cst_children "${idx}" kids
            for kid in "${kids[@]}"; do
                if [[ "${SHAVE_CST_TYPE[kid]}" == "variable_name" || "${SHAVE_CST_TYPE[kid]}" == "special_variable_name" ]]; then
                    varname="$(shave_cst_child_text "${kid}")"
                    break
                fi
            done
            if [[ -z "${varname}" ]]; then
                return 1
            fi
            _kinds+=("var")
            _vals+=("${varname}")
            ;;
        concatenation)
            shave_cst_children "${idx}" kids
            for kid in "${kids[@]}"; do
                if ! shave_collect_expand_parts "${kid}" _kinds _vals; then
                    return 1
                fi
            done
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

shave_emit_c_string() {
    local text="$1"
    local escaped
    escaped=""
    escaped="$(shave_c_escape "${text}")"
    printf '"%s"' "${escaped}"
}

shave_c_indent_push() {
    SHAVE_C_INDENT+="    "
}

shave_c_indent_pop() {
    SHAVE_C_INDENT="${SHAVE_C_INDENT%    }"
}

shave_encode_parts() {
    local -n _src="$1"
    local out=""
    local item
    for item in "${_src[@]}"; do
        out+="${item}"$'\x1e'
    done
    printf '%s' "${out}"
}

shave_emit_builtin_from_nodes() {
    local name="$1"
    shift
    local -a arg_nodes=("$@")
    local -a static_vals=()
    local -a dyn_flags=()
    local node
    local static
    local -a kinds=()
    local -a vals=()
    local -i i
    local -i j
    local -i argc
    local -i need_block=0
    local fn
    local buf
    local escaped
    local kind
    local val
    local -a pk=()
    local -a pv=()

    SHAVE_ARG_PK=()
    SHAVE_ARG_PV=()
    SHAVE_ARG_BUF=()

    static_vals+=("${name}")
    dyn_flags+=(0)
    SHAVE_ARG_PK+=("")
    SHAVE_ARG_PV+=("")

    for node in "${arg_nodes[@]}"; do
        static=""
        if static="$(shave_eval_static_node "${node}")"; then
            static_vals+=("${static}")
            dyn_flags+=(0)
            SHAVE_ARG_PK+=("")
            SHAVE_ARG_PV+=("")
            continue
        fi
        # shellcheck disable=SC2034
        # Justification: nameref used to return expansion parts to caller
        kinds=()
        # shellcheck disable=SC2034
        # Justification: nameref used to return expansion parts to caller
        vals=()
        if ! shave_collect_expand_parts "${node}" kinds vals; then
            return 1
        fi
        static_vals+=("")
        dyn_flags+=(1)
        need_block=1
        SHAVE_ARG_PK+=("$(shave_encode_parts kinds)")
        SHAVE_ARG_PV+=("$(shave_encode_parts vals)")
    done

    argc=${#static_vals[@]}
    if [[ "${name}" == "echo" ]]; then
        fn="shave_echo_builtin"
    elif [[ "${name}" == "printf" ]]; then
        fn="shave_printf_builtin"
    else
        fn="shave_wc"
    fi

    if (( need_block == 0 )); then
        printf '%sstatus |= %s(%s, (char *[]){' "${SHAVE_C_INDENT}" "${fn}" "${argc}"
        for ((i = 0; i < argc; i++)); do
            if (( i > 0 )); then
                printf ', '
            fi
            escaped=""
            escaped="$(shave_c_escape "${static_vals[i]}")"
            printf '"%s"' "${escaped}"
        done
        printf '});\n'
        return 0
    fi

    printf '%s{\n' "${SHAVE_C_INDENT}"
    shave_c_indent_push
    for ((i = 0; i < argc; i++)); do
        if (( dyn_flags[i] == 0 )); then
            continue
        fi
        SHAVE_GEN_BUF=$((SHAVE_GEN_BUF + 1))
        buf="shave_buf_${SHAVE_GEN_BUF}"
        SHAVE_ARG_BUF[i]="${buf}"
        printf '%schar %s[SHAVE_EXPAND_MAX];\n' "${SHAVE_C_INDENT}" "${buf}"
        printf '%s%s[0] = '\''\\0'\'';\n' "${SHAVE_C_INDENT}" "${buf}"
        IFS=$'\x1e' read -r -a pk <<< "${SHAVE_ARG_PK[i]}"
        IFS=$'\x1e' read -r -a pv <<< "${SHAVE_ARG_PV[i]}"
        for ((j = 0; j < ${#pk[@]}; j++)); do
            kind="${pk[j]}"
            val="${pv[j]}"
            [[ -n "${kind}" ]] || continue
            escaped=""
            escaped="$(shave_c_escape "${val}")"
            if [[ "${kind}" == "lit" ]]; then
                printf '%sshave_buf_add(%s, sizeof(%s), "%s");\n' "${SHAVE_C_INDENT}" "${buf}" "${buf}" "${escaped}"
            else
                printf '%sshave_buf_add(%s, sizeof(%s), shave_get_var("%s"));\n' "${SHAVE_C_INDENT}" "${buf}" "${buf}" "${escaped}"
            fi
        done
    done
    printf '%sstatus |= %s(%s, (char *[]){' "${SHAVE_C_INDENT}" "${fn}" "${argc}"
    for ((i = 0; i < argc; i++)); do
        if (( i > 0 )); then
            printf ', '
        fi
        if (( dyn_flags[i] )); then
            printf '%s' "${SHAVE_ARG_BUF[i]}"
        else
            escaped=""
            escaped="$(shave_c_escape "${static_vals[i]}")"
            printf '"%s"' "${escaped}"
        fi
    done
    printf '});\n'
    shave_c_indent_pop
    printf '%s}\n' "${SHAVE_C_INDENT}"
}

shave_emit_prefix_env() {
    local assign_idx="$1"
    local -a kids=()
    local kid
    local name=""
    local value=""
    shave_cst_children "${assign_idx}" kids
    for kid in "${kids[@]}"; do
        if [[ "${SHAVE_CST_FIELD[kid]}" == "name" || "${SHAVE_CST_TYPE[kid]}" == "variable_name" ]]; then
            name="$(shave_cst_child_text "${kid}")"
        elif [[ "${SHAVE_CST_FIELD[kid]}" == "value" ]]; then
            if ! value="$(shave_eval_static_node "${kid}")"; then
                return 1
            fi
        fi
    done
    if [[ -z "${name}" ]]; then
        return 1
    fi
    printf '%s{\n' "${SHAVE_C_INDENT}"
    shave_c_indent_push
    printf '%sconst char *shave_old_%s = getenv("%s");\n' "${SHAVE_C_INDENT}" "${name}" "${name}"
    printf '%s(void)setenv("%s", ' "${SHAVE_C_INDENT}" "${name}"
    shave_emit_c_string "${value}"
    printf ', 1);\n'
    if [[ "${name}" == "TZ" ]]; then
        printf '%stzset();\n' "${SHAVE_C_INDENT}"
    fi
    return 0
}

shave_emit_prefix_env_restore() {
    local assign_idx="$1"
    local -a kids=()
    local kid
    local name=""
    shave_cst_children "${assign_idx}" kids
    for kid in "${kids[@]}"; do
        if [[ "${SHAVE_CST_FIELD[kid]}" == "name" || "${SHAVE_CST_TYPE[kid]}" == "variable_name" ]]; then
            name="$(shave_cst_child_text "${kid}")"
        fi
    done
    if [[ -z "${name}" ]]; then
        return 1
    fi
    printf '%sif (shave_old_%s != NULL) {\n' "${SHAVE_C_INDENT}" "${name}"
    printf '%s    (void)setenv("%s", shave_old_%s, 1);\n' "${SHAVE_C_INDENT}" "${name}" "${name}"
    printf '%s} else {\n' "${SHAVE_C_INDENT}"
    printf '%s    (void)unsetenv("%s");\n' "${SHAVE_C_INDENT}" "${name}"
    printf '%s}\n' "${SHAVE_C_INDENT}"
    if [[ "${name}" == "TZ" ]]; then
        printf '%stzset();\n' "${SHAVE_C_INDENT}"
    fi
    shave_c_indent_pop
    printf '%s}\n' "${SHAVE_C_INDENT}"
}

shave_emit_command() {
    local idx="$1"
    local -a kids=()
    local -a assigns=()
    local -a args=()
    local -a name_kids=()
    local kid
    local name=""
    local name_idx=""
    local assign
    shave_cst_children "${idx}" kids
    for kid in "${kids[@]}"; do
        case "${SHAVE_CST_TYPE[kid]}" in
            variable_assignment)
                assigns+=("${kid}")
                ;;
            command_name)
                name_idx="${kid}"
                ;;
            *)
                if [[ "${SHAVE_CST_FIELD[kid]}" == "argument" ]]; then
                    args+=("${kid}")
                fi
                ;;
        esac
    done
    if [[ -n "${name_idx}" ]]; then
        shave_cst_children "${name_idx}" name_kids
        if [[ ${#name_kids[@]} -gt 0 ]]; then
            name="$(shave_eval_static_node "${name_kids[0]}" 2>/dev/null || shave_cst_child_text "${name_kids[0]}")"
        else
            name="$(shave_cst_child_text "${name_idx}")"
        fi
    fi
    if [[ "${name}" != "echo" && "${name}" != "printf" && "${name}" != "wc" ]]; then
        return 1
    fi
    for assign in "${assigns[@]}"; do
        if ! shave_emit_prefix_env "${assign}"; then
            return 1
        fi
    done
    if ! shave_emit_builtin_from_nodes "${name}" ${args[@]+"${args[@]}"}; then
        for assign in "${assigns[@]}"; do
            shave_c_indent_pop
            printf '%s}\n' "${SHAVE_C_INDENT}"
        done
        return 1
    fi
    for assign in "${assigns[@]}"; do
        shave_emit_prefix_env_restore "${assign}"
    done
    return 0
}

shave_emit_for() {
    local idx="$1"
    local -a kids=()
    local -a values=()
    local kid
    local varname=""
    local body=""
    local val
    local arr
    local nvals
    local -i i
    shave_cst_children "${idx}" kids
    for kid in "${kids[@]}"; do
        if [[ "${SHAVE_CST_FIELD[kid]}" == "variable" || "${SHAVE_CST_TYPE[kid]}" == "variable_name" ]]; then
            varname="$(shave_cst_child_text "${kid}")"
        elif [[ "${SHAVE_CST_FIELD[kid]}" == "value" ]]; then
            if ! val="$(shave_eval_static_node "${kid}")"; then
                return 1
            fi
            values+=("${val}")
        elif [[ "${SHAVE_CST_TYPE[kid]}" == "do_group" || "${SHAVE_CST_FIELD[kid]}" == "body" ]]; then
            body="${kid}"
        fi
    done
    if [[ -z "${varname}" || -z "${body}" ]]; then
        return 1
    fi
    SHAVE_GEN_FOR=$((SHAVE_GEN_FOR + 1))
    arr="shave_for_${SHAVE_GEN_FOR}"
    nvals=${#values[@]}
    printf '%s{\n' "${SHAVE_C_INDENT}"
    shave_c_indent_push
    printf '%sconst char *%s[] = {' "${SHAVE_C_INDENT}" "${arr}"
    for ((i = 0; i < nvals; i++)); do
        if (( i > 0 )); then
            printf ', '
        fi
        shave_emit_c_string "${values[i]}"
    done
    if (( nvals == 0 )); then
        printf 'NULL'
    fi
    printf '};\n'
    printf '%sconst int %s_n = %s;\n' "${SHAVE_C_INDENT}" "${arr}" "${nvals}"
    printf '%sint %s_i;\n' "${SHAVE_C_INDENT}" "${arr}"
    printf '%sfor (%s_i = 0; %s_i < %s_n; %s_i++) {\n' "${SHAVE_C_INDENT}" "${arr}" "${arr}" "${arr}" "${arr}"
    shave_c_indent_push
    printf '%sshave_set_var("%s", %s[%s_i]);\n' "${SHAVE_C_INDENT}" "${varname}" "${arr}" "${arr}"
    if ! shave_emit_do_group "${body}"; then
        shave_c_indent_pop
        printf '%s}\n' "${SHAVE_C_INDENT}"
        shave_c_indent_pop
        printf '%s}\n' "${SHAVE_C_INDENT}"
        return 1
    fi
    shave_c_indent_pop
    printf '%s}\n' "${SHAVE_C_INDENT}"
    shave_c_indent_pop
    printf '%s}\n' "${SHAVE_C_INDENT}"
    return 0
}

shave_emit_do_group() {
    local idx="$1"
    local -a kids=()
    local kid
    shave_cst_children "${idx}" kids
    for kid in "${kids[@]}"; do
        if ! shave_emit_statement "${kid}"; then
            return 1
        fi
    done
    return 0
}

shave_emit_fallback_line() {
    local idx="$1"
    local text
    local escaped
    text=""
    text="$(shave_cst_child_text "${idx}")"
    escaped=""
    escaped="$(shave_c_escape "${text}")"
    printf '%s/* unsupported: emitted source text */\n' "${SHAVE_C_INDENT}"
    printf '%s(void)printf("%%s\\n", "%s");\n' "${SHAVE_C_INDENT}" "${escaped}"
}

shave_emit_statement() {
    local idx="$1"
    local typ="${SHAVE_CST_TYPE[idx]}"
    case "${typ}" in
        comment)
            return 0
            ;;
        command)
            if shave_emit_command "${idx}"; then
                return 0
            fi
            shave_emit_fallback_line "${idx}"
            ;;
        for_statement)
            if shave_emit_for "${idx}"; then
                return 0
            fi
            shave_emit_fallback_line "${idx}"
            ;;
        do_group)
            shave_emit_do_group "${idx}"
            ;;
        *)
            shave_emit_fallback_line "${idx}"
            ;;
    esac
}

shave_generate_from_cst() {
    local input_script="$1"
    local -a kids=()
    local kid
    local program=""
    local -i i
    SHAVE_C_INDENT="    "
    SHAVE_GEN_FOR=0
    SHAVE_GEN_BUF=0
    for ((i = 0; i < SHAVE_CST_N; i++)); do
        if [[ "${SHAVE_CST_TYPE[i]}" == "program" ]]; then
            program="${i}"
            break
        fi
    done
    if [[ -z "${program}" ]]; then
        return 1
    fi
    printf '    // Generated content from %s\n' "${input_script}"
    shave_cst_children "${program}" kids
    for kid in "${kids[@]}"; do
        shave_emit_statement "${kid}"
    done
    return 0
}

shave_tokenize_words() {
    local line="$1"
    local -n _out="$2"
    local -i i=0
    local -i n=${#line}
    local c
    local next
    local word=""
    local -i in_squote=0
    local -i in_dquote=0
    local -i had_token=0

    _out=()
    while (( i < n )); do
        c="${line:i:1}"
        if (( in_squote )); then
            if [[ "${c}" == "'" ]]; then
                in_squote=0
            else
                word+="${c}"
            fi
            i=$((i + 1))
            continue
        fi
        if (( in_dquote )); then
            if [[ "${c}" == '\' ]] && (( i + 1 < n )); then
                next="${line:i+1:1}"
                case "${next}" in
                    \\|\"|\$|\`)
                        word+="${next}"
                        ;;
                    $'\n')
                        ;;
                    *)
                        word+='\'
                        word+="${next}"
                        ;;
                esac
                i=$((i + 2))
                continue
            fi
            if [[ "${c}" == '"' ]]; then
                in_dquote=0
                i=$((i + 1))
                continue
            fi
            word+="${c}"
            i=$((i + 1))
            continue
        fi
        case "${c}" in
            [[:space:]])
                if (( had_token )); then
                    _out+=("${word}")
                    word=""
                    had_token=0
                fi
                i=$((i + 1))
                ;;
            "'")
                in_squote=1
                had_token=1
                i=$((i + 1))
                ;;
            '"')
                in_dquote=1
                had_token=1
                i=$((i + 1))
                ;;
            '\\')
                if (( i + 1 < n )); then
                    word+="${line:i+1:1}"
                    had_token=1
                    i=$((i + 2))
                else
                    word+='\'
                    had_token=1
                    i=$((i + 1))
                fi
                ;;
            *)
                word+="${c}"
                had_token=1
                i=$((i + 1))
                ;;
        esac
    done
    if (( had_token )); then
        _out+=("${word}")
    fi
}

shave_emit_words_builtin() {
    local -n _args="$1"
    local name="${_args[0]-}"
    local fn
    local -i argc
    local -i i
    local escaped
    argc=${#_args[@]}
    if [[ "${name}" == "echo" ]]; then
        fn="shave_echo_builtin"
    elif [[ "${name}" == "printf" ]]; then
        fn="shave_printf_builtin"
    else
        fn="shave_wc"
    fi
    printf '    status |= %s(%s, (char *[]){' "${fn}" "${argc}"
    for ((i = 0; i < argc; i++)); do
        escaped=""
        escaped="$(shave_c_escape "${_args[i]}")"
        if (( i > 0 )); then
            printf ', '
        fi
        printf '"%s"' "${escaped}"
    done
    printf '});\n'
}

shave_generate_from_lines() {
    local input_script="$1"
    local -n _src="$2"
    local line
    local trimmed
    local escaped_line
    local -a words
    printf '    // Generated content from %s\n' "${input_script}"
    for line in "${_src[@]}"; do
        trimmed="${line#"${line%%[![:space:]]*}"}"
        if [[ -z "${trimmed}" || "${trimmed}" == \#* ]]; then
            continue
        fi
        shave_tokenize_words "${trimmed}" words
        if [[ ${#words[@]} -gt 0 && ( "${words[0]}" == "echo" || "${words[0]}" == "printf" || "${words[0]}" == "wc" ) ]]; then
            shave_emit_words_builtin words
            continue
        fi
        escaped_line=""
        escaped_line="$(shave_c_escape "${line}")"
        printf '    (void)printf("%%s\\n", "%s");\n' "${escaped_line}"
    done
}

# Generate C statements for a Bash script. Writes to stdout.
# $1 = input script path (for comments)
# $2 = name of script_content array
# $3 = name of cst_data array
shave_generate_c() {
    local input_script="$1"
    local src_name="$2"
    local cst_name="$3"
    SHAVE_SRC_LINES=()
    eval "SHAVE_SRC_LINES=(\"\${${src_name}[@]}\")"
    shave_cst_load "${cst_name}"
    if (( SHAVE_CST_N > 0 )); then
        shave_generate_from_cst "${input_script}"
        return 0
    fi
    shave_generate_from_lines "${input_script}" "${src_name}"
}
