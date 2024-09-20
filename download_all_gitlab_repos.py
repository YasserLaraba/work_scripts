import os
import requests
import subprocess

# Configuration
GITLAB_URL = 'URL'  # Replace with your GitLab instance URL
PRIVATE_TOKEN = 'TOKEN'   # Replace with your private access token
CLONE_DIR = 'DIR'               # Directory where repos will be cloned

# Headers for the API requests
headers = {
    'Private-Token': PRIVATE_TOKEN
}

def get_all_groups():
    """Get all groups from GitLab."""
    url = f'{GITLAB_URL}/api/v4/groups'
    params = {'per_page': 100, 'all_available': True}
    groups = []
    page = 1

    while True:
        response = requests.get(url, headers=headers, params={**params, 'page': page})
        response.raise_for_status()
        data = response.json()
        if not data:
            break
        groups.extend(data)
        page += 1

    return groups

def get_group_projects(group_id):
    """Get all projects in a group."""
    url = f'{GITLAB_URL}/api/v4/groups/{group_id}/projects'
    projects = []
    page = 1

    while True:
        response = requests.get(url, headers=headers, params={'per_page': 100, 'page': page})
        response.raise_for_status()
        data = response.json()
        if not data:
            break
        projects.extend(data)
        page += 1

    return projects

def clone_repo(repo_url, clone_dir):
    """Clone a repository to the specified directory."""
    if not os.path.exists(clone_dir):
        os.makedirs(clone_dir)

    repo_name = repo_url.split('/')[-1].replace('.git', '')
    repo_path = os.path.join(clone_dir, repo_name)

    if os.path.exists(repo_path):
        print(f"Repository {repo_name} already exists. Pulling latest changes.")
        subprocess.run(['git', '-C', repo_path, 'pull'], check=True)
    else:
        print(f"Cloning repository {repo_name}.")
        subprocess.run(['git', 'clone', repo_url, repo_path], check=True)

def process_group(group, parent_dir, processed_groups):
    """Process a group, its subgroups, and projects."""
    if group['id'] in processed_groups:
        return

    # Mark this group as processed
    processed_groups.add(group['id'])

    # Create the directory for the group
    group_dir = os.path.join(parent_dir, group['name'].replace('/', '_'))
    if not os.path.exists(group_dir):
        os.makedirs(group_dir)

    print(f"Processing group: {group['name']} (ID: {group['id']}, Parent ID: {group['parent_id']})")

    # Clone all projects in this group
    projects = get_group_projects(group['id'])
    print(f"  Found {len(projects)} projects in group {group['name']}.")

    for project in projects:
        print(f"  Cloning repository: {project['name']}")
        clone_repo(project['ssh_url_to_repo'], group_dir)

def find_parent_dir(parent_id, all_groups):
    """Find the directory path of the parent group."""
    for group in all_groups:
        if group['id'] == parent_id:
            return group['name'].replace('/', '_')
    raise ValueError(f"Parent group with ID {parent_id} not found.")

def main():
    # Get all groups
    all_groups = get_all_groups()
    print(f"Found {len(all_groups)} total groups.")

    # Separate root groups and subgroups
    root_groups = [group for group in all_groups if group['parent_id'] is None]
    subgroups = [group for group in all_groups if group['parent_id'] is not None]

    # Set to track processed groups
    processed_groups = set()

    # Process all root groups first
    for group in root_groups:
        print(f"Processing root group: {group['name']} (ID: {group['id']})")
        process_group(group, CLONE_DIR, processed_groups)

    # Now process subgroups in context
    for group in subgroups:
        try:
            parent_dir = os.path.join(CLONE_DIR, find_parent_dir(group['parent_id'], all_groups))
            print(f"Processing subgroup: {group['name']} (ID: {group['id']})")
            process_group(group, parent_dir, processed_groups)
        except ValueError as e:
            print(f"Error: {e}")

if __name__ == '__main__':
    main()

