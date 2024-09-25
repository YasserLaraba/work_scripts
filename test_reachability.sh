#!/bin/bash

# File containing the list of known IP addresses and their corresponding domains
# The file should have entries in the format: "IP_ADDRESS DOMAIN_NAME".
IP_LIST="known_ip_list.txt"

# Check if the IP list file exists
# If the file does not exist, an error message is printed and the script exits with a non-zero status.
if [[ ! -f "$IP_LIST" ]]; then
    echo "IP list file $IP_LIST not found!"
    exit 1  # Exit the script with a failure code.
fi

# Function to strip out comments, whitespace, and extract IP and domain from each line
# Args:
#   line: A line from the IP list file, containing an IP address and corresponding domain.
# Returns:
#   A string with the IP address and domain name separated by a space.
get_ip_and_domain() {
    local line="$1"  # The input line passed as an argument.
    
    # Extract the IP address (the first word) from the line using awk.
    local ip=$(echo "$line" | awk '{print $1}')
    
    # Extract the rest of the line (the domain name) by removing the first word and trimming leading whitespace.
    local domain=$(echo "$line" | awk '{$1=""; print $0}' | sed -e 's/^[ \t]*//')
    
    # Return both the IP and domain as a single string.
    echo "$ip $domain"
}

# Arrays to store the results of the reachability tests.
# reachable_results will hold IP addresses that are reachable.
# unreachable_results will hold IP addresses that are unreachable or blocked.
reachable_results=()
unreachable_results=()

echo "Testing all IP addresses from the list..."
echo "-----------------------------------------------"

# Read each line from the IP list file
# IFS= ensures that the entire line is read, and the loop will continue even if the last line is missing a newline.
while IFS= read -r line || [[ -n "$line" ]]; do
    # Check if the line is not empty
    if [[ -n "$line" ]]; then
        # Call the get_ip_and_domain function to extract the IP and domain from the line.
        ENTRY=$(get_ip_and_domain "$line")
        
        # Extract the IP and domain from the entry returned by the function.
        IP=$(echo "$ENTRY" | awk '{print $1}')
        DOMAIN=$(echo "$ENTRY" | awk '{$1=""; print $0}' | sed -e 's/^[ \t]*//')
        
        # Print a message indicating which IP and domain are being tested.
        echo "Testing IP: $IP ($DOMAIN)"
        
        # Ping the IP address once and capture the output and exit status.
        PING_OUTPUT=$(ping -c 1 "$IP" 2>&1)
        PING_EXIT_STATUS=$?  # Capture the exit status of the ping command.
        
        # If the ping was successful (exit status 0), store the result as reachable.
        if [[ $PING_EXIT_STATUS -eq 0 ]]; then
            result="IP $IP ($DOMAIN) is reachable"
            reachable_results+=("$result")  # Add the result to the reachable results array.
        else
            # If the ping failed, store the result as unreachable or blocked.
            result="IP $IP ($DOMAIN) is blocked or unreachable"
            unreachable_results+=("$result")  # Add the result to the unreachable results array.
        fi
        
        # Print the result of the ping test.
        echo "Result: $result"
        echo "-----------------------------------------------"
    fi
done < "$IP_LIST"  # Read from the IP list file line by line.

# Output all reachable IP addresses and domains first.
for result in "${reachable_results[@]}"; do
    echo "$result"
done

# Output all unreachable or blocked IP addresses and domains last.
for result in "${unreachable_results[@]}"; do
    echo "$result"
done

