import os
import requests
import subprocess

# Configuration section
# Replace these values with your GitLab instance URL, personal access token, and the directory to store cloned repositories.
GITLAB_URL = 'URL'  # Replace with your GitLab instance URL
PRIVATE_TOKEN = 'TOKEN'   # Replace with your private access token
CLONE_DIR = 'DIR'               # Directory where repos will be cloned

# Headers used for API requests to authenticate using the private token.
headers = {
    'Private-Token': PRIVATE_TOKEN
}

def get_all_groups():
    """
    Retrieve all groups from the GitLab instance.
    
    Uses pagination to fetch all groups available in GitLab. It will request up to 100 groups per page.
    Continues to make requests until no more data is returned (i.e., all groups have been fetched).
    
    Returns:
        list: A list of all GitLab groups.
    """
    url = f'{GITLAB_URL}/api/v4/groups'
    params = {'per_page': 100, 'all_available': True}  # Request 100 groups per page.
    groups = []
    page = 1  # Start at page 1

    # Loop through pages until no more data is returned
    while True:
        response = requests.get(url, headers=headers, params={**params, 'page': page})
        response.raise_for_status()  # If request fails, raise an error.
        data = response.json()  # Parse response as JSON.
        if not data:  # Exit loop if no more data (end of pagination).
            break
        groups.extend(data)  # Add current page's groups to the list.
        page += 1  # Move to the next page.

    return groups  # Return the full list of groups.

def get_group_projects(group_id):
    """
    Get all projects belonging to a specific group.
    
    Args:
        group_id (int): The ID of the GitLab group.
        
    Returns:
        list: A list of projects in the specified group.
    """
    url = f'{GITLAB_URL}/api/v4/groups/{group_id}/projects'
    projects = []
    page = 1  # Start at page 1

    # Loop through pages to get all projects in the group
    while True:
        response = requests.get(url, headers=headers, params={'per_page': 100, 'page': page})
        response.raise_for_status()  # If request fails, raise an error.
        data = response.json()  # Parse response as JSON.
        if not data:  # Exit loop if no more data (end of pagination).
            break
        projects.extend(data)  # Add current page's projects to the list.
        page += 1  # Move to the next page.

    return projects  # Return the full list of projects.

def clone_repo(repo_url, clone_dir):
    """
    Clone or update a repository to the specified local directory.
    
    If the repository already exists, it will pull the latest changes. If it does not exist, it will clone the repository.
    
    Args:
        repo_url (str): The URL of the Git repository.
        clone_dir (str): The local directory where the repo will be cloned.
    """
    # Ensure the directory exists; create it if it does not.
    if not os.path.exists(clone_dir):
        os.makedirs(clone_dir)

    # Get repository name from the URL (remove .git suffix if present).
    repo_name = repo_url.split('/')[-1].replace('.git', '')
    repo_path = os.path.join(clone_dir, repo_name)

    if os.path.exists(repo_path):
        # If the repository already exists locally, pull the latest changes.
        print(f"Repository {repo_name} already exists. Pulling latest changes.")
        subprocess.run(['git', '-C', repo_path, 'pull'], check=True)
    else:
        # If the repository does not exist locally, clone it.
        print(f"Cloning repository {repo_name}.")
        subprocess.run(['git', 'clone', repo_url, repo_path], check=True)

def process_group(group, parent_dir, processed_groups):
    """
    Process a GitLab group: clone its repositories and handle its subgroups.
    
    This function ensures that repositories within the group are cloned to the correct local directory.
    It also keeps track of groups that have been processed to avoid duplicates.
    
    Args:
        group (dict): The GitLab group data.
        parent_dir (str): The local directory where the group's repositories will be cloned.
        processed_groups (set): A set to track which groups have already been processed.
    """
    if group['id'] in processed_groups:
        # If this group has already been processed, skip it.
        return

    # Mark this group as processed
    processed_groups.add(group['id'])

    # Create the directory for the group using its name.
    group_dir = os.path.join(parent_dir, group['name'].replace('/', '_'))
    if not os.path.exists(group_dir):
        os.makedirs(group_dir)

    print(f"Processing group: {group['name']} (ID: {group['id']}, Parent ID: {group['parent_id']})")

    # Fetch and clone all projects in this group.
    projects = get_group_projects(group['id'])
    print(f"  Found {len(projects)} projects in group {group['name']}.")

    for project in projects:
        print(f"  Cloning repository: {project['name']}")
        clone_repo(project['ssh_url_to_repo'], group_dir)

def find_parent_dir(parent_id, all_groups):
    """
    Find the directory path of a parent group given its ID.
    
    Args:
        parent_id (int): The ID of the parent group.
        all_groups (list): The list of all groups.
        
    Returns:
        str: The local directory name of the parent group.
        
    Raises:
        ValueError: If the parent group is not found in the list.
    """
    for group in all_groups:
        if group['id'] == parent_id:
            return group['name'].replace('/', '_')
    raise ValueError(f"Parent group with ID {parent_id} not found.")

def main():
    """
    Main function to execute the repository cloning process.
    
    It retrieves all groups from GitLab, processes root groups first, and then processes subgroups
    while ensuring the correct directory structure is followed.
    """
    # Fetch all GitLab groups.
    all_groups = get_all_groups()
    print(f"Found {len(all_groups)} total groups.")

    # Separate root groups (groups with no parent) and subgroups.
    root_groups = [group for group in all_groups if group['parent_id'] is None]
    subgroups = [group for group in all_groups if group['parent_id'] is not None]

    # Set to track already processed groups.
    processed_groups = set()

    # Process all root groups.
    for group in root_groups:
        print(f"Processing root group: {group['name']} (ID: {group['id']})")
        process_group(group, CLONE_DIR, processed_groups)

    # Process subgroups by finding their parent directory.
    for group in subgroups:
        try:
            parent_dir = os.path.join(CLONE_DIR, find_parent_dir(group['parent_id'], all_groups))
            print(f"Processing subgroup: {group['name']} (ID: {group['id']})")
            process_group(group, parent_dir, processed_groups)
        except ValueError as e:
            print(f"Error: {e}")

if __name__ == '__main__':
    # If the script is run directly, execute the main function.
    main()

