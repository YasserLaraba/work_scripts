#!/bin/bash

# Function to check if input is a valid positive integer
is_valid_number() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ]
}

# Prompt the user for the number of days
while true; do
    read -p "Enter the number of days to check for pipeline executions: " DAYS

    # Check if the input is a valid positive integer
    if is_valid_number "$DAYS"; then
        break
    else
        echo "Invalid input. Please enter a positive number."
    fi
done

# Output file for pipelines that have executions
OUTPUT_FILE="pipelines_with_executions.txt"

# Empty the file at the start
> $OUTPUT_FILE

for pipeline in $(aws codepipeline list-pipelines --query "pipelines[].name" --output text); do
    # Get the executions from the past N days
    executions=$(aws codepipeline list-pipeline-executions \
    --pipeline-name $pipeline \
    --query "pipelineExecutionSummaries[?startTime>=\`date -d '-$DAYS days' +%Y-%m-%dT%H:%M:%SZ\`]" \
    --output json)
    
    # Check if there are any executions in the past N days
    if [ "$executions" != "[]" ]; then
        echo "Pipeline: $pipeline" >> $OUTPUT_FILE
        # Use jq to extract and append the startTime to the file
        echo "$executions" | jq -r '.[] | "ExecutionId: \(.pipelineExecutionId) - StartTime: \(.startTime)"' >> $OUTPUT_FILE
        echo "" >> $OUTPUT_FILE
    fi
done

# Correct message depending on whether the user entered 1 or more days
if [ "$DAYS" -eq 1 ]; then
    echo "Pipelines with executions in the past day have been written to $OUTPUT_FILE"
else
    echo "Pipelines with executions in the past $DAYS days have been written to $OUTPUT_FILE"
fi

