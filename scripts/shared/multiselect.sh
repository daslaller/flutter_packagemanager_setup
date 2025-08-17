#!/bin/bash

# Multi-selection menu function
# Usage: multiselect "prompt" array_name selected_indices_var_name
multiselect() {
    local prompt="$1"
    local -n options_ref=$2
    local -n selected_ref=$3
    
    local selected=()
    local cursor=0
    local selected_indices=()
    
    # Initialize selected array with false values
    for ((i=0; i<${#options_ref[@]}; i++)); do
        selected[i]=false
    done
    
    draw_menu() {
        clear
        echo "$prompt"
        echo ""
        echo "Use ↑/↓ or j/k to navigate, SPACE to select/deselect, ENTER to confirm, q to quit"
        echo ""
        
        for ((i=0; i<${#options_ref[@]}; i++)); do
            local prefix="  "
            local checkbox="[ ]"
            
            # Check if this item is selected
            if [[ "${selected[i]}" == "true" ]]; then
                checkbox="[✓]"
            fi
            
            # Highlight current cursor position
            if [[ $i -eq $cursor ]]; then
                prefix="► "
                echo -e "\033[7m$prefix$checkbox ${options_ref[i]}\033[0m"
            else
                echo "$prefix$checkbox ${options_ref[i]}"
            fi
        done
        
        echo ""
        echo "Selected: ${#selected_indices[@]} items"
    }
    
    while true; do
        draw_menu
        
        # Read single character
        read -rsn1 key
        
        case "$key" in
            $'\x1b')  # ESC sequence
                read -rsn2 key
                case "$key" in
                    '[A'|'[k') # Up arrow or k
                        ((cursor > 0)) && ((cursor--))
                        ;;
                    '[B'|'[j') # Down arrow or j  
                        ((cursor < ${#options_ref[@]} - 1)) && ((cursor++))
                        ;;
                esac
                ;;
            'j') # j key
                ((cursor < ${#options_ref[@]} - 1)) && ((cursor++))
                ;;
            'k') # k key
                ((cursor > 0)) && ((cursor--))
                ;;
            ' ') # Space
                if [[ "${selected[cursor]}" == "true" ]]; then
                    selected[cursor]=false
                    # Remove from selected_indices
                    selected_indices=($(printf '%s\n' "${selected_indices[@]}" | grep -v "^${cursor}$"))
                else
                    selected[cursor]=true
                    selected_indices+=($cursor)
                fi
                ;;
            $'\n'|$'\r') # Enter
                break
                ;;
            'q'|'Q') # Quit
                selected_indices=()
                break
                ;;
        esac
    done
    
    # Sort selected indices
    IFS=$'\n' selected_indices=($(sort -n <<<"${selected_indices[*]}"))
    
    # Return selected indices
    selected_ref=("${selected_indices[@]}")
    
    clear
}