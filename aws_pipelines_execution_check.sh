#!/bin/bash

# Function to check if input is a valid positive integer
# This function uses a regular expression to ensure the input is a number
# and checks if the number is greater than zero.
is_valid_number() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ]
}

# Prompt the user to input the number of days
# The loop will keep asking for a valid input until the user provides a positive integer.
while true; do
    read -p "Enter the number of days to check for pipeline executions: " DAYS

    # Validate if the input is a positive number using the is_valid_number function.
    if is_valid_number "$DAYS"; then
        break  # Break the loop if valid input is provided.
    else
        echo "Invalid input. Please enter a positive number."
    fi
done

# Output file to store the pipelines with recent executions.
OUTPUT_FILE="pipelines_with_executions.txt"

# Clear the contents of the output file to start fresh for each run.
# The '>' operator empties the file. It doesn't handle errors but assumes the file is writable.
> $OUTPUT_FILE

# Loop through all pipelines retrieved from AWS CodePipeline using the AWS CLI.
# The list-pipelines command returns all pipeline names.
for pipeline in $(aws codepipeline list-pipelines --query "pipelines[].name" --output text); do
    # Get pipeline executions that have occurred within the last N days using AWS CLI.
    # The list-pipeline-executions command fetches execution details, and the query filters
    # based on the execution startTime, ensuring only those newer than N days are included.
    executions=$(aws codepipeline list-pipeline-executions \
    --pipeline-name $pipeline \
    --query "pipelineExecutionSummaries[?startTime>=\`date -d '-$DAYS days' +%Y-%m-%dT%H:%M:%SZ\`]" \
    --output json)

    # Check if there are any executions in the past N days.
    # If the 'executions' variable is not an empty array, it means there were pipeline executions.
    if [ "$executions" != "[]" ]; then
        # Write the pipeline name to the output file.
        echo "Pipeline: $pipeline" >> $OUTPUT_FILE

        # Use jq to extract each execution's ID and start time, and append it to the output file.
        # jq is a JSON processor that helps to parse and extract the needed values.
        echo "$executions" | jq -r '.[] | "ExecutionId: \(.pipelineExecutionId) - StartTime: \(.startTime)"' >> $OUTPUT_FILE

        # Add a blank line for readability between pipeline entries.
        echo "" >> $OUTPUT_FILE
    fi
done

# Final message summarizing the results depending on the number of days entered.
# If the user entered 1 day, the message will be singular, otherwise it will be plural.
if [ "$DAYS" -eq 1 ]; then
    echo "Pipelines with executions in the past day have been written to $OUTPUT_FILE"
else
    echo "Pipelines with executions in the past $DAYS days have been written to $OUTPUT_FILE"
fi

