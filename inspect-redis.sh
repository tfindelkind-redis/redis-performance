#!/bin/bash

# Redis Database Inspector and Cleanup Tool
# Helps you check and clean up redis-benchmark test data

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

echo "=========================================="
echo "  Redis Database Inspector & Cleanup"
echo "=========================================="
echo ""

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    print_error "config.sh not found!"
    exit 1
fi

source "$CONFIG_FILE"

# Set defaults
REDIS_DB="${REDIS_DB:-0}"
USE_SSL="${USE_SSL:-true}"
REDIS_PORT="${REDIS_PORT:-6380}"

# Validate
if [ -z "$REDIS_HOST" ] || [ -z "$REDIS_PASSWORD" ]; then
    print_error "REDIS_HOST or REDIS_PASSWORD not set in config.sh"
    exit 1
fi

# Build redis-cli command
REDIS_CMD="redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD"
if [ "$USE_SSL" = "true" ]; then
    REDIS_CMD="$REDIS_CMD --tls"
fi
if [ -n "$REDIS_DB" ] && [ "$REDIS_DB" != "0" ]; then
    REDIS_CMD="$REDIS_CMD -n $REDIS_DB"
fi

print_info "Connected to: $REDIS_HOST:$REDIS_PORT (DB: $REDIS_DB)"
echo ""

# Function to safely get info
get_info() {
    $REDIS_CMD INFO "$1" 2>/dev/null || echo "Error getting info"
}

# Function to get memory in human readable format
get_memory() {
    get_info memory | grep "$1" | cut -d: -f2 | tr -d '\r'
}

# Function to get keyspace info
get_keyspace() {
    get_info keyspace | grep "^db${REDIS_DB}:" | cut -d: -f2 | tr -d '\r'
}

# Display current database status
print_info "Current Database Status:"
echo ""

DBSIZE=$($REDIS_CMD DBSIZE 2>/dev/null)
USED_MEMORY=$(get_memory "used_memory_human")
USED_MEMORY_RSS=$(get_memory "used_memory_rss_human")
MAX_MEMORY=$(get_memory "maxmemory_human")
KEYSPACE_INFO=$(get_keyspace)

echo "  📊 Total Keys: $DBSIZE"
echo "  💾 Memory Used: $USED_MEMORY (RSS: $USED_MEMORY_RSS)"
echo "  📈 Max Memory: $MAX_MEMORY"
if [ -n "$KEYSPACE_INFO" ]; then
    echo "  🔑 Keyspace: $KEYSPACE_INFO"
fi
echo ""

# Check for benchmark keys
print_info "Checking for redis-benchmark keys (key:*)..."
BENCHMARK_KEY_COUNT=$($REDIS_CMD --scan --pattern "key:*" 2>/dev/null | wc -l | tr -d ' ')
echo "  Found: $BENCHMARK_KEY_COUNT benchmark keys"
echo ""

