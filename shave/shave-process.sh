#!/bin/bash
# Shave Process: Processes Bash scripts to generate C code, handling recursive sourcing.
#
# CHANGELOG
# 1.1.0 - 2026-08-18 - Emit shave_echo_builtin calls for Bash echo lines
# 1.0.1 - 2026-08-18 - Default DEBUG_MODE and script metadata for shellcheck
# 1.0.0 - Initial process module

# Source the output handling script and other modular components
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
: "${DEBUG_MODE:=false}"
: "${SHAVE_SCRIPT_NAME:=shave}"
: "${SHAVE_SCRIPT_VERSION:=0.0.0}"
# shellcheck source=./shave-output.sh  # Essential for logging and output handling
# shellcheck source=./shave-reader.sh  # Reads script content into arrays
# shellcheck source=./shave-parser.sh  # Parses Bash scripts for conversion
# shellcheck source=./shave-combiner.sh  # Combines content and CST data
# shellcheck source=./shave-validate.sh  # Validates script syntax and status
# shellcheck disable=SC1091  # File paths are dynamically determined at runtime
for script in "$SCRIPT_DIR/shave-output.sh" "$SCRIPT_DIR/shave-reader.sh" "$SCRIPT_DIR/shave-parser.sh" "$SCRIPT_DIR/shave-combiner.sh" "$SCRIPT_DIR/shave-validate.sh"; do
    if [ -f "$script" ]; then
        . "$script"
    else
        echo "Error: Script $script not found"
        exit 1
    fi
done

# Maximum recursion depth to prevent infinite loops
MAX_RECURSION_DEPTH=10

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
                word+="${next}"
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

