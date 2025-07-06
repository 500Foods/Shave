#!/bin/bash
# Shave Parser: Reads and processes Bash script input for C code generation.

# Source the output handling script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./shave-output.sh  # Essential for logging and output handling
# shellcheck disable=SC1091  # File path is dynamically determined at runtime
. "$SCRIPT_DIR/shave-output.sh"

# Deprecated function - kept for reference, replaced by new modular processing
# parse_bash_to_c() {
#     local input_script="$1"
#     local c_source_file="$2"
#     
#     # Check if input file exists
#     if [[ ! -f "$input_script" ]]; then
#         log_output "fail" "Input script '$input_script' not found."
#         return 1
#     fi
#     
#     # Read the input script and generate printf statements for each line
#     log_output "info" "Processing '$input_script' into C code..."
#     # Create a temporary file for the generated code
#     temp_code=$(mktemp /tmp/shave-code.XXXXXX)
#     {
#         echo "    // Generated content from $input_script"
#         while IFS= read -r line; do
#             # Escape special characters in the line for C string
#             escaped_line=$(printf '%s\n' "$line" | sed 's/[\/&]/\\&/g' | sed 's/"/\\"/g')
#             printf "    printf(\"%%s\\\\n\", \"%s\");\n" "$escaped_line"
#         done < "$input_script"
#     } > "$temp_code"
#     
#     # Insert the generated code between Script start and Script end markers
#     sed -i '/\/\/ Script start - Additional generated code will be inserted here/r '"$temp_code" "$c_source_file"
#     rm -f "$temp_code"
#     
#     log_output "pass" "Inserted parsed content into $c_source_file between markers"
#     return 0
# }

# Function to generate CST from a Bash script using tree-sitter if available
generate_cst() {
    local input_script="$1"
    local -n cst_array_ref="$2"  # Nameref to return the regular array
    
    # Initialize the CST array as a regular array
    local -a cst_array
    local node_count=0
    
    if command -v tree-sitter >/dev/null 2>&1; then
        local tree_sitter_output
        tree_sitter_output=$(tree-sitter parse "$input_script" 2> /tmp/shave-tree-sitter-error.log)
        local tree_sitter_status=$?
        if (( tree_sitter_status == 0 )); then
            local parse_line_count
            parse_line_count=$(echo "$tree_sitter_output" | wc -l | awk '{print $1}')
            # Parse CST output into a regular array
            IFS=$'\n' read -d '' -r -a cst_lines <<< "$tree_sitter_output"
            for line in "${cst_lines[@]}"; do
                # Match lines with optional labels (like "name:" or "argument:") followed by node syntax
                if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*)??\(([a-zA-Z_][a-zA-Z0-9_]*)\ \[([0-9]+),\ ([0-9]+)\]\ -\ \[([0-9]+),\ ([0-9]+)\] ]]; then
                    # Store only the original tree-sitter output with proper indentation
                    cst_array[node_count]="$line"
                    ((node_count++))
                fi
            done
            log_output "info" "tree-sitter parsed '$input_script': $(format_number "$node_count") CST nodes from $(format_number "$parse_line_count") lines of output"
            # If in debug mode, save CST data to a temporary file
            if [[ "$DEBUG_MODE" == "true" ]]; then
                local temp_cst_file
                temp_cst_file=$(mktemp /tmp/shave-cst.XXXXXX.cst)
                {
                    echo "CST Data Array:"
                    echo "---------------"
                    local i
                    for i in "${!cst_array[@]}"; do
                        echo "[$i]: ${cst_array[$i]}"
                    done
                } > "$temp_cst_file"
                # Store the filename in a global variable to be accessed by the calling script
                # shellcheck disable=SC2034  # Variable kept for compatibility with calling scripts
                CST_DEBUG_FILE="$temp_cst_file"
                # Log will be handled in the calling script to avoid duplicates
            fi
        else
            log_output "warn" "tree-sitter parsing failed. See errors in /tmp/shave-tree-sitter-error.log for details"
        fi
    else
        log_output "warn" "tree-sitter is not installed. Skipping CST generation"
    fi
    
    # Assign the local array to the nameref to return it
    # shellcheck disable=SC2034  # Nameref used to return array to caller, appears unused to shellcheck
    cst_array_ref=("${cst_array[@]}")
    return 0
}
