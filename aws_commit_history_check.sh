#!/bin/bash

# Function to check if input is a valid positive integer
is_valid_number() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ]
}

# Prompt the user for the number of days
while true; do
    read -p "Enter the number of days to check for repository activity: " DAYS

    # Check if the input is a valid positive integer
    if is_valid_number "$DAYS"; then
        break
    else
        echo "Invalid input. Please enter a positive number."
    fi
done

# Calculate the date threshold
DATE_THRESHOLD=$(date -d "-$DAYS days" +%Y-%m-%dT%H:%M:%SZ)
echo "Date threshold for filtering: $DATE_THRESHOLD"

# Output file for repositories that have been pushed to
OUTPUT_FILE="repos_with_activity.txt"

# Empty the file at the start (debugging added)
> $OUTPUT_FILE
if [ $? -ne 0 ]; then
    echo "Failed to clear the file: $OUTPUT_FILE. Check file permissions." >&2
    exit 1
fi
echo "Successfully cleared the file: $OUTPUT_FILE"

# Get the list of all repositories
repos=$(aws codecommit list-repositories --query "repositories[].repositoryName" --output text)
echo "Repositories: $repos"

for repo in $repos; do
    echo "Processing repository: $repo"

    # Get the default branch name for the repository
    default_branch=$(aws codecommit get-repository --repository-name $repo --query "repositoryMetadata.defaultBranch" --output text)
    echo "Default branch for $repo: $default_branch"

    # Check if default branch exists
    if [ "$default_branch" == "None" ] || [ -z "$default_branch" ]; then
        echo "Repository: $repo does not have a default branch, skipping..." >&2
        continue
    fi

    # Get the commit ID of the latest commit on the default branch
    latest_commit=$(aws codecommit get-branch --repository-name $repo --branch-name $default_branch --query "branch.commitId" --output text)
    echo "Latest commit for $repo on branch $default_branch: $latest_commit"

    # Check if latest_commit is valid
    if [ -z "$latest_commit" ]; then
        echo "Could not retrieve commit ID for repository: $repo on branch: $default_branch, skipping..." >&2
        continue
    fi

    # Get the details of the latest commit, including the commit time and committer name
    commit_info=$(aws codecommit get-commit --repository-name $repo --commit-id $latest_commit --query "commit.{date:committer.date, name:committer.name}" --output json)
    echo "Commit info for $repo: $commit_info"

    commit_date=$(echo "$commit_info" | jq -r '.date')
    committer_name=$(echo "$commit_info" | jq -r '.name')

    # Check if the commit date is within the specified time range
    if [[ "$commit_date" > "$DATE_THRESHOLD" ]]; then
        # Try writing to the output file
        echo "Repository: $repo - Branch: $default_branch - Committer: $committer_name - Last Commit: $commit_date" >> $OUTPUT_FILE
        if [ $? -ne 0 ]; then
            echo "Failed to write to the file: $OUTPUT_FILE" >&2
            exit 1
        fi
        echo "Successfully wrote to $OUTPUT_FILE"
    else
        echo "Repository $repo has no recent activity."
    fi
done

# Final message
if [ "$DAYS" -eq 1 ]; then
    echo "Repositories with commits in the past day have been written to $OUTPUT_FILE"
else
    echo "Repositories with commits in the past $DAYS days have been written to $OUTPUT_FILE"
fi

