#!/bin/bash

# shave-output.sh - A script to handle console output with formatted messages

# Function to format a number with thousands separators
# Usage: format_number <number>
format_number() {
  echo "$1" | sed -E ':a;s/([0-9]+)([0-9]{3})/\1,\2/;ta'
}

# ANSI Color Codes
RESET_COLOR="\033[0m"
INFO_COLOR="\033[1;36m"  # Cyan
WARN_COLOR="\033[1;33m"  # Yellow
FAIL_COLOR="\033[1;31m"  # Red
PASS_COLOR="\033[1;32m"  # Green
DONE_COLOR="\033[1;33m"  # Yellow
STEP_COLOR="\033[1;35m"  # Magenta
INIT_COLOR="\033[1;33m"  # Yellow
FILE_COLOR="\033[1;33m"  # Yellow

# Icons for different log levels
INFO_ICON="${INFO_COLOR}\U2587\U2587"
WARN_ICON="${WARN_COLOR}\U2587\U2587"
FAIL_ICON="${FAIL_COLOR}\U2587\U2587"
PASS_ICON="${PASS_COLOR}\U2587\U2587"
DONE_ICON="${DONE_COLOR}\U2587\U2587"
STEP_ICON="${STEP_COLOR}\U2587\U2587"
INIT_ICON="${INIT_COLOR}\U2587\U2587"
FILE_ICON="${FILE_COLOR}\U2587\U2587"

# Labels for different log levels
INFO_LABEL="INFO"
WARN_LABEL="WARN"
FAIL_LABEL="FAIL"
PASS_LABEL="PASS"
DONE_LABEL="DONE"
STEP_LABEL="STEP"
INIT_LABEL="INIT"
FILE_LABEL="FILE"


# Function to convert a full path to a relative path if not in /tmp/
# Usage: get_relative_path <path>
get_relative_path() {
  local path="$1"
  if [[ "$path" == /tmp/* ]]; then
    echo "$path"
  else
    # Get the current working directory
    local cwd
    cwd="$(pwd)"
    # Compute relative path if possible
    if [[ "$path" == "$cwd"* ]]; then
      echo "${path#"$cwd"/}"
    else
      # Try to compute relative path from parent directories
      local rel_path="$path"
      if [[ "$path" == /* ]]; then
        local temp_rel_path
        temp_rel_path=$(realpath --relative-to="$cwd" "$path" 2>/dev/null)
        if [ -n "$temp_rel_path" ]; then
          rel_path="$temp_rel_path"
        fi
      fi
      echo "$rel_path"
    fi
  fi
}

# Function to process a message and replace full paths with relative paths
# Usage: process_message <message>
process_message() {
  local message="$1"
  # Use a while loop to handle multiple paths in the message
  local processed="$message"
  local paths=()
  IFS=' ' read -ra words <<< "$message"
  for word in "${words[@]}"; do
    # Check if the word looks like a path
    if [[ "$word" == /* || "$word" == */* ]]; then
      # Check if it's an actual file or directory
      if [ -e "$word" ]; then
        paths+=("$word")
      fi
    fi
  done
  for path in "${paths[@]}"; do
    local rel_path
    rel_path=$(get_relative_path "$path")
    processed="${processed//$path/$rel_path}"
  done
  echo "$processed"
}

# Function to get elapsed time since script start in SSS.ZZZ format
# Requires SHAVE_START_TIME to be set at the beginning of the script
get_elapsed_time() {
  if [ -z "$SHAVE_START_TIME" ]; then
    SHAVE_START_TIME=$(date +%s%3N)
  fi
  local current_time_ms
  current_time_ms=$(date +%s%3N)
  local start_time_ms="$SHAVE_START_TIME"
  # Calculate elapsed time in milliseconds
  local elapsed_ms
  elapsed_ms=$((current_time_ms - start_time_ms))
  # Convert to seconds and milliseconds
  local secs
  secs=$((elapsed_ms / 1000))
  local millis
  millis=$((elapsed_ms % 1000))
  printf "%03d.%03d" "$secs" "$millis"
}

# Function to log output with elapsed time, step counter, icon, label, and message
# Usage: log_output <level> <message>
# Levels: info, warn, fail, pass, done, step
log_output() {
  local level="$1"
  local message="$2"
  local processed_message
  processed_message=$(process_message "$message")
  local elapsed_time
  elapsed_time=$(get_elapsed_time)
  local color=""
  local icon=""
  local label=""

  # Initialize step counters if not set
  if [ -z "$MAJOR_STEP" ]; then
    MAJOR_STEP=-1
    MINOR_STEP=0
  fi

  # Increment step counters
  if [ "$level" == "step" ] || [ "$level" == "init" ] || [ "$level" == "file" ]; then
    MAJOR_STEP=$((MAJOR_STEP + 1))
    MINOR_STEP=0
  else
    MINOR_STEP=$((MINOR_STEP + 1))
  fi

  # Format step counter as 00-000
  local step_counter
  step_counter=$(printf "%02d-%03d" "$MAJOR_STEP" "$MINOR_STEP")

  case "$level" in
    "info")
      color=$INFO_COLOR
      icon=$INFO_ICON
      label=$INFO_LABEL
      ;;
    "warn")
      color=$WARN_COLOR
      icon=$WARN_ICON
      label=$WARN_LABEL
      ;;
    "fail")
      color=$FAIL_COLOR
      icon=$FAIL_ICON
      label=$FAIL_LABEL
      ;;
    "pass")
      color=$PASS_COLOR
      icon=$PASS_ICON
      label=$PASS_LABEL
      ;;
    "done")
      color=$DONE_COLOR
      icon=$DONE_ICON
      label=$DONE_LABEL
      ;;
    "step")
      color=$STEP_COLOR
      icon=$STEP_ICON
      label=$STEP_LABEL
      ;;
    "init")
      color=$INIT_COLOR
      icon=$INIT_ICON
      label=$INIT_LABEL
      ;;
    "file")
      color=$FILE_COLOR
      icon=$FILE_ICON
      label=$FILE_LABEL
      ;;
    *)
      color=$RESET_COLOR
      icon="?"
      label="UNKNOWN"
      ;;
  esac

  if [ "$level" == "step" ] || [ "$level" == "file" ]; then
    echo -e "${color}  $step_counter   $elapsed_time   ${icon} ${label}   ${processed_message}${RESET_COLOR}"
  else
    echo -e "  $step_counter   $elapsed_time   ${icon} ${color}${label}${RESET_COLOR}   ${processed_message}"
  fi
}

# Example usage (uncomment to test)
# log_output "info" "This is an information message."
# log_output "warn" "This is a warning message."
# log_output "fail" "This is a failure message."
# log_output "pass" "This is a success message."
# log_output "done" "This task is completed."
