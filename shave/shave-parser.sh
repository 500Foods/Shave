#!/bin/bash
# Shave Parser: Reads and processes Bash script input for C code generation.

# Source the output handling script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./shave-output.sh
. "$SCRIPT_DIR/shave-output.sh"

# Function to parse Bash script and generate C code snippet
parse_bash_to_c() {
    local input_script="$1"
    local c_source_file="$2"
    
    # Check if input file exists
    if [[ ! -f "$input_script" ]]; then
        log_output "fail" "Input script '$input_script' not found."
        return 1
    fi
    
    # Read the input script and generate printf statements for each line
    log_output "info" "Processing '$input_script' into C code..."
    # Create a temporary file for the generated code
    temp_code=$(mktemp /tmp/shave-code.XXXXXX)
    {
        echo "    // Generated content from $input_script"
        while IFS= read -r line; do
            # Escape special characters in the line for C string
            escaped_line=$(printf '%s\n' "$line" | sed 's/[\/&]/\\&/g' | sed 's/"/\\"/g')
            printf "    printf(\"%%s\\\\n\", \"%s\");\n" "$escaped_line"
        done < "$input_script"
    } > "$temp_code"
    
    # Insert the generated code between Script start and Script end markers
    sed -i '/\/\/ Script start - Additional generated code will be inserted here/r '"$temp_code" "$c_source_file"
    rm -f "$temp_code"
    
    log_output "pass" "Inserted parsed content into $c_source_file between markers"
    return 0
}
