#!/bin/bash

# Replace with your GitLab instance URL and private access token
# These values are required for authentication when making API requests to the GitLab server.
GITLAB_URL="URL"  # Replace with your GitLab instance URL
PRIVATE_TOKEN="TOKEN"  # Replace with your private GitLab access token

# Function to get running pipelines for a given project
# Args:
#   project_id: The ID of the project for which to retrieve running pipelines.
# Description:
#   This function uses the GitLab API to fetch all pipelines that have the "running" status
#   for the specified project. It returns pipeline details including ID, status, project ID, ref, and web URL.
get_running_pipelines() {
    project_id=$1  # Assign the first argument to the project_id variable.

    # Use curl to make an API call to the GitLab endpoint that lists running pipelines for the project.
    # The jq command formats the output to show the relevant fields.
    curl --silent --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" \
        "$GITLAB_URL/api/v4/projects/$project_id/pipelines?status=running" | \
        jq '.[] | {id: .id, status: .status, project_id: .project_id, ref: .ref, web_url: .web_url}'
}

# Function to get a list of all projects from GitLab (handling pagination)
# Description:
#   This function retrieves all projects from the GitLab instance. It handles pagination by
#   making repeated API calls to fetch the projects page by page.
#   For each project, it calls the get_running_pipelines function to get the pipelines with "running" status.
get_all_projects() {
    page=1  # Start at the first page.
    per_page=100  # Number of projects to retrieve per page (API limit is 100).

    # Infinite loop to handle pagination. Will break out of the loop when no more projects are found.
    while : ; do
        # Fetch the list of projects for the current page using the GitLab API.
        projects=$(curl --silent --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" \
            "$GITLAB_URL/api/v4/projects?simple=true&per_page=$per_page&page=$page")

        # Process each project in the list. The jq command extracts each project as a JSON object.
        echo "$projects" | jq -c '.[]' | while read project; do
            # Extract the project ID from the project data.
            project_id=$(echo "$project" | jq -r '.id')

            # Call the get_running_pipelines function to fetch running pipelines for the current project.
            get_running_pipelines "$project_id"
        done

        # If fewer projects are returned than the per_page limit, it means we have reached the last page.
        # Break the loop if the number of projects in the current page is less than per_page.
        if [ $(echo "$projects" | jq length) -lt $per_page ]; then
            break  # Exit the loop as there are no more pages.
        fi

        # Move to the next page to fetch more projects.
        page=$((page + 1))
    done
}

# Start the process of fetching running pipelines for all projects.
echo "Fetching running pipelines for all projects..."

# Call the function to retrieve all projects and their running pipelines.
get_all_projects

# Indicate that the process is complete.
echo "Done."

