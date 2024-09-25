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
    read -p "Enter the number of days to check for repository activity: " DAYS

    # Validate if the input is a positive number using the is_valid_number function.
    if is_valid_number "$DAYS"; then
        break  # Break the loop if valid input is provided.
    else
        echo "Invalid input. Please enter a positive number."
    fi
done

# Calculate the date threshold for filtering commits.
# This determines how far back in time to look for repository activity.
# The date command is used to get the date 'DAYS' ago in the correct format (ISO 8601).
DATE_THRESHOLD=$(date -d "-$DAYS days" +%Y-%m-%dT%H:%M:%SZ)
echo "Date threshold for filtering: $DATE_THRESHOLD"

# Output file to store the list of repositories with recent activity.
OUTPUT_FILE="repos_with_activity.txt"

# Clear the contents of the output file to start fresh for each run.
# If the file cannot be cleared, it will raise an error and exit.
> $OUTPUT_FILE
if [ $? -ne 0 ]; then
    echo "Failed to clear the file: $OUTPUT_FILE. Check file permissions." >&2
    exit 1  # Exit with an error if the file cannot be cleared.
fi
echo "Successfully cleared the file: $OUTPUT_FILE"

# Fetch the list of all repositories using AWS CLI for CodeCommit.
# The list-repositories command returns repository names in text format.
repos=$(aws codecommit list-repositories --query "repositories[].repositoryName" --output text)
echo "Repositories: $repos"

# Loop through each repository to check its activity.
for repo in $repos; do
    echo "Processing repository: $repo"

    # Get the default branch name of the current repository.
    default_branch=$(aws codecommit get-repository --repository-name $repo --query "repositoryMetadata.defaultBranch" --output text)
    echo "Default branch for $repo: $default_branch"

    # If the repository does not have a default branch, skip it.
    if [ "$default_branch" == "None" ] || [ -z "$default_branch" ]; then
        echo "Repository: $repo does not have a default branch, skipping..." >&2
        continue  # Skip to the next repository.
    fi

    # Get the latest commit ID from the default branch of the repository.
    latest_commit=$(aws codecommit get-branch --repository-name $repo --branch-name $default_branch --query "branch.commitId" --output text)
    echo "Latest commit for $repo on branch $default_branch: $latest_commit"

    # If no commit ID is retrieved, skip the repository.
    if [ -z "$latest_commit" ]; then
        echo "Could not retrieve commit ID for repository: $repo on branch: $default_branch, skipping..." >&2
        continue  # Skip to the next repository.
    fi

    # Get details of the latest commit, such as commit date and committer name, in JSON format.
    commit_info=$(aws codecommit get-commit --repository-name $repo --commit-id $latest_commit --query "commit.{date:committer.date, name:committer.name}" --output json)
    echo "Commit info for $repo: $commit_info"

    # Extract commit date and committer name using jq, a JSON parsing tool.
    commit_date=$(echo "$commit_info" | jq -r '.date')
    committer_name=$(echo "$commit_info" | jq -r '.name')

    # Check if the commit date is more recent than the threshold date.
    if [[ "$commit_date" > "$DATE_THRESHOLD" ]]; then
        # If the commit is within the date range, write the details to the output file.
        echo "Repository: $repo - Branch: $default_branch - Committer: $committer_name - Last Commit: $commit_date" >> $OUTPUT_FILE
        # Check if writing to the file was successful.
        if [ $? -ne 0 ]; then
            echo "Failed to write to the file: $OUTPUT_FILE" >&2
            exit 1  # Exit with an error if the write operation fails.
        fi
        echo "Successfully wrote to $OUTPUT_FILE"
    else
        # If the commit is outside the date range, print a message and continue.
        echo "Repository $repo has no recent activity."
    fi
done

# Final message summarizing the results depending on whether the user checked for 1 day or more.
if [ "$DAYS" -eq 1 ]; then
    echo "Repositories with commits in the past day have been written to $OUTPUT_FILE"
else
    echo "Repositories with commits in the past $DAYS days have been written to $OUTPUT_FILE"
fi

