#!/bin/bash
# Shave Boilerplate: Generates the basic C code structure for the transpiler output.

# Source the output handling script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./shave-output.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/shave-output.sh"

# Function to generate C boilerplate code
generate_c_boilerplate() {
    local output_file="$1"
    local source_file="$2"
    # shellcheck disable=SC2034
    local source_path="$3"  # Reserved for future use
    local source_size_bytes="$4"
    local source_lines="$5"
    local source_timestamp="$6"
    local script_name="$7"
    local script_version="$8"
    local generation_timestamp
    generation_timestamp=$(date '+%Y-%m-%d %H:%M:%S %Z')
    local script_location
    script_location="$SCRIPT_DIR/shave.sh"
    # Handle script timestamp extraction for different systems (macOS vs Linux)
    local script_timestamp
    local raw_timestamp
    if stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S %Z" "$script_location" >/dev/null 2>&1; then
        script_timestamp=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S %Z" "$script_location")
    else
        raw_timestamp=$(stat -c %y "$script_location" | cut -d. -f1)
        script_timestamp="$raw_timestamp $(date +%Z)"
    fi
    # Format numbers with thousands separators
    local formatted_size_bytes
    local formatted_lines
    formatted_size_bytes=$(format_number "$source_size_bytes")
    formatted_lines=$(format_number "$source_lines")
    cat << EOF > "$output_file"
// -----------------------------------------------------------------------------
// Shave Transpiler Output
// Script Name: $script_name
// Script Version: $script_version
// Script Location: $script_location
// Script Timestamp: $script_timestamp
// Generation Timestamp: $generation_timestamp
// Source File: $source_file
// Source Size: $formatted_size_bytes bytes, $formatted_lines lines
// Source Timestamp: $source_timestamp
// -----------------------------------------------------------------------------

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Hash Table Start
// Hash Table End

int main(int argc, char *argv[]) {
    // Script start - Additional generated code will be inserted here
    // Script end - Transpiled code stops here
    return 0;
}
EOF
    log_output "info" "Generated C boilerplate in $output_file"
}
