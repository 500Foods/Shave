#!/bin/bash
# Shave Combiner: Merges script content and CST data for further processing.

# Source the output handling script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./shave-output.sh  # Essential for logging and output handling
# shellcheck disable=SC1091  # File path is dynamically determined at runtime
. "$SCRIPT_DIR/shave-output.sh"

# Function to combine script content array and CST regular array
combine_content_cst() {
    local script_content_name="$1"  # Name of script content array
    local cst_data_name="$2"        # Name of CST regular array
    
    # Use eval to access arrays by name
    eval "local script_content_size=\${#${script_content_name}[@]}"
    eval "local cst_data_size=\${#${cst_data_name}[@]}"
    # shellcheck disable=SC2154  # Variable defined in calling script, appears undefined to shellcheck
    log_output "info" "Combining script content ($script_content_size lines) with CST data ($cst_data_size entries)"
    
    # Create a combined array with source code lookups from CST range data
    local -a combined_data
    local i
    for ((i=0; i<cst_data_size; i++)); do
        eval "local cst_entry=\"\${${cst_data_name}[$i]}\""
        # shellcheck disable=SC2154  # Variable defined in calling script, appears undefined to shellcheck
        # Extract range information and lookup source code
            if [[ "$cst_entry" =~ \[([0-9]+),\ ([0-9]+)\]\ -\ \[([0-9]+),\ ([0-9]+)\] ]]; then
                local start_line="${BASH_REMATCH[1]}"
                local start_col="${BASH_REMATCH[2]}"
                local end_line="${BASH_REMATCH[3]}"
                local end_col="${BASH_REMATCH[4]}"
                
                # Check if range spans multiple lines
                if (( start_line != end_line )); then
                    combined_data[i]=""  # Blank value for multi-line ranges
                else
                    # Single line - extract substring from source array
                    eval "local source_line=\"\${${script_content_name}[$start_line]}\""
                    if [[ -n "$source_line" ]] && (( start_col <= "${#source_line}" )); then
                        local extracted_text="${source_line:start_col:$((end_col - start_col))}"
                        combined_data[i]="$extracted_text"
                    else
                        combined_data[i]="(Out of range)"
                    fi
                fi
            else
                combined_data[i]="(No range info)"
            fi
    done
    
    # If in debug mode, save combined data to a temporary file
    if [[ "$DEBUG_MODE" == "true" ]]; then
        local temp_combined_file
        temp_combined_file=$(mktemp /tmp/shave-combined.XXXXXX.dat)
        {
            echo "CST Data vs Combined Data Comparison:"
            echo "======================================"
            printf "%-75s | %s\n" "CST Data" "Combined Data"
            printf "%-75s | %s\n" "$(printf '%*s' 75 '' | tr ' ' '-')" "$(printf '%*s' 75 '' | tr ' ' '-')"
            for ((i=0; i<cst_data_size; i++)); do
                eval "local cst_text=\"\${${cst_data_name}[$i]}\""
                local combined_text="${combined_data[$i]}"
                # Display the CST text directly (now contains only the original tree-sitter output)
                # shellcheck disable=SC2154  # Variable defined in calling script, appears undefined to shellcheck
                local cst_display="[$i]: $cst_text"
                printf "%-75s | %s\n" "$cst_display" "$combined_text"
            done
        } > "$temp_combined_file"
        
        # Store the filename in a global variable to be accessed by the calling script
        # shellcheck disable=SC2034  # Variable kept for compatibility with calling scripts
        COMBINED_DEBUG_FILE="$temp_combined_file"  # Unused but kept for compatibility with calling scripts
        # Log will be handled in the calling script to avoid duplicates for combined data
    fi
    
    return 0
}
