#!/bin/bash

LOG_FILE="$1"
MAX_LINES=2000
KEEP_LINES=1000

touch "$LOG_FILE"

while IFS= read -r line; do
    echo "$line" >> "$LOG_FILE"
    
    if (( RANDOM % 50 == 0 )); then
        line_count=$(wc -l < "$LOG_FILE")
        
        if [ "$line_count" -gt "$MAX_LINES" ]; then
            tail -n "$KEEP_LINES" "$LOG_FILE" > "$LOG_FILE.tmp"
            mv "$LOG_FILE.tmp" "$LOG_FILE"
        fi
    fi
done