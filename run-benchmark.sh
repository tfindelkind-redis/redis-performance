#!/bin/bash

# Redis Performance Benchmark Runner
# This script allows you to select and run different performance profiles
# against an Azure Managed Redis Database

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"
PROFILES_DIR="${SCRIPT_DIR}/profiles"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if redis-benchmark is installed
check_redis_benchmark() {
    if ! command -v redis-benchmark &> /dev/null; then
        print_error "redis-benchmark is not installed!"
        echo "Please install Redis tools:"
        echo "  macOS: brew install redis"
        echo "  Linux: sudo apt-get install redis-tools"
        exit 1
    fi
}

# Function to load configuration
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        print_info "Please copy config.sh.template to config.sh and fill in your Redis details:"
        print_info "  cp config.sh.template config.sh"
        print_info "  vim config.sh"
        exit 1
    fi
    
    source "$CONFIG_FILE"
    
    # Validate required configuration
    if [ -z "$REDIS_HOST" ]; then
        print_error "REDIS_HOST is not set in config.sh"
        exit 1
    fi
    
    if [ -z "$REDIS_PASSWORD" ]; then
        print_error "REDIS_PASSWORD is not set in config.sh"
        exit 1
    fi
    
    print_success "Configuration loaded successfully"
    
    # Set defaults for optional parameters
    REDIS_DB="${REDIS_DB:-0}"
    USE_SSL="${USE_SSL:-true}"
    REDIS_PORT="${REDIS_PORT:-6380}"
}

# Function to list available profiles
list_profiles() {
    if [ ! -d "$PROFILES_DIR" ]; then
        print_error "Profiles directory not found: $PROFILES_DIR"
        exit 1
    fi
    
    profiles=($(find "$PROFILES_DIR" -name "*.profile" -type f | sort))
    
    if [ ${#profiles[@]} -eq 0 ]; then
        print_error "No profiles found in $PROFILES_DIR"
        exit 1
    fi
    
    echo ""
    echo "Available Performance Profiles:"
    echo "================================"
    
    for i in "${!profiles[@]}"; do
        profile_name=$(basename "${profiles[$i]}" .profile)
        # Read the first comment line as description
        description=$(grep "^#" "${profiles[$i]}" | head -2 | tail -1 | sed 's/^# //')
        printf "%2d) %-25s %s\n" $((i+1)) "$profile_name" "$description"
    done
    
    echo ""
}

# Function to parse profile file
parse_profile() {
    local profile_file="$1"
    local args=""
    
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        args="$args $line"
    done < "$profile_file"
    
    echo "$args"
}

# Function to run benchmark
run_benchmark() {
    local profile_file="$1"
    local profile_name=$(basename "$profile_file" .profile)
    
    print_info "Running benchmark with profile: $profile_name"
    print_info "Profile: $profile_file"
    echo ""
    
    # Parse profile arguments
    profile_args=$(parse_profile "$profile_file")
    
    # Build redis-benchmark command
    cmd="redis-benchmark -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD"
    
    # Add SSL flag if enabled
    if [ "$USE_SSL" = "true" ]; then
        cmd="$cmd --tls"
    fi
    
    # Add database number if not default
    if [ -n "$REDIS_DB" ] && [ "$REDIS_DB" != "0" ]; then
        cmd="$cmd --dbnum $REDIS_DB"
    fi
    
    # Add profile arguments
    cmd="$cmd $profile_args"
    
    # Show the command (without password)
    safe_cmd=$(echo "$cmd" | sed "s/-a [^ ]*/-a ****/g")
    print_info "Command: $safe_cmd"
    echo ""
    
    # Create results directory if it doesn't exist
    RESULTS_DIR="${SCRIPT_DIR}/results"
    mkdir -p "$RESULTS_DIR"
    
    # Generate timestamp for results
    timestamp=$(date +"%Y%m%d_%H%M%S")
    result_file="${RESULTS_DIR}/${profile_name}_${timestamp}.txt"
    
    # Run the benchmark
    print_info "Starting benchmark... (results will be saved to $result_file)"
    echo ""
    
    eval "$cmd" 2>&1 | tee "$result_file"
    
    echo ""
    print_success "Benchmark completed!"
    print_info "Results saved to: $result_file"
}

# Main script
main() {
    echo "=========================================="
    echo "  Redis Performance Benchmark Runner"
    echo "=========================================="
    echo ""
    
    # Check prerequisites
    check_redis_benchmark
    
    # Load configuration
    load_config
    
    print_info "Redis Configuration:"
    print_info "  Host: $REDIS_HOST"
    print_info "  Port: $REDIS_PORT"
    print_info "  SSL: $USE_SSL"
    print_info "  Database: $REDIS_DB"
    echo ""
    
    # List available profiles
    list_profiles
    
    # Get user selection
    profiles=($(find "$PROFILES_DIR" -name "*.profile" -type f | sort))
    
    while true; do
        read -p "Select a profile (1-${#profiles[@]}) or 'q' to quit: " selection
        
        if [ "$selection" = "q" ] || [ "$selection" = "Q" ]; then
            print_info "Exiting..."
            exit 0
        fi
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#profiles[@]}" ]; then
            selected_profile="${profiles[$((selection-1))]}"
            echo ""
            run_benchmark "$selected_profile"
            echo ""
            
            # Ask if user wants to run another test
            read -p "Run another benchmark? (y/n): " continue
            if [ "$continue" != "y" ] && [ "$continue" != "Y" ]; then
                print_info "Exiting..."
                exit 0
            fi
            echo ""
            list_profiles
        else
            print_error "Invalid selection. Please choose a number between 1 and ${#profiles[@]}"
        fi
    done
}

# Run main function
main
