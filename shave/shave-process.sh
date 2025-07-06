#!/bin/bash
# Shave Process: Processes Bash scripts to generate C code, handling recursive sourcing.

# Source the output handling script and other modular components
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./shave-output.sh
# shellcheck source=./shave-reader.sh
# shellcheck source=./shave-parser.sh
# shellcheck source=./shave-combiner.sh
# shellcheck source=./shave-validate.sh
# shellcheck disable=SC1091
# Note: shellcheck may report SC1091 as the file paths are dynamically determined
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

# Function to process a script, including validation and recursive handling of sourced files
process() {
    local input_script="$1"
    local c_source_file="$2"
    local recursion_depth="${3:-0}"
    
    # Check recursion depth
    if [[ "$recursion_depth" -ge "$MAX_RECURSION_DEPTH" ]]; then
        log_output "warn" "Maximum recursion depth ($MAX_RECURSION_DEPTH) reached for '$input_script'. Skipping."
        return 1
    fi
    
    # Removed duplicate log entry for processing script step
    # log_output "step" "Processing script '$input_script' (Depth: $recursion_depth)"
    
    # Validate the script and gather statistics
    declare -A file_stats
    if ! validate_script "$input_script" "file_stats"; then
        log_output "fail" "Validation failed for '$input_script'. Skipping processing."
        return 1
    fi
    
    # Emit FILE log line after validation
    log_output "file" "[Depth: $recursion_depth] $input_script"
    
    # If this is the initial script (depth 0), generate the C boilerplate after validation
    if [[ "$recursion_depth" -eq 0 ]]; then
        log_output "step" "Generating C Boilerplate"
        local input_file_full_path=$(realpath "$input_script" 2>/dev/null || readlink -f "$input_script" 2>/dev/null)
        generate_c_boilerplate "$c_source_file" "$input_file_full_path" "$input_script" "${file_stats[size]}" "${file_stats[lines]}" "${file_stats[timestamp]}" "$SHAVE_SCRIPT_NAME" "$SHAVE_SCRIPT_VERSION"
    fi
    
    # Read script content
    log_output "step" "Read Script Content for '$input_script'"
    local -a script_content
    if ! read_script_content "$input_script" script_content; then
        log_output "fail" "Failed to read content from '$input_script'."
        return 1
    fi
    
    
    # Generate CST
    log_output "step" "Generating Concrete Syntax Tree (CST) for '$input_script'"
    local -a cst_data
    if ! generate_cst "$input_script" cst_data; then
        log_output "warn" "Failed to generate CST for '$input_script'. Proceeding with content only."
    else
        # If in debug mode, log the CST file location using the global variable set in generate_cst
        if [[ "$DEBUG_MODE" == "true" && -n "$CST_DEBUG_FILE" ]]; then
            log_output "info" "Debug mode: CST data saved to $CST_DEBUG_FILE"
        fi
        log_output "pass" "Concrete Syntax Tree (CST) generated"
    fi
    
    # Combine content and CST
    log_output "step" "Correlating CST and Script data for '$input_script'"
    local -A combined_data
    if ! combine_content_cst "script_content" "cst_data" "combined_data"; then
        log_output "fail" "Failed to correlate CST and script data for '$input_script'."
        return 1
    fi
    # If in debug mode, log the combined data file location using the global variable set in combine_content_cst
    if [[ "$DEBUG_MODE" == "true" && -n "$COMBINED_DEBUG_FILE" ]]; then
        log_output "info" "Debug mode: Combined data saved to $COMBINED_DEBUG_FILE"
    fi
    log_output "pass" "Correlated script content and CST data into unified structure."
    
    # Generate C code from combined data
    log_output "step" "Generating C code for '$input_script'"
    # Create a temporary file for the generated code
    local temp_code=$(mktemp /tmp/shave-code.XXXXXX)
    {
        echo "    // Generated content from $input_script"
        local i
        for ((i=0; i<${#script_content[@]}; i++)); do
            local line="${script_content[$i]}"
            # Escape special characters in the line for C string
            local escaped_line=$(printf '%s\n' "$line" | sed 's/[\/&]/\\&/g' | sed 's/"/\\"/g')
            printf "    printf(\"%%s\\\\n\", \"%s\");\n" "$escaped_line"
        done
    } > "$temp_code"
    
    # Insert the generated code between Script start and Script end markers
    if grep -q "// Script start - Additional generated code will be inserted here" "$c_source_file"; then
        sed -i '/\/\/ Script start - Additional generated code will be inserted here/r '"$temp_code" "$c_source_file"
        log_output "pass" "Generated C code for '$input_script' inserted into temporary C file between markers."
    else
        log_output "warn" "Marker not found in temporary C file. Appending code inside main function as fallback."
        # Fallback: Append after the start of main if marker not found
        sed -i '/int main(int argc, char \*argv\[\]) {/r '"$temp_code" "$c_source_file"
    fi
    rm -f "$temp_code"
    
    # Scan for sourced files (source or . commands)
    log_output "info" "Scanning '$input_script' for sourced files."
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
                local base_dir=$(dirname "$input_script")
                sourced_path="$base_dir/$sourced_path"
            fi
            # Attempt to resolve the path to an absolute path
            local resolved_path=$(realpath "$sourced_path" 2>/dev/null || readlink -f "$sourced_path" 2>/dev/null)
            if [[ -n "$resolved_path" ]]; then
                sourced_path="$resolved_path"
            fi
            sourced_files+=("$sourced_path")
            log_output "info" "Found sourced file '$sourced_path' at line $line_num in '$input_script'."
        fi
    done
    
    # Process sourced files recursively
    for sourced_file in "${sourced_files[@]}"; do
        if [[ -f "$sourced_file" ]]; then
            log_output "step" "Recursively processing sourced file '$sourced_file'."
            process "$sourced_file" "$c_source_file" $((recursion_depth + 1))
        else
            log_output "warn" "Sourced file '$sourced_file' not found. Skipping."
        fi
    done
    
    return 0
}
