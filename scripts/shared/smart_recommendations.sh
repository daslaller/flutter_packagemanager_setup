#!/bin/bash

# Smart Dependency Recommendations Engine (Bash 3.2 Compatible)
# Analyzes Flutter code and suggests relevant packages with quality scores

# Function to get package recommendations for a pattern
get_package_recommendations() {
    local pattern="$1"
    
    case "$pattern" in
        "setState_pattern")
            echo "riverpod:9.2:Elegant state management with excellent API design"
            echo "provider:8.1:Simple but can get verbose with complex state"
            echo "bloc:7.3:Powerful but often over-engineered for simple apps"
            ;;
        "SharedPreferences_pattern")
            echo "hive:8.8:Ingenious NoSQL database with beautiful syntax"
            echo "shared_preferences:6.5:Basic but gets messy with complex data"
            echo "sqflite:7.8:Powerful but overkill for simple key-value storage"
            ;;
        "manual_http")
            echo "dio:9.1:Elegant HTTP client with interceptors and clean API"
            echo "http:7.2:Basic but requires lots of boilerplate for complex scenarios"
            ;;
        "Navigator_push")
            echo "go_router:8.9:Declarative routing with excellent type safety"
            echo "auto_route:8.2:Code generation approach, less boilerplate"
            ;;
        "manual_json")
            echo "json_serializable:8.7:Code generation eliminates boilerplate and errors"
            echo "freezed:9.0:Immutable classes with union types - incredibly elegant"
            ;;
        "manual_auth")
            echo "firebase_auth:8.9:Comprehensive auth solution with great API"
            echo "supabase_auth:8.4:Clean alternative to Firebase"
            ;;
        "Container_styling")
            echo "flutter_screenutil:8.3:Responsive design made simple"
            echo "styled_widget:8.6:Eloquent widget styling without nesting hell"
            ;;
        "TextEditingController_forms")
            echo "reactive_forms:8.8:Reactive programming for forms - very elegant"
            echo "flutter_form_builder:7.9:Declarative but can be verbose"
            ;;
        "Image_network")
            echo "cached_network_image:8.5:Intelligent caching with smooth loading states"
            echo "fast_cached_network_image:8.7:Even faster with better memory management"
            ;;
        "print_debugging")
            echo "logger:8.4:Beautiful colored logs with different levels"
            echo "talker:8.6:Comprehensive logging and error tracking"
            ;;
        "AnimationController_manual")
            echo "flutter_animate:9.3:Declarative animations with incredible ease of use"
            echo "lottie:8.1:Complex animations via After Effects files"
            ;;
        "DateTime_formatting")
            echo "intl:8.0:Internationalization with date formatting"
            echo "timeago:7.8:Human-readable relative time"
            ;;
        "manual_singletons")
            echo "get_it:8.2:Service locator pattern done right"
            echo "injectable:8.5:Code generation for DI - less boilerplate"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Function to get quality level explanation
get_quality_explanation() {
    local score="$1"
    local score_int=$(echo "$score" | sed 's/\..*//')
    
    case "$score_int" in
        9) echo "🌟 Exceptional: Ingenious design, elegant API, solves complex problems simply" ;;
        8) echo "⭐ Excellent: Great architecture, clean code, well-designed API" ;;
        7) echo "✨ Very Good: Solid implementation, good design patterns" ;;
        6) echo "👍 Decent: Gets the job done but lacks ingenuity" ;;
        *) echo "👌 Functional: Works but could be more elegant" ;;
    esac
}

