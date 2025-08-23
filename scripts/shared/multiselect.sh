#!/bin/bash

# Multi-selection menu function
# Usage: multiselect "prompt" array_name selected_indices_var_name [single_mode]
multiselect() {
    local prompt="$1"
    local options_array_name="$2"
    local selected_array_name="$3"
    local single_mode="${4:-false}"
    local debug_mode="${5:-false}"
    
    # Create local reference to the options array (bash 3.x compatible)
    eval "local options_ref=(\"\${${options_array_name}[@]}\")"
    
    local selected=()
    local cursor=0
    local selected_indices=()
    local window_start=0
    local window_size=10
    
    # Initialize selected array with false values
    for ((i=0; i<${#options_ref[@]}; i++)); do
        selected[i]=false
    done
    
    draw_menu() {
        clear
        echo "$prompt"
        echo ""
        if [[ "$single_mode" == "true" ]]; then
            echo "Use ↑/↓ or j/k to navigate, SPACE or ENTER to select, q to quit"
        else
            echo "Use ↑/↓ or j/k to navigate, SPACE to select/deselect, ENTER to confirm, q to quit"
        fi
        echo ""
        
        # Calculate window bounds
        local window_end=$((window_start + window_size))
        if [[ $window_end -gt ${#options_ref[@]} ]]; then
            window_end=${#options_ref[@]}
        fi
        
        # Show 'hidden above' indicator
        if [[ $window_start -gt 0 ]]; then
            echo "... ($window_start more above) ..."
            echo ""
        fi
        
        for ((i=window_start; i<window_end; i++)); do
            local prefix="  "
            local checkbox="[ ]"
            
            # Check if this item is selected
            if [[ "${selected[i]}" == "true" ]]; then
                if [[ "$single_mode" == "true" ]]; then
                    checkbox="[●]"
                else
                    checkbox="[✓]"
                fi
            fi
            
            # Highlight current cursor position
            if [[ $i -eq $cursor ]]; then
                prefix="► "
                echo -e "\033[7m$prefix$checkbox ${options_ref[i]}\033[0m"
            else
                echo "$prefix$checkbox ${options_ref[i]}"
            fi
        done
        
        # Show 'hidden below' indicator
        if [[ $window_end -lt ${#options_ref[@]} ]]; then
            local remaining=$((${#options_ref[@]} - window_end))
            echo ""
            echo "... ($remaining more below) ..."
        fi
        
        echo ""
        if [[ "$single_mode" == "true" ]]; then
            if [[ ${#selected_indices[@]} -gt 0 ]]; then
                echo "Selected: ${options_ref[${selected_indices[0]}]}"
            else
                echo "No selection"
            fi
        else
            echo "Selected: ${#selected_indices[@]} items"
        fi
    }
    
    # Set up proper terminal handling
    exec 3</dev/tty
    local old_stty=$(stty -g </dev/tty 2>/dev/null)
    stty -echo -icanon min 1 time 0 </dev/tty 2>/dev/null
    
    cleanup() {
        if [[ -n "$old_stty" ]]; then
            stty "$old_stty" </dev/tty 2>/dev/null || true
        fi
        exec 3<&- 2>/dev/null || true
    }
    trap cleanup EXIT INT TERM
    
    while true; do
        draw_menu
        
        # Read single character using dd for raw input
        local key=""
        key=$(dd bs=1 count=1 </dev/tty 2>/dev/null)
        
        # Log every key press
        echo "Key: '$key' ASCII: $(printf '%d' "'$key" 2>/dev/null || echo 'N/A')" >> /tmp/multiselect_keys.log
        
        case "$key" in
            $'\x1b')  # ESC sequence - read next 2 chars with dd
                local seq=$(dd bs=1 count=2 </dev/tty 2>/dev/null)
                case "$seq" in
                    '[A') # Up arrow
                        if ((cursor > 0)); then
                            ((cursor--))
                            ((cursor < window_start)) && window_start=$cursor
                        fi
                        ;;
                    '[B') # Down arrow
                        if ((cursor < ${#options_ref[@]} - 1)); then
                            ((cursor++))
                            if [[ $cursor -ge $((window_start + window_size)) ]]; then
                                window_start=$((cursor - window_size + 1))
                            fi
                        fi
                        ;;
                esac
                ;;
            'j') # j key
                if ((cursor < ${#options_ref[@]} - 1)); then
                    ((cursor++))
                    if [[ $cursor -ge $((window_start + window_size)) ]]; then
                        window_start=$((cursor - window_size + 1))
                    fi
                fi
                ;;
            'k') # k key
                if ((cursor > 0)); then
                    ((cursor--))
                    ((cursor < window_start)) && window_start=$cursor
                fi
                ;;
            ' '|$'\x20'|$'\040'|"'") # Space (multiple possible formats including quote)
                echo "SPACE detected!" >> /tmp/multiselect_keys.log
                if [[ "$single_mode" == "true" ]]; then
                    # Single mode: select and exit
                    for ((i=0; i<${#selected[@]}; i++)); do
                        selected[i]=false
                    done
                    selected[cursor]=true
                    selected_indices=($cursor)
                    break
                else
                    # Multi mode: toggle selection (NO BREAK EVER)
                    if [[ "${selected[cursor]}" == "true" ]]; then
                        selected[cursor]=false
                        local tmp=()
                        for si in "${selected_indices[@]}"; do
                            [[ "$si" != "$cursor" ]] && tmp+=("$si")
                        done
                        selected_indices=("${tmp[@]}")
                    else
                        selected[cursor]=true
                        selected_indices+=($cursor)
                    fi
                fi
                ;;
            $'\n'|$'\r'|$'\x0d'|$'\x0a'|$'\0') # Enter (including null character)
                echo "ENTER detected!" >> /tmp/multiselect_keys.log
                if [[ "$single_mode" == "true" ]]; then
                    # Single mode: select current and exit
                    for ((i=0; i<${#selected[@]}; i++)); do
                        selected[i]=false
                    done
                    selected[cursor]=true
                    selected_indices=($cursor)
                fi
                break
                ;;
            'q'|'Q') # Quit
                selected_indices=()
                break
                ;;
            *) # Catch all other keys
                echo "UNHANDLED Key: '$key' ASCII: $(printf '%d' "'$key" 2>/dev/null || echo 'N/A')" >> /tmp/multiselect_keys.log
                ;;
        esac
    done
    
    # Cleanup terminal mode and restore normal settings
    cleanup
    stty echo icanon </dev/tty 2>/dev/null || true
    
    
    # Return selected indices using eval (bash 3.x compatible)
    eval "${selected_array_name}=(\"\${selected_indices[@]}\")"
    
    clear
}