#!/bin/bash

# Function to generate a random IP address
generate_random_ip() {
    echo "$((RANDOM % 256)).$((RANDOM % 256)).$((RANDOM % 256)).$((RANDOM % 256))"
}

# Number of random IP addresses to generate
NUM_IPS=10

echo "Generating $NUM_IPS random IP addresses and testing them..."

for ((i=1; i<=NUM_IPS; i++)); do
    IP=$(generate_random_ip)
    echo "Testing IP: $IP"
    if ping -c 1 "$IP" &> /dev/null; then
        echo "IP $IP is reachable"
    else
        echo "IP $IP is blocked or unreachable"
    fi
done