shave_emit_echo_c() {
    local -n _args="$1"
    local -i argc
    local -i i
    local escaped
    argc=${#_args[@]}
    printf '    status |= shave_echo_builtin(%s, (char *[]){' "${argc}"
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

# Function to process a script, including validation and recursive handling of sourced files
process() {
    local input_script="$1"
    local c_source_file="$2"
    local recursion_depth="${3:-0}"
    
    # Check recursion depth
    if [[ "$recursion_depth" -ge "$MAX_RECURSION_DEPTH" ]]; then
        log_output "warn" "Maximum recursion depth ($MAX_RECURSION_DEPTH) reached for '$input_script'. Skipping"
        return 1
    fi
    
    # Removed duplicate log entry for processing script step
    # log_output "step" "Processing script '$input_script' (Depth: $recursion_depth)"
    
    # Validate the script and gather statistics
    declare -A file_stats
    if ! validate_script "$input_script" "file_stats"; then
        log_output "fail" "Validation failed for '$input_script'. Skipping processing"
        return 1
    fi
    
    # Emit FILE log line after validation
    log_output "file" "[Depth: $recursion_depth] $input_script"
    
    # If this is the initial script (depth 0), generate the C boilerplate after validation
    if [[ "$recursion_depth" -eq 0 ]]; then
        log_output "step" "Generating C Boilerplate"
        local input_file_full_path
    input_file_full_path=$(realpath "$input_script" 2>/dev/null || readlink -f "$input_script" 2>/dev/null)
        generate_c_boilerplate "$c_source_file" "$input_file_full_path" "$input_script" "${file_stats[size]}" "${file_stats[lines]}" "${file_stats[timestamp]}" "$SHAVE_SCRIPT_NAME" "$SHAVE_SCRIPT_VERSION"
    fi
    
    # Read script content
    log_output "step" "Read Script Content for '$input_script'"
    local -a script_content
    if ! read_script_content "$input_script" script_content; then
        log_output "fail" "Failed to read content from '$input_script'"
        return 1
    fi
    
    
    # Generate CST
    log_output "step" "Generating Concrete Syntax Tree (CST) for '$input_script'"
    # shellcheck disable=SC2034  # Variable kept for compatibility, appears unused to shellcheck
    local -a cst_data  # Unused but kept for compatibility
    if ! generate_cst "$input_script" cst_data; then
        log_output "warn" "Failed to generate CST for '$input_script'. Proceeding with content only"
    else
        # If in debug mode, log the CST file location using the global variable set in generate_cst
        if [[ "$DEBUG_MODE" == "true" && -n "$CST_DEBUG_FILE" ]]; then
            log_output "info" "Debug mode: CST data saved to $CST_DEBUG_FILE"
        fi
        log_output "pass" "Concrete Syntax Tree (CST) generated"
    fi
    
    # Combine content and CST
    log_output "step" "Correlating CST and Script data for '$input_script'"
    # shellcheck disable=SC2034  # Variable kept for compatibility, appears unused to shellcheck
    local -A combined_data  # Unused but kept for compatibility
    if ! combine_content_cst "script_content" "cst_data" "combined_data"; then
        log_output "fail" "Failed to correlate CST and script data for '$input_script'"
        return 1
    fi
    # If in debug mode, log the combined data file location using the global variable set in combine_content_cst
    if [[ "$DEBUG_MODE" == "true" && -n "$COMBINED_DEBUG_FILE" ]]; then
        log_output "info" "Debug mode: Combined data saved to $COMBINED_DEBUG_FILE"
    fi
    log_output "pass" "Correlated script content and CST data into unified structure"
    
    # Generate C code from combined data
    log_output "step" "Generating C code for '$input_script'"
    # Create a temporary file for the generated code
    local temp_code
    temp_code=$(mktemp /tmp/shave-code.XXXXXX)
    {
        echo "    // Generated content from $input_script"
        local i
        local line
        local trimmed
        local escaped_line
        local -a words
        for ((i=0; i<${#script_content[@]}; i++)); do
            line="${script_content[$i]}"
            trimmed="${line#"${line%%[![:space:]]*}"}"
            if [[ -z "${trimmed}" || "${trimmed}" == \#* ]]; then
                continue
            fi
            shave_tokenize_words "${trimmed}" words
            if [[ ${#words[@]} -gt 0 && "${words[0]}" == "echo" ]]; then
                shave_emit_echo_c words
                continue
            fi
            escaped_line=""
            escaped_line=$(printf '%s\n' "$line" | sed 's/[\/&]/\\&/g' | sed 's/"/\\"/g')
            printf "    printf(\"%%s\\\\n\", \"%s\");\n" "$escaped_line"
        done
    } > "$temp_code"
    
    # Insert the generated code between Script start and Script end markers
    if grep -q "// Script start - Additional generated code will be inserted here" "$c_source_file"; then
        sed -i '/\/\/ Script start - Additional generated code will be inserted here/r '"$temp_code" "$c_source_file"
        log_output "pass" "Generated C code for '$input_script' inserted into temporary C file between markers"
    else
        log_output "warn" "Marker not found in temporary C file. Appending code inside main function as fallback"
        # Fallback: Append after the start of main if marker not found
        sed -i '/int main(int argc, char \*argv\[\]) {/r '"$temp_code" "$c_source_file"
    fi
    rm -f "$temp_code"
    
    # Scan for sourced files (source or . commands)
    log_output "info" "Scanning '$input_script' for sourced files"
    local sourced_files=()
    local line_num=0
    for line in "${script_content[@]}"; do
        ((line_num++))
        if [[ "$line" =~ ^[[:space:]]*(\.|source)[[:space:]]+([^[:space:]]+) ]]; then
            local sourced_path="${BASH_REMATCH[2]}"
            # Remove quotes if present
            sourced_path="${sourced_path//\"/}"
            sourced_path="${sourced_path//\'/}"
            # Attempt to resolve variables in the path (basic handling for common variables)
            if [[ "$sourced_path" =~ \$SCRIPT_DIR ]]; then
                sourced_path="${sourced_path//\$SCRIPT_DIR/$SCRIPT_DIR}"
            elif [[ "$sourced_path" =~ \$\{SCRIPT_DIR\} ]]; then
                sourced_path="${sourced_path//\$\{SCRIPT_DIR\}/$SCRIPT_DIR}"
            fi
            # Check if it's a relative path
            if [[ ! "$sourced_path" =~ ^/ ]]; then
                local base_dir
                base_dir=$(dirname "$input_script")
                sourced_path="${base_dir}/${sourced_path}"
            fi
            # Attempt to resolve the path to an absolute path
            local resolved_path
            resolved_path=$(realpath "$sourced_path" 2>/dev/null || readlink -f "$sourced_path" 2>/dev/null)
            if [[ -n "$resolved_path" ]]; then
                sourced_path="$resolved_path"
            fi
            sourced_files+=("$sourced_path")
            log_output "info" "Found sourced file '$sourced_path' at line $line_num in '$input_script'"
        fi
    done
    
    # Process sourced files recursively
    for sourced_file in "${sourced_files[@]}"; do
        if [[ -f "$sourced_file" ]]; then
            log_output "step" "Recursively processing sourced file '$sourced_file'"
            process "$sourced_file" "$c_source_file" $((recursion_depth + 1))
        else
            log_output "warn" "Sourced file '$sourced_file' not found. Skipping"
        fi
    done
    
    return 0
}
