#!/bin/bash

# Multi-selection menu function
# Usage: multiselect "prompt" array_name selected_indices_var_name [single_mode] [debug_mode]
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
            echo "Use ↑/↓ or j/k to navigate, SPACE/ENTER to select, numbers for direct select, q to quit"
        else
            echo "Use ↑/↓ or j/k to navigate, SPACE to select/deselect, ENTER to confirm, numbers for direct select, q to quit"
        fi
        # ... existing code ...
        echo ""
        
        # Calculate window bounds
        local window_end=$((window_start + window_size))
        if [[ $window_end -gt ${#options_ref[@]} ]]; then
            window_end=${#options_ref[@]}
        fi
        
        # Show 'hidden above' indicator above the list
        if [[ $window_start -gt 0 ]]; then
            echo "... ($window_start more above) ..."
            echo ""
        fi
        
        for ((i=window_start; i<window_end; i++)); do
            local prefix="  "
            local checkbox="[ ]"
            if [[ "${selected[i]}" == "true" ]]; then
                if [[ "$single_mode" == "true" ]]; then
                    checkbox="[●]"
                else
                    checkbox="[✓]"
                fi
            fi
            if [[ $i -eq $cursor ]]; then
                prefix="► "
                echo -e "\033[7m$prefix$checkbox ${options_ref[i]}\033[0m"
            else
                echo "$prefix$checkbox ${options_ref[i]}"
            fi
        done
        
        # Show 'hidden below' indicator below the list
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
    
    # Ensure we have a terminal
    if [[ ! -t 0 && ! -t 1 && ! -t 2 ]]; then
        echo "❌ Error: This function requires an interactive terminal"
        return 1
    fi
    
    # Open controlling TTY on FD 3 and manage its mode locally
    local old_stty=""
    if [[ -t 0 ]]; then
        old_stty=$(stty -g 2>/dev/null)
    else
        old_stty=$(stty -g </dev/tty 2>/dev/null)
    fi
    exec 3</dev/tty 2>/dev/null || exec 3<&0
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
        
        # Read a single real key (skip nulls)
        local key=""
        while true; do
            if read -rsn1 -u 3 key 2>/dev/null; then
                [[ -n "$key" ]] && break
            fi
        done
        
        if [[ "$debug_mode" == "true" ]]; then
            echo "DEBUG: Key pressed: '$key' (ASCII: $(printf '%d' "'$key" 2>/dev/null || echo "N/A"))" >> /tmp/multiselect_debug.log
        fi
        
        case "$key" in
            $'\x1b')  # ESC sequence with short timeouts
                local k1="" k2=""
                read -rsn1 -u 3 -t 0.02 k1 2>/dev/null || k1=""
                if [[ "$k1" == "[" ]]; then
                    read -rsn1 -u 3 -t 0.02 k2 2>/dev/null || k2=""
                    case "$k2" in
                        A) # Up
                            if ((cursor > 0)); then
                                ((cursor--))
                                (( cursor < window_start )) && window_start=$cursor
                            fi
                            ;;
                        B) # Down
                            if ((cursor < ${#options_ref[@]} - 1)); then
                                ((cursor++))
                                if [[ $cursor -ge $((window_start + window_size)) ]]; then
                                    window_start=$((cursor - window_size + 1))
                                fi
                            fi
                            ;;
                    esac
                fi
                ;;
            'j')
                if ((cursor < ${#options_ref[@]} - 1)); then
                    ((cursor++))
                    if [[ $cursor -ge $((window_start + window_size)) ]]; then
                        window_start=$((cursor - window_size + 1))
                    fi
                fi
                ;;
            'k')
                if ((cursor > 0)); then
                    ((cursor--))
                    (( cursor < window_start )) && window_start=$cursor
                fi
                ;;
            ' ') # Space toggles selection
                if [[ "$single_mode" == "true" ]]; then
                    for ((i=0; i<${#selected[@]}; i++)); do selected[i]=false; done
                    selected[cursor]=true
                    selected_indices=($cursor)
                    break
                else
                    if [[ "${selected[cursor]}" == "true" ]]; then
                        selected[cursor]=false
                        # Remove from list
                        local tmp=()
                        for si in "${selected_indices[@]}"; do
                            [[ "$si" != "$cursor" ]] && tmp+=("$si")
                        done
                        selected_indices=("${tmp[@]}")
                    else
                        selected[cursor]=true
                        selected_indices+=("$cursor")
                    fi
                fi
                ;;
            $'\r'|$'\n') # Enter (CR or LF)
                if [[ "$single_mode" == "true" ]]; then
                    for ((i=0; i<${#selected[@]}; i++)); do selected[i]=false; done
                    selected[cursor]=true
                    selected_indices=($cursor)
                    break
                else
                    if [[ ${#selected_indices[@]} -gt 0 ]]; then
                        break
                    else
                        echo ""
                        echo "⚠️  No items selected. Use SPACE to select items, then ENTER to confirm."
                        sleep 1
                    fi
                fi
                ;;
            'q'|'Q')
                selected_indices=()
                break
                ;;
            [1-9])
                local num=$(( $(printf '%d' "'$key") - 48 ))
                if (( num>=1 && num<=${#options_ref[@]} )); then
                    local idx=$((num-1))
                    if [[ "$single_mode" == "true" ]]; then
                        for ((i=0; i<${#selected[@]}; i++)); do selected[i]=false; done
                        selected[idx]=true
                        selected_indices=($idx)
                        cursor=$idx
                        break
                    else
                        if [[ "${selected[idx]}" == "true" ]]; then
                            selected[idx]=false
                            local tmp=()
                            for si in "${selected_indices[@]}"; do
                                [[ "$si" != "$idx" ]] && tmp+=("$si")
                            done
                            selected_indices=("${tmp[@]}")
                        else
                            selected[idx]=true
                            selected_indices+=("$idx")
                        fi
                        cursor=$idx
                        if [[ $cursor -lt $window_start || $cursor -ge $((window_start + window_size)) ]]; then
                            window_start=$((cursor - window_size / 2))
                            (( window_start < 0 )) && window_start=0
                        fi
                    fi
                fi
                ;;
            *) : ;;
        esac
    done
    
    cleanup
    
    # Sort and return
    if [[ ${#selected_indices[@]} -gt 0 ]]; then
        IFS=$'\n' selected_indices=($(sort -n <<<"${selected_indices[*]}"))
        unset IFS
    fi
    eval "${selected_array_name}=(\"\${selected_indices[@]}\")"
    
    clear
}