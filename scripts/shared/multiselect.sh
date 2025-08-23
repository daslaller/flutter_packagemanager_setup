#!/bin/bash

# Multi-selection menu function
# Usage: multiselect "prompt" array_name selected_indices_var_name [single_mode]
multiselect() {
    local prompt="$1"
    local options_array_name="$2"
    local selected_array_name="$3"
    local single_mode="${4:-false}"
    
    # Create local reference to the options array (bash 3.x compatible)
    eval "local options_ref=(\"\${${options_array_name}[@]}\")"
    
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
        if [[ "$single_mode" == "true" ]]; then
            echo "Use ↑/↓ or j/k to navigate, SPACE or ENTER to select, q to quit"
        else
            echo "Use ↑/↓ or j/k to navigate, SPACE to select/deselect, ENTER to confirm, q to quit"
        fi
        echo ""
        
        for ((i=0; i<${#options_ref[@]}; i++)); do
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
                if [[ "$single_mode" == "true" ]]; then
                    # Single mode: clear all selections first, then select current
                    for ((i=0; i<${#selected[@]}; i++)); do
                        selected[i]=false
                    done
                    selected[cursor]=true
                    selected_indices=($cursor)
                    break  # Exit immediately in single mode
                else
                    # Multi mode: toggle selection
                    if [[ "${selected[cursor]}" == "true" ]]; then
                        selected[cursor]=false
                        # Remove from selected_indices
                        selected_indices=($(printf '%s\n' "${selected_indices[@]}" | grep -v "^${cursor}$"))
                    else
                        selected[cursor]=true
                        selected_indices+=($cursor)
                    fi
                fi
                ;;
            $'\n'|$'\r') # Enter
                if [[ "$single_mode" == "true" ]]; then
                    # Single mode: select current item and exit
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
        esac
    done
    
    # Sort selected indices
    IFS=$'\n' selected_indices=($(sort -n <<<"${selected_indices[*]}"))
    
    # Return selected indices using eval (bash 3.x compatible)
    eval "${selected_array_name}=(\"\${selected_indices[@]}\")"
    
    clear
}