# Function to analyze Flutter code patterns
analyze_code_patterns() {
    local project_dir="$1"
    local found_patterns=()
    
    echo "🔍 Analyzing your Flutter code for improvement opportunities..."
    echo ""
    
    if [ ! -d "$project_dir" ]; then
        echo "❌ Project directory not found: $project_dir"
        return 1
    fi
    
    # Find all Dart files
    local dart_files=$(find "$project_dir" -name "*.dart" -not -path "*/.*" -not -path "*/build/*" 2>/dev/null)
    
    if [ -z "$dart_files" ]; then
        echo "⚠️  No Dart files found in project"
        return 1
    fi
    
    echo "📂 Scanning $(echo "$dart_files" | wc -l) Dart files..."
    echo ""
    
    # Pattern Detection
    local temp_analysis=$(mktemp)
    
    # Combine all dart files for analysis
    cat $dart_files > "$temp_analysis" 2>/dev/null || {
        echo "❌ Could not read Dart files"
        rm -f "$temp_analysis"
        return 1
    }
    
    # setState Pattern Detection
    local setState_count=$(grep -c "setState(" "$temp_analysis" 2>/dev/null || echo "0")
    if [ "$setState_count" -gt 0 ]; then
        found_patterns[${#found_patterns[@]}]="setState_pattern:$setState_count"
        echo "🔄 State Management: Found $setState_count setState() calls"
    fi
    
    # SharedPreferences Pattern Detection  
    local prefs_count=$(grep -c "SharedPreferences" "$temp_analysis" 2>/dev/null || echo "0")
    if [ "$prefs_count" -gt 0 ]; then
        found_patterns[${#found_patterns[@]}]="SharedPreferences_pattern:$prefs_count"
        echo "💾 Local Storage: Found $prefs_count SharedPreferences usages"
    fi
    
    # Manual HTTP Detection
    local http_count_get=$(grep -c "http\.get\|http\.post" "$temp_analysis" 2>/dev/null || echo "0")
    local http_count_client=$(grep -c "HttpClient" "$temp_analysis" 2>/dev/null || echo "0") 
    local dio_count=$(grep -c "dio\|Dio" "$temp_analysis" 2>/dev/null || echo "0")
    
    # Ensure numeric values for arithmetic - strip whitespace
    http_count_get=$(echo "$http_count_get" | tr -d '[:space:]')
    http_count_client=$(echo "$http_count_client" | tr -d '[:space:]')
    dio_count=$(echo "$dio_count" | tr -d '[:space:]')
    http_count_get=${http_count_get:-0}
    http_count_client=${http_count_client:-0}
    dio_count=${dio_count:-0}
    local total_http=$((http_count_get + http_count_client))
    
    if [ "$total_http" -gt 0 ] && [ "$dio_count" -eq 0 ]; then
        found_patterns[${#found_patterns[@]}]="manual_http:$total_http"
        echo "🌐 HTTP Calls: Found $total_http manual HTTP implementations"
    fi
    
    # Navigation Pattern Detection
    local nav_count=$(grep -c "Navigator\.push" "$temp_analysis" 2>/dev/null || echo "0")
    local router_count=$(grep -c "go_router\|GoRouter" "$temp_analysis" 2>/dev/null || echo "0")
    
    # Clean numeric values
    nav_count=$(echo "$nav_count" | tr -d '[:space:]')
    router_count=$(echo "$router_count" | tr -d '[:space:]')
    nav_count=${nav_count:-0}
    router_count=${router_count:-0}
    
    if [ "$nav_count" -gt 0 ] && [ "$router_count" -eq 0 ]; then
        found_patterns[${#found_patterns[@]}]="Navigator_push:$nav_count"
        echo "🧭 Navigation: Found $nav_count imperative navigation calls"
    fi
    
    # Manual JSON Pattern Detection
    local json_count=$(grep -c "fromJson\|toJson" "$temp_analysis" 2>/dev/null || echo "0")
    local json_serializable_count=$(grep -c "json_serializable\|JsonSerializable" "$temp_analysis" 2>/dev/null || echo "0")
    
    # Clean numeric values
    json_count=$(echo "$json_count" | tr -d '[:space:]')
    json_serializable_count=$(echo "$json_serializable_count" | tr -d '[:space:]')
    json_count=${json_count:-0}
    json_serializable_count=${json_serializable_count:-0}
    
    if [ "$json_count" -gt 0 ] && [ "$json_serializable_count" -eq 0 ]; then
        found_patterns[${#found_patterns[@]}]="manual_json:$json_count"
        echo "📋 JSON Handling: Found $json_count manual JSON implementations"
    fi
    
    # Authentication Pattern Detection
    local auth_count=$(grep -c "login\|signIn\|authenticate" "$temp_analysis" 2>/dev/null || echo "0")
    local firebase_auth_count=$(grep -c "firebase_auth\|FirebaseAuth" "$temp_analysis" 2>/dev/null || echo "0")
    
    # Clean numeric values
    auth_count=$(echo "$auth_count" | tr -d '[:space:]')
    firebase_auth_count=$(echo "$firebase_auth_count" | tr -d '[:space:]')
    auth_count=${auth_count:-0}
    firebase_auth_count=${firebase_auth_count:-0}
    
    if [ "$auth_count" -gt 0 ] && [ "$firebase_auth_count" -eq 0 ]; then
        found_patterns[${#found_patterns[@]}]="manual_auth:$auth_count"
        echo "🔐 Authentication: Found $auth_count manual auth implementations"
    fi
    
    # Container Styling Detection
    local container_count=$(grep -c "Container(" "$temp_analysis" 2>/dev/null || echo "0")
    container_count=$(echo "$container_count" | tr -d '[:space:]')
    container_count=${container_count:-0}
    if [ "$container_count" -gt 10 ]; then
        found_patterns[${#found_patterns[@]}]="Container_styling:$container_count"
        echo "🎨 UI Styling: Found $container_count Container widgets (potential styling complexity)"
    fi
    
    # Form Handling Detection
    local controller_count=$(grep -c "TextEditingController" "$temp_analysis" 2>/dev/null || echo "0")
    controller_count=$(echo "$controller_count" | tr -d '[:space:]')
    controller_count=${controller_count:-0}
    if [ "$controller_count" -gt 3 ]; then
        found_patterns[${#found_patterns[@]}]="TextEditingController_forms:$controller_count"
        echo "📝 Form Handling: Found $controller_count TextEditingController instances"
    fi
    
    # Image Network Detection
    local image_count=$(grep -c "Image\.network" "$temp_analysis" 2>/dev/null || echo "0")
    local cached_image_count=$(grep -c "cached_network_image" "$temp_analysis" 2>/dev/null || echo "0")
    
    # Clean numeric values
    image_count=$(echo "$image_count" | tr -d '[:space:]')
    cached_image_count=$(echo "$cached_image_count" | tr -d '[:space:]')
    image_count=${image_count:-0}
    cached_image_count=${cached_image_count:-0}
    
    if [ "$image_count" -gt 0 ] && [ "$cached_image_count" -eq 0 ]; then
        found_patterns[${#found_patterns[@]}]="Image_network:$image_count"
        echo "🖼️ Image Loading: Found $image_count uncached network images"
    fi
    
    # Print Debugging Detection
    local print_count=$(grep -c "print(" "$temp_analysis" 2>/dev/null || echo "0")
    local logger_count=$(grep -c "logger\|Logger" "$temp_analysis" 2>/dev/null || echo "0")
    
    # Clean numeric values
    print_count=$(echo "$print_count" | tr -d '[:space:]')
    logger_count=$(echo "$logger_count" | tr -d '[:space:]')
    print_count=${print_count:-0}
    logger_count=${logger_count:-0}
    
    if [ "$print_count" -gt 5 ] && [ "$logger_count" -eq 0 ]; then
        found_patterns[${#found_patterns[@]}]="print_debugging:$print_count"
        echo "🐛 Debugging: Found $print_count print statements (could use proper logging)"
    fi
    
    # Animation Detection
    local anim_count=$(grep -c "AnimationController\|Animation<" "$temp_analysis" 2>/dev/null || echo "0")
    local flutter_animate_count=$(grep -c "flutter_animate" "$temp_analysis" 2>/dev/null || echo "0")
    
    # Clean numeric values
    anim_count=$(echo "$anim_count" | tr -d '[:space:]')
    flutter_animate_count=$(echo "$flutter_animate_count" | tr -d '[:space:]')
    anim_count=${anim_count:-0}
    flutter_animate_count=${flutter_animate_count:-0}
    
    if [ "$anim_count" -gt 0 ] && [ "$flutter_animate_count" -eq 0 ]; then
        found_patterns[${#found_patterns[@]}]="AnimationController_manual:$anim_count"
        echo "🎭 Animations: Found $anim_count manual animation implementations"
    fi
    
    # DateTime Formatting Detection
    local date_format_count=$(grep -c "DateTime.*toString\|DateFormat.*format" "$temp_analysis" 2>/dev/null || echo "0")
    date_format_count=$(echo "$date_format_count" | tr -d '[:space:]')
    date_format_count=${date_format_count:-0}
    if [ "$date_format_count" -gt 0 ]; then
        found_patterns[${#found_patterns[@]}]="DateTime_formatting:$date_format_count"
        echo "📅 Date Formatting: Found $date_format_count date formatting operations"
    fi
    
    # Manual Singleton Detection
    local singleton_count=$(grep -c "static.*getInstance\|static.*_instance" "$temp_analysis" 2>/dev/null || echo "0")
    singleton_count=$(echo "$singleton_count" | tr -d '[:space:]')
    singleton_count=${singleton_count:-0}
    if [ "$singleton_count" -gt 0 ]; then
        found_patterns[${#found_patterns[@]}]="manual_singletons:$singleton_count"
        echo "🏗️ Dependency Management: Found $singleton_count manual singleton patterns"
    fi
    
    rm -f "$temp_analysis"
    
    # Store found patterns for recommendation generation
    if [ ${#found_patterns[@]} -eq 0 ]; then
        echo "✅ Code analysis complete - no obvious improvement opportunities found!"
        echo "   Your code is already well-structured! 🎉"
        return 0
    fi
    
    echo ""
    echo "📊 Analysis complete: Found ${#found_patterns[@]} improvement opportunities"
    echo ""
    
    # Generate recommendations
    generate_smart_recommendations "${found_patterns[@]}"
}

# Function to generate smart recommendations based on detected patterns
generate_smart_recommendations() {
    local patterns=("$@")
    
    echo "🤖 **SMART RECOMMENDATIONS** - Packages that could improve your code:"
    echo "================================================================="
    echo ""
    
    local rec_count=0
    
    for pattern_info in "${patterns[@]}"; do
        IFS=':' read -r pattern_name count <<< "$pattern_info"
        
        local recommendations=$(get_package_recommendations "$pattern_name")
        if [ -n "$recommendations" ]; then
            rec_count=$((rec_count + 1))
            
            echo "**${rec_count}. $(get_pattern_title "$pattern_name")** ($count occurrences found)"
            echo ""
            
            # Display recommendations
            echo "$recommendations" | while IFS=':' read -r package_name quality_score description; do
                if [ -n "$package_name" ]; then
                    local quality_level=$(get_quality_level "$quality_score")
                    local quality_explanation=$(get_quality_explanation "$quality_score")
                    
                    echo "   📦 **$package_name** (Quality: $quality_score/10) $quality_level"
                    echo "      💡 $description"
                    echo "      📈 $quality_explanation"
                    echo ""
                fi
            done
            
            echo "   🎯 **Why this matters:** $(get_pattern_explanation "$pattern_name")"
            echo ""
            echo "$(printf '%*s' 80 '' | tr ' ' '-')"
            echo ""
        fi
    done
    
    if [ $rec_count -eq 0 ]; then
        echo "🎉 No specific recommendations found - your code patterns look great!"
    else
        echo ""
        echo "💡 **Next Steps:**"
        echo "   1. Review the recommendations above"
        echo "   2. When adding packages, flutter-pm will prioritize these high-quality options"
        echo "   3. Each package includes architectural guidance for integration"
        echo ""
        echo "🏆 **Quality Focus:** These recommendations prioritize elegant, ingenious solutions"
        echo "   over popular but overcomplicated alternatives."
    fi
}

# Helper function to get pattern title
get_pattern_title() {
    case "$1" in
        "setState_pattern") echo "State Management Opportunity" ;;
        "SharedPreferences_pattern") echo "Local Storage Enhancement" ;;
        "manual_http") echo "HTTP Client Improvement" ;;
        "Navigator_push") echo "Navigation Architecture" ;;
        "manual_json") echo "JSON Serialization" ;;
        "manual_auth") echo "Authentication Solution" ;;
        "Container_styling") echo "UI Styling Architecture" ;;
        "TextEditingController_forms") echo "Form Management" ;;
        "Image_network") echo "Image Loading Optimization" ;;
        "print_debugging") echo "Logging Infrastructure" ;;
        "AnimationController_manual") echo "Animation Framework" ;;
        "DateTime_formatting") echo "Date/Time Handling" ;;
        "manual_singletons") echo "Dependency Injection" ;;
        *) echo "Code Enhancement" ;;
    esac
}

# Helper function to get pattern explanation
get_pattern_explanation() {
    case "$1" in
        "setState_pattern") echo "Moving to a proper state management solution reduces complexity and improves maintainability" ;;
        "SharedPreferences_pattern") echo "Modern storage solutions offer better performance, type safety, and developer experience" ;;
        "manual_http") echo "Dedicated HTTP clients provide interceptors, error handling, and cleaner APIs" ;;
        "Navigator_push") echo "Declarative navigation reduces boilerplate and provides better type safety" ;;
        "manual_json") echo "Code generation eliminates runtime errors and reduces boilerplate significantly" ;;
        "manual_auth") echo "Authentication providers handle security concerns and edge cases you might miss" ;;
        "Container_styling") echo "Styling libraries reduce widget nesting and make responsive design easier" ;;
        "TextEditingController_forms") echo "Form libraries provide validation, reactive updates, and cleaner architecture" ;;
        "Image_network") echo "Image caching improves performance and provides loading states out of the box" ;;
        "print_debugging") echo "Proper logging tools provide filtering, formatting, and production-safe debugging" ;;
        "AnimationController_manual") echo "Animation frameworks eliminate boilerplate and provide declarative syntax" ;;
        "DateTime_formatting") echo "Internationalization libraries handle locales and provide consistent formatting" ;;
        "manual_singletons") echo "Dependency injection containers provide better testing and cleaner architecture" ;;
        *) echo "This pattern could benefit from a more elegant solution" ;;
    esac
}

# Helper function to get quality level emoji
get_quality_level() {
    local score="$1"
    local score_int=$(echo "$score" | sed 's/\..*//')
    
    case "$score_int" in
        9) echo "🌟" ;;
        8) echo "⭐" ;;
        7) echo "✨" ;;
        *) echo "👍" ;;
    esac
}