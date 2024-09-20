#!/bin/bash

# File containing the list of known IP addresses and their corresponding domains
IP_LIST="known_ip_list.txt"

# Check if the IP list file exists
if [[ ! -f "$IP_LIST" ]]; then
    echo "IP list file $IP_LIST not found!"
    exit 1
fi

# Function to strip out comments and whitespace, and retrieve IP and domain
get_ip_and_domain() {
    local line="$1"
    local ip=$(echo "$line" | awk '{print $1}')
    local domain=$(echo "$line" | awk '{$1=""; print $0}' | sed -e 's/^[ \t]*//')
    echo "$ip $domain"
}

# Array to hold reachable and unreachable results
reachable_results=()
unreachable_results=()

echo "Testing all IP addresses from the list..."
echo "-----------------------------------------------"

# Read each line from the IP list file
while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -n "$line" ]]; then
        ENTRY=$(get_ip_and_domain "$line")
        IP=$(echo "$ENTRY" | awk '{print $1}')
        DOMAIN=$(echo "$ENTRY" | awk '{$1=""; print $0}' | sed -e 's/^[ \t]*//')
        echo "Testing IP: $IP ($DOMAIN)"
        PING_OUTPUT=$(ping -c 1 "$IP" 2>&1)
        PING_EXIT_STATUS=$?
        if [[ $PING_EXIT_STATUS -eq 0 ]]; then
            result="IP $IP ($DOMAIN) is reachable"
            reachable_results+=("$result")
        else
            result="IP $IP ($DOMAIN) is blocked or unreachable"
            unreachable_results+=("$result")
        fi
        echo "Result: $result"
        echo "-----------------------------------------------"
    fi
done < "$IP_LIST"

# Output all reachable results first
for result in "${reachable_results[@]}"; do
    echo "$result"
done

# Output all unreachable results last
for result in "${unreachable_results[@]}"; do
    echo "$result"
done
