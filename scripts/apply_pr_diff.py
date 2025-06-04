#!/usr/bin/env python3
"""
Gitea PR Sync Script
Fetches PRs from a Gitea repository, allows selection, and applies them as diffs to current repo.
"""

import subprocess
import sys
import os
import json
import argparse
import urllib.request
import urllib.parse
import urllib.error
from urllib.parse import urlparse

class GiteaPRSync:
    """Class for syncing PRs from Gitea repository to local repo"""
    
    def __init__(self, gitea_url, owner, repo, token=None):
        self.gitea_url = gitea_url.rstrip('/')
        self.owner = owner
        self.repo = repo
        self.token = token
    
    def list_prs(self):
        """Fetch all open PRs from the Gitea repository."""
        params = urllib.parse.urlencode({'state': 'open', 'sort': 'updated', 'direction': 'desc'})
        url = f"{self.gitea_url}/api/v1/repos/{self.owner}/{self.repo}/pulls?{params}"
        
        headers = {}
        if self.token:
            headers['Authorization'] = f'token {self.token}'
        
        request = urllib.request.Request(url, headers=headers, method="GET")
        
        try:
            with urllib.request.urlopen(request) as response:
                return json.loads(response.read().decode('utf-8'))
        except urllib.error.HTTPError as e:
            error_message = e.read().decode('utf-8')
            print(f"Error fetching PRs: {error_message}")
            return []
    
    def display_prs(self, prs):
        """Display PRs in a user-friendly format."""
        if not prs:
            print("No open PRs found.")
            return
        
        print("\nAvailable PRs:")
        print("-" * 80)
        for i, pr in enumerate(prs, 1):
            print(f"{i:2d}. #{pr['number']} - {pr['title']}")
            print(f"    Author: {pr['user']['login']}")
            print(f"    Updated: {pr['updated_at'][:10]}")
            print(f"    Branch: {pr['head']['ref']} -> {pr['base']['ref']}")
            print()
    
    def get_pr_diff(self, pr_number):
        """Fetch the diff for a specific PR."""
        url = f"{self.gitea_url}/api/v1/repos/{self.owner}/{self.repo}/pulls/{pr_number}.diff"
        
        headers = {}
        if self.token:
            headers['Authorization'] = f'token {self.token}'
        
        request = urllib.request.Request(url, headers=headers, method="GET")
        
        try:
            with urllib.request.urlopen(request) as response:
                return response.read().decode('utf-8')
        except urllib.error.HTTPError as e:
            error_message = e.read().decode('utf-8')
            print(f"Error fetching diff for PR #{pr_number}: {error_message}")
            return ""
    
    def save_diff_file(self, pr_number, diff_content):
        """Save diff content to a file."""
        filename = f"pr_{pr_number}.diff"
        try:
            with open(filename, 'w', encoding='utf-8') as f:
                f.write(diff_content)
            return filename
        except IOError as e:
            print(f"Error saving diff file: {e}")
            return ""
    
    def apply_diff(self, diff_file):
        """Apply a diff file to the current repository."""
        try:
            # First try git apply
            result = subprocess.run(['git', 'apply', '--check', diff_file], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                result = subprocess.run(['git', 'apply', diff_file], 
                                      capture_output=True, text=True)
                if result.returncode == 0:
                    print(f"✓ Successfully applied {diff_file}")
                    return True
                else:
                    print(f"✗ Failed to apply {diff_file}: {result.stderr}")
            else:
                print(f"✗ Diff check failed for {diff_file}: {result.stderr}")
            
            # Try patch as fallback
            print("Trying patch command as fallback...")
            result = subprocess.run(['patch', '-p1', '--dry-run'], 
                                  input=open(diff_file).read(), 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                result = subprocess.run(['patch', '-p1'], 
                                      input=open(diff_file).read(), 
                                      capture_output=True, text=True)
                if result.returncode == 0:
                    print(f"✓ Successfully applied {diff_file} with patch")
                    return True
                else:
                    print(f"✗ Failed to apply {diff_file} with patch: {result.stderr}")
            
            return False
        except Exception as e:
            print(f"Error applying diff: {e}")
            return False
    
    @staticmethod
    def parse_repo_url(url):
        """Parse Gitea repository URL to extract components."""
        parsed = urlparse(url)
        path_parts = parsed.path.strip('/').split('/')
        if len(path_parts) >= 2:
            # Remove .git suffix if present
            repo_name = path_parts[1]
            if repo_name.endswith('.git'):
                repo_name = repo_name[:-4]
            return f"{parsed.scheme}://{parsed.netloc}", path_parts[0], repo_name
        return None, None, None

def parse_arguments():
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description="Sync PRs from Gitea repository to local repo")
    
    parser.add_argument(
        "--repo-url",
        type=str,
        required=True,
        help="Gitea repository URL (e.g., http://localhost:3000/owner/repo)"
    )
    
    parser.add_argument(
        "--token",
        type=str,
        help="Gitea API token (optional for public repos)"
    )
    
    parser.add_argument(
        "--prs",
        type=str,
        help="Comma-separated list of PR numbers to sync (e.g., '1,3,5')"
    )
    
    
    return parser.parse_args()


def main():
    """Main execution method"""
    args = parse_arguments()
    
    print("Gitea PR Sync Tool")
    print("==================")
    
    # Parse repository URL
    gitea_url, owner, repo = GiteaPRSync.parse_repo_url(args.repo_url)
    if not all([gitea_url, owner, repo]):
        print("Invalid repository URL format. Expected: http://gitea-server/owner/repo")
        sys.exit(1)
    
    # Initialize sync object
    sync = GiteaPRSync(gitea_url, owner, repo, args.token)
    
    # Fetch and display PRs
    print(f"\nFetching PRs from {owner}/{repo}...")
    prs = sync.list_prs()
    
    if not prs:
        print("No PRs found or error occurred.")
        sys.exit(1)
    
    sync.display_prs(prs)
    
    # Get user selection
    if args.prs:
        selection = args.prs
    else:
        print("Enter PR numbers to sync (comma-separated, e.g., '1,3,5'):")
        selection = input("Selection: ").strip()
    
    if not selection:
        print("No selection made.")
        sys.exit(0)
    
    try:
        selected_indices = [int(x.strip()) - 1 for x in selection.split(',')]
        selected_prs = [prs[i] for i in selected_indices if 0 <= i < len(prs)]
    except (ValueError, IndexError):
        print("Invalid selection.")
        sys.exit(1)
    
    if not selected_prs:
        print("No valid PRs selected.")
        sys.exit(1)
    
    # Process selected PRs
    print(f"\nProcessing {len(selected_prs)} selected PR(s)...")
    
    diff_files = []
    for pr in selected_prs:
        pr_number = pr['number']
        print(f"\nFetching diff for PR #{pr_number}: {pr['title']}")
        
        diff_content = sync.get_pr_diff(pr_number)
        if diff_content:
            diff_file = sync.save_diff_file(pr_number, diff_content)
            if diff_file:
                diff_files.append(diff_file)
                print(f"✓ Saved diff to {diff_file}")
            else:
                print(f"✗ Failed to save diff for PR #{pr_number}")
        else:
            print(f"✗ Failed to fetch diff for PR #{pr_number}")
    
    if not diff_files:
        print("No diff files created.")
        sys.exit(1)
    
    # Apply diffs
    print(f"\nApplying {len(diff_files)} diff file(s)...")
    apply_confirm = input("Proceed with applying diffs? (Y/n): ").strip().lower()
    if apply_confirm == 'n':
        print("Diff files saved but not applied.")
        print(f"Files: {', '.join(diff_files)}")
        sys.exit(0)
    
    successful = 0
    for diff_file in diff_files:
        if sync.apply_diff(diff_file):
            successful += 1
    
    print(f"\nSummary: {successful}/{len(diff_files)} diffs applied successfully.")
    
    # Clean up diff files
    cleanup_response = input("Delete diff files? (Y/n): ").strip().lower()
    if cleanup_response != 'n':
        for diff_file in diff_files:
            try:
                os.remove(diff_file)
                print(f"✓ Deleted {diff_file}")
            except OSError as e:
                print(f"✗ Failed to delete {diff_file}: {e}")


if __name__ == "__main__":
    main()