if [ "$BENCHMARK_KEY_COUNT" -gt 0 ]; then
    # Sample some keys
    print_info "Sample keys:"
    $REDIS_CMD --scan --pattern "key:*" 2>/dev/null | head -5 | while read key; do
        if [ -n "$key" ]; then
            size=$($REDIS_CMD MEMORY USAGE "$key" 2>/dev/null || echo "unknown")
            ttl=$($REDIS_CMD TTL "$key" 2>/dev/null || echo "unknown")
            echo "  - $key (size: $size bytes, TTL: $ttl)"
        fi
    done
    echo ""
    
    # Estimate memory used by benchmark keys
    if [ "$BENCHMARK_KEY_COUNT" -gt 0 ]; then
        SAMPLE_KEY=$($REDIS_CMD --scan --pattern "key:*" 2>/dev/null | head -1)
        if [ -n "$SAMPLE_KEY" ]; then
            SAMPLE_SIZE=$($REDIS_CMD MEMORY USAGE "$SAMPLE_KEY" 2>/dev/null || echo "0")
            if [ "$SAMPLE_SIZE" != "0" ] && [ "$SAMPLE_SIZE" != "" ]; then
                ESTIMATED_MB=$((SAMPLE_SIZE * BENCHMARK_KEY_COUNT / 1024 / 1024))
                print_warning "Estimated memory used by benchmark keys: ~${ESTIMATED_MB} MB"
                echo ""
            fi
        fi
    fi
    
    # Offer cleanup options
    echo "Cleanup Options:"
    echo "  1) Delete all benchmark keys (key:*)"
    echo "  2) Delete keys from specific range (e.g., key:000000000000 to key:000000001000)"
    echo "  3) Flush entire database (DELETE ALL KEYS!)"
    echo "  4) Exit without changes"
    echo ""
    
    read -p "Select option (1-4): " cleanup_option
    
    case $cleanup_option in
        1)
            print_warning "This will delete $BENCHMARK_KEY_COUNT keys!"
            read -p "Are you sure? (yes/no): " confirm
            if [ "$confirm" = "yes" ]; then
                print_info "Deleting benchmark keys..."
                
                # Delete in batches to avoid blocking
                DELETED=0
                $REDIS_CMD --scan --pattern "key:*" 2>/dev/null | while IFS= read -r key; do
                    if [ -n "$key" ]; then
                        $REDIS_CMD DEL "$key" >/dev/null 2>&1
                        DELETED=$((DELETED + 1))
                        if [ $((DELETED % 100)) -eq 0 ]; then
                            echo -ne "\r  Deleted: $DELETED keys..."
                        fi
                    fi
                done
                echo ""
                print_success "Benchmark keys deleted!"
                
                # Show new status
                NEW_DBSIZE=$($REDIS_CMD DBSIZE 2>/dev/null)
                print_success "New key count: $NEW_DBSIZE"
            else
                print_info "Cleanup cancelled"
            fi
            ;;
        2)
            echo ""
            read -p "Enter start key number (e.g., 0 for key:000000000000): " start_num
            read -p "Enter end key number (e.g., 9999 for key:000000009999): " end_num
            
            print_warning "This will delete keys from key:$(printf '%012d' $start_num) to key:$(printf '%012d' $end_num)"
            read -p "Are you sure? (yes/no): " confirm
            
            if [ "$confirm" = "yes" ]; then
                print_info "Deleting keys in range..."
                DELETED=0
                for i in $(seq $start_num $end_num); do
                    key="key:$(printf '%012d' $i)"
                    $REDIS_CMD DEL "$key" >/dev/null 2>&1
                    DELETED=$((DELETED + 1))
                    if [ $((DELETED % 100)) -eq 0 ]; then
                        echo -ne "\r  Deleted: $DELETED keys..."
                    fi
                done
                echo ""
                print_success "Keys deleted!"
                
                # Show new status
                NEW_DBSIZE=$($REDIS_CMD DBSIZE 2>/dev/null)
                print_success "New key count: $NEW_DBSIZE"
            else
                print_info "Cleanup cancelled"
            fi
            ;;
        3)
            print_error "WARNING: This will delete ALL keys in database $REDIS_DB!"
            read -p "Type 'DELETE ALL' to confirm: " confirm
            
            if [ "$confirm" = "DELETE ALL" ]; then
                print_info "Flushing database..."
                $REDIS_CMD FLUSHDB >/dev/null 2>&1
                print_success "Database flushed!"
                
                # Show new status
                NEW_DBSIZE=$($REDIS_CMD DBSIZE 2>/dev/null)
                print_success "New key count: $NEW_DBSIZE"
            else
                print_info "Flush cancelled"
            fi
            ;;
        4)
            print_info "No changes made"
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
else
    print_success "No benchmark keys found in database $REDIS_DB"
fi

echo ""
print_info "Done!"
echo ""
