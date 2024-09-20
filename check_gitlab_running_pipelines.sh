#!/bin/bash

# Replace with your GitLab instance URL and private access token
GITLAB_URL="URL"
PRIVATE_TOKEN="TOKEN"

# Function to get running pipelines for a project
get_running_pipelines() {
    project_id=$1
    curl --silent --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" "$GITLAB_URL/api/v4/projects/$project_id/pipelines?status=running" | jq '.[] | {id: .id, status: .status, project_id: .project_id, ref: .ref, web_url: .web_url}'
}

# Get the list of all projects (handling pagination if necessary)
get_all_projects() {
    page=1
    per_page=100
    while : ; do
        projects=$(curl --silent --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" "$GITLAB_URL/api/v4/projects?simple=true&per_page=$per_page&page=$page")
        echo "$projects" | jq -c '.[]' | while read project; do
            project_id=$(echo "$project" | jq -r '.id')
            get_running_pipelines "$project_id"
        done
        # Break the loop if there are no more projects
        if [ $(echo "$projects" | jq length) -lt $per_page ]; then
            break
        fi
        page=$((page + 1))
    done
}

# Start the process
echo "Fetching running pipelines for all projects..."
get_all_projects
echo "Done."

