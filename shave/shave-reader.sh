#!/bin/bash
# Shave Reader: Reads Bash script content into an array for further processing.

# Source the output handling script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./shave-output.sh
# shellcheck disable=SC1091
# Note: shellcheck may report SC1091 as the file path is dynamically determined
. "$SCRIPT_DIR/shave-output.sh"

# Function to read script content into an array
read_script_content() {
    local input_script="$1"
    local -n content_array="$2"  # Nameref to return the array
    
    # Check if input file exists
    if [[ ! -f "$input_script" ]]; then
        log_output "fail" "Input script '$input_script' not found."
        return 1
    fi
    
    # Read the file into an array, preserving each line
    mapfile -t content_array < "$input_script"
    
    log_output "info" "Read content from '$input_script' into array (${#content_array[@]} lines)."
    # If in debug mode, save the content to a temporary file with .txt extension, showing array structure
    if [[ "$DEBUG_MODE" == "true" ]]; then
        local temp_file
        temp_file=$(mktemp /tmp/shave-script.XXXXXX.txt)
        {
            echo "Script Content Array:"
            echo "--------------------"
            local i
            for i in "${!content_array[@]}"; do
                echo "[$i]: ${content_array[$i]}"
            done
        } > "$temp_file"
        log_output "info" "Debug mode: Script content array saved to $temp_file"
    fi
    return 0
}
