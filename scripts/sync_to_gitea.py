#!/usr/bin/env python3

import os
import subprocess
import urllib.request
import urllib.parse
import json
import argparse
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading


class GiteaSync:
    """Class for syncing local Git repositories to Gitea server"""

    def __init__(self, projects_dir, gitea_url, username, token, remove_remote=False, auto_yes=False):
        """Initialize GiteaSync with configuration parameters"""
        self.projects_dir = os.path.abspath(projects_dir)
        self.gitea_url = gitea_url.rstrip('/')
        self.username = username
        self.token = token
        self.remove_remote = remove_remote
        self.auto_yes = auto_yes
        self.print_lock = threading.Lock()  # For thread-safe printing

    def find_git_repos(self):
        """Efficiently finds Git repositories using optimized traversal."""
        git_repos = []

        # Skip common non-project directories
        skip_dirs = {
            '.git', 'node_modules', '.next', '.nuxt', 'dist', 'build',
            '.vscode', '.idea', '__pycache__', '.pytest_cache', 'venv',
            '.env', 'target', '.cargo', '.gradle', 'vendor', '.npm',
            '.cache', '.temp', '.tmp', 'logs', '.DS_Store'
        }

        def fast_walk(path, max_depth=3):
            """Fast walk with depth limit and smart skipping."""
            try:
                items = os.listdir(path)
            except (PermissionError, OSError):
                return

            has_git = '.git' in items
            if has_git:
                git_repos.append(path)
                return  # Don't traverse deeper if we found a git repo

            if max_depth <= 0:
                return

            # Only traverse directories that might contain projects
            for item in items:
                if item.startswith('.') and item not in {'.git'}:
                    continue
                if item in skip_dirs:
                    continue

                item_path = os.path.join(path, item)
                if os.path.isdir(item_path):
                    fast_walk(item_path, max_depth - 1)

        print(f"Scanning {self.projects_dir} (max depth: 3)...")
        fast_walk(self.projects_dir)
        return git_repos

    def create_gitea_repo(self, repo_name):
        """Creates a new repository in Gitea."""
        url = f"{self.gitea_url}/api/v1/user/repos"

        data = {
            "name": repo_name,
            "private": True,
            "auto_init": False,
            "has_actions": False
        }

        headers = {
            "Content-Type": "application/json",
            "Authorization": f"token {self.token}"
        }

        request = urllib.request.Request(
            url,
            data=json.dumps(data).encode('utf-8'),
            headers=headers,
            method="POST"
        )

        try:
            with urllib.request.urlopen(request) as response:
                return json.loads(response.read().decode('utf-8'))
        except urllib.error.HTTPError as e:
            error_message = e.read().decode('utf-8')
            print(f"Failed to create repository {repo_name}: {error_message}")
            return None

    def disable_actions_for_repo(self, repo_name):
        """Disable Actions for a repository by updating its settings."""
        url = f"{self.gitea_url}/api/v1/repos/{self.username}/{repo_name}"

        data = {
            "has_actions": False
        }

        headers = {
            "Content-Type": "application/json",
            "Authorization": f"token {self.token}"
        }

        request = urllib.request.Request(
            url,
            data=json.dumps(data).encode('utf-8'),
            headers=headers,
            method="PATCH"
        )

        try:
            with urllib.request.urlopen(request) as response:
                print(f"Actions disabled for {repo_name}")
                return True
        except urllib.error.HTTPError as e:
            error_message = e.read().decode('utf-8')
            print(f"Failed to disable Actions for {repo_name}: {error_message}")
            # Don't fail the whole process if we can't disable actions
            return False

    def get_git_status(self, repo_path):
        """Get git status information."""
        try:
            result = subprocess.run(
                ["git", "status", "--porcelain"],
                cwd=repo_path,
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError:
            return ""

    def stash_changes(self, repo_path):
        """Stash current changes if any exist."""
        try:
            status = self.get_git_status(repo_path)
            if not status:
                return None  # No changes to stash

            # Create a stash with timestamp
            import time
            timestamp = int(time.time())
            stash_message = f"gitea-sync-backup-{timestamp}"

            result = subprocess.run(
                ["git", "stash", "push", "-u", "-m", stash_message],
                cwd=repo_path,
                capture_output=True,
                text=True,
                check=True
            )

            self.safe_print(f"💾 Stashed changes in {os.path.basename(repo_path)}")
            return stash_message
        except subprocess.CalledProcessError as e:
            self.safe_print(f"⚠️  Failed to stash changes in {os.path.basename(repo_path)}: {e}")
            return None

    def restore_changes(self, repo_path, stash_message):
        """Restore previously stashed changes."""
        if not stash_message:
            return True

        try:
            # Find the stash with our message
            result = subprocess.run(
                ["git", "stash", "list"],
                cwd=repo_path,
                capture_output=True,
                text=True,
                check=True
            )

            stash_ref = None
            for line in result.stdout.split('\n'):
                if stash_message in line:
                    stash_ref = line.split(':')[0]
                    break

            if stash_ref:
                # Apply and drop the specific stash
                subprocess.run(
                    ["git", "stash", "pop", stash_ref],
                    cwd=repo_path,
                    capture_output=True,
                    text=True,
                    check=True
                )
                self.safe_print(f"🔄 Restored changes in {os.path.basename(repo_path)}")
            else:
                self.safe_print(f"⚠️  Could not find stash {stash_message} in {os.path.basename(repo_path)}")

            return True
        except subprocess.CalledProcessError as e:
            self.safe_print(f"⚠️  Failed to restore changes in {os.path.basename(repo_path)}: {e}")
            return False

    def get_current_branch(self, repo_path):
        """Get the current branch name."""
        try:
            result = subprocess.run(
                ["git", "rev-parse", "--abbrev-ref", "HEAD"],
                cwd=repo_path,
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError:
            return None

    def get_all_local_branches(self, repo_path):
        """Get all local branches."""
        try:
            result = subprocess.run(
                ["git", "branch", "--format=%(refname:short)"],
                cwd=repo_path,
                capture_output=True,
                text=True,
                check=True
            )
            branches = [branch.strip() for branch in result.stdout.split('\n') if branch.strip()]
            return branches
        except subprocess.CalledProcessError:
            return []

    def get_remote_tracking_branches(self, repo_path):
        """Get all local branches that track remote branches."""
        try:
            result = subprocess.run(
                ["git", "for-each-ref", "--format=%(refname:short) %(upstream:short)", "refs/heads/"],
                cwd=repo_path,
                capture_output=True,
                text=True,
                check=True
            )

            tracking_branches = {}
            for line in result.stdout.split('\n'):
                if line.strip():
                    parts = line.strip().split(' ', 1)
                    if len(parts) == 2 and parts[1]:  # Has upstream
                        local_branch = parts[0]
                        upstream_branch = parts[1]
                        tracking_branches[local_branch] = upstream_branch

            return tracking_branches
        except subprocess.CalledProcessError:
            return {}

    def get_remotes(self, repo_path):
        """Get all configured remotes."""
        try:
            result = subprocess.run(
                ["git", "remote", "-v"],
                cwd=repo_path,
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError:
            return ""

    def pull_latest_changes(self, repo_path):
        """Pull latest changes for all tracking branches from the original remote."""
        try:
            repo_name = os.path.basename(repo_path)

            # Stash any uncommitted changes first
            stash_message = self.stash_changes(repo_path)

            try:
                # Debug: show remotes
                remotes = self.get_remotes(repo_path)
                if remotes:
                    self.safe_print(f"🔍 Remotes in {repo_name}:")
                    for line in remotes.split('\n'):
                        if line.strip():
                            self.safe_print(f"    {line}")
                else:
                    self.safe_print(f"⚠️  No remotes configured in {repo_name}")
                    return True

                # Get current branch to restore later
                current_branch = self.get_current_branch(repo_path)
                if not current_branch or current_branch == "HEAD":
                    self.safe_print(f"⚠️  Detached HEAD in {repo_name} - will only fetch")

                self.safe_print(f"🔄 Fetching changes for {repo_name}...")

                # Simple fetch from origin
                fetch_result = subprocess.run(
                    ["git", "fetch"],
                    cwd=repo_path,
                    capture_output=True,
                    text=True
                )

                if fetch_result.returncode != 0:
                    self.safe_print(f"⚠️  fetch failed for {repo_name}: {fetch_result.stderr}")
                    self.safe_print(f"ℹ️  Skipping pull, will sync current state to Gitea")
                    return True
                else:
                    if fetch_result.stdout.strip():
                        self.safe_print(f"📥 Fetch output: {fetch_result.stdout.strip()}")
                    else:
                        self.safe_print(f"✅ Fetch completed (no new changes)")
                    if fetch_result.stderr.strip():
                        self.safe_print(f"ℹ️  Fetch stderr: {fetch_result.stderr.strip()}")

                # Get all local branches
                all_local_branches = self.get_all_local_branches(repo_path)

                if not all_local_branches:
                    self.safe_print(f"ℹ️  No local branches found in {repo_name}")
                    return True

                self.safe_print(f"📥 Updating {len(all_local_branches)} local branches in {repo_name}...")

                updated_branches = []
                failed_branches = []

                # Checkout each branch and pull
                for local_branch in all_local_branches:
                    try:
                        # Checkout the branch (no -f needed since we stashed)
                        checkout_result = subprocess.run(
                            ["git", "checkout", local_branch],
                            cwd=repo_path,
                            capture_output=True,
                            text=True
                        )

                        if checkout_result.returncode != 0:
                            failed_branches.append(f"{local_branch} (checkout failed)")
                            continue

                        # Try to pull
                        self.safe_print(f"🔄 Pulling {local_branch}...")
                        pull_result = subprocess.run(
                            ["git", "pull"],
                            cwd=repo_path,
                            capture_output=True,
                            text=True
                        )

                        if pull_result.returncode == 0:
                            if "Already up to date" in pull_result.stdout:
                                self.safe_print(f"✅ {local_branch}: already up to date")
                                updated_branches.append(f"{local_branch} (up-to-date)")
                            else:
                                self.safe_print(f"✅ {local_branch}: {pull_result.stdout.strip()}")
                                updated_branches.append(f"{local_branch} (updated)")
                        else:
                            # Pull failed, might be no upstream or conflict
                            if "no tracking information" in pull_result.stderr.lower():
                                self.safe_print(f"ℹ️  {local_branch}: no upstream configured")
                                updated_branches.append(f"{local_branch} (no upstream)")
                            else:
                                self.safe_print(f"⚠️  {local_branch}: pull failed - {pull_result.stderr.strip()}")
                                failed_branches.append(f"{local_branch} (pull failed)")

                    except subprocess.CalledProcessError:
                        failed_branches.append(local_branch)

                # Restore original branch
                if current_branch and current_branch != "HEAD":
                    try:
                        subprocess.run(
                            ["git", "checkout", current_branch],
                            cwd=repo_path,
                            capture_output=True,
                            text=True,
                            check=True
                        )
                    except subprocess.CalledProcessError:
                        self.safe_print(f"⚠️  Failed to restore branch {current_branch} in {repo_name}")

                # Report results
                if updated_branches:
                    self.safe_print(f"✅ Updated branches in {repo_name}: {', '.join(updated_branches)}")
                if failed_branches:
                    self.safe_print(f"⚠️  Failed to update branches in {repo_name}: {', '.join(failed_branches)}")

                return True

            finally:
                # Always restore stashed changes
                if stash_message:
                    self.restore_changes(repo_path, stash_message)

        except subprocess.CalledProcessError as e:
            self.safe_print(f"⚠️  Failed to pull latest changes for {repo_name}: {e}")
            # Don't fail the whole sync process, just warn
            return True

    def add_remote_and_push(self, repo_path, remote_url):
        """Adds a new remote to the Git repository and pushes changes."""
        try:
            repo_name = os.path.basename(repo_path)

            # Pull latest changes from original remote first
            self.pull_latest_changes(repo_path)

            # Check if remote 'gitea' exists
            result = subprocess.run(
                ["git", "remote"],
                cwd=repo_path,
                capture_output=True,
                text=True
            )

            if "gitea" in result.stdout:
                # Update existing remote
                subprocess.run(
                    ["git", "remote", "set-url", "gitea", remote_url],
                    cwd=repo_path,
                    check=True
                )
            else:
                # Add new remote
                subprocess.run(
                    ["git", "remote", "add", "gitea", remote_url],
                    cwd=repo_path,
                    check=True
                )

            self.safe_print(f"📤 Pushing {repo_name} to Gitea...")

            # Push all branches to the new remote
            subprocess.run(
                ["git", "push", "gitea", "--all"],
                cwd=repo_path,
                check=True
            )

            # Push all tags
            subprocess.run(
                ["git", "push", "gitea", "--tags"],
                cwd=repo_path,
                check=True
            )

            # Remove remote if requested
            if self.remove_remote:
                subprocess.run(
                    ["git", "remote", "remove", "gitea"],
                    cwd=repo_path,
                    check=True
                )

            return True
        except subprocess.CalledProcessError as e:
            print(f"Error executing Git command: {e}")
            return False

    def is_git_repo(self, path):
        """Check if the given path is a git repository root."""
        return os.path.isdir(os.path.join(path, '.git'))

    def list_and_select_repos(self):
        """Lists all found repositories and asks the user to select which ones to process."""
        # Check if we're inside a git repository
        current_is_git = self.is_git_repo(self.projects_dir)

        if current_is_git:
            current_repo_name = os.path.basename(os.path.abspath(self.projects_dir))
            print(f"📁 Current directory is a git repository: {current_repo_name}")

            if self.auto_yes:
                print("Sync this repository? (Y/n/scan): y [auto-yes]")
                return [self.projects_dir]

            # Ask if user wants to sync just this repo
            choice = input("Sync this repository? (Y/n/scan): ").strip().lower()
            if choice in ['', 'y', 'yes']:
                return [self.projects_dir]
            elif choice in ['n', 'no']:
                return []
            # If 'scan', continue with normal scanning

        # Find all Git repositories
        print(f"Scanning for Git repositories in {self.projects_dir}...")
        all_repos = self.find_git_repos()

        if not all_repos:
            print("No Git repositories found.")
            return []

        print(f"Found {len(all_repos)} Git repositories:")

        # Display repositories with numbers, highlight current repo if it's in the list
        current_repo_index = None
        for i, repo_path in enumerate(all_repos, 1):
            repo_name = os.path.basename(repo_path)
            if repo_path == os.path.abspath(self.projects_dir):
                print(f"{i}. {repo_name} ({repo_path}) ⭐ [CURRENT]")
                current_repo_index = i
            else:
                print(f"{i}. {repo_name} ({repo_path})")

        print("\nOptions:")
        print("- Enter numbers to select specific repositories (e.g., '1,3,5')")
        print("- Enter 'all' to select all repositories")
        print("- Enter 'none' to cancel")
        print("- Enter 'exclude:1,2,3' to select all except those specified")
        if current_repo_index:
            print(f"- Press Enter to select current repository only (#{current_repo_index})")

        # Auto-yes mode handling
        if self.auto_yes:
            if current_repo_index:
                print(f"\nSelect repositories to process [default: {current_repo_index}]: {current_repo_index} [auto-yes]")
                return [all_repos[current_repo_index - 1]]
            else:
                print("\nSelect repositories to process: all [auto-yes]")
                return all_repos

        while True:
            prompt = "\nSelect repositories to process: "
            if current_repo_index:
                prompt = f"\nSelect repositories to process [default: {current_repo_index}]: "

            selection = input(prompt).strip().lower()

            # If empty and we have a current repo, select it
            if not selection and current_repo_index:
                return [all_repos[current_repo_index - 1]]

            if selection == 'all':
                return all_repos

            if selection == 'none':
                return []

            if selection.startswith('exclude:'):
                try:
                    exclude_nums = [int(x.strip()) for x in selection[8:].split(',') if x.strip()]
                    excluded_indices = [x-1 for x in exclude_nums if 1 <= x <= len(all_repos)]
                    return [repo for i, repo in enumerate(all_repos) if i not in excluded_indices]
                except ValueError:
                    print("Invalid format for exclusion. Please try again.")
                    continue

            try:
                # Parse comma-separated numbers
                selected_nums = [int(x.strip()) for x in selection.split(',') if x.strip()]
                # Validate selection
                selected_indices = [x-1 for x in selected_nums if 1 <= x <= len(all_repos)]

                if not selected_indices and selection:
                    print("No valid selections. Please try again.")
                    continue

                return [all_repos[i] for i in selected_indices]
            except ValueError:
                print("Invalid input. Please enter numbers separated by commas.")

    def repository_exists(self, repo_name):
        """Check if a repository already exists in Gitea."""
        url = f"{self.gitea_url}/api/v1/repos/{self.username}/{repo_name}"

        headers = {
            "Authorization": f"token {self.token}"
        }

        request = urllib.request.Request(
            url,
            headers=headers,
            method="GET"
        )

        try:
            with urllib.request.urlopen(request) as response:
                return True
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return False
            else:
                print(f"Error checking if repository exists: {e.read().decode('utf-8')}")
                return False

    def safe_print(self, message):
        """Thread-safe printing"""
        with self.print_lock:
            print(message)

    def process_repository(self, repo_path):
        """Process a single repository (for concurrent execution)"""
        repo_name = os.path.basename(repo_path)
        self.safe_print(f"\nProcessing repository: {repo_name}")

        try:

            if self.repository_exists(repo_name):
                self.safe_print(f"Repository {repo_name} already exists in Gitea, skipping creation...")
                remote_url = f"{self.gitea_url}/{self.username}/{repo_name}.git"
                self.safe_print(f"Adding remote and pushing to {remote_url}...")
                if self.add_remote_and_push(repo_path, remote_url):
                    self.safe_print(f"✓ Successfully pushed {repo_name} to Gitea.")
                    return True
                else:
                    self.safe_print(f"✗ Failed to push {repo_name} to Gitea.")
                    return False

            # Create repository in Gitea
            self.safe_print(f"Creating Gitea repository for {repo_name}...")
            result = self.create_gitea_repo(repo_name)
            if result:
                self.disable_actions_for_repo(repo_name)

                # Add remote and push to Gitea
                remote_url = f"{self.gitea_url}/{self.username}/{repo_name}.git"
                self.safe_print(f"Adding remote and pushing to {remote_url}...")
                if self.add_remote_and_push(repo_path, remote_url):
                    self.safe_print(f"✓ Successfully pushed {repo_name} to Gitea.")
                    return True
                else:
                    self.safe_print(f"✗ Failed to push {repo_name} to Gitea.")
                    return False
            else:
                self.safe_print(f"✗ Skipping {repo_name} due to repository creation error.")
                return False
        except Exception as e:
            self.safe_print(f"✗ Error processing {repo_name}: {e}")
            return False

    def run(self):
        """Main execution method that processes selected repositories with concurrency"""
        # List and select repositories
        selected_repos = self.list_and_select_repos()

        if not selected_repos:
            print("No repositories selected for processing.")
            return

        print(f"\nProcessing {len(selected_repos)} selected repositories...")

        # Process repositories concurrently (limit to 3 to avoid overwhelming the server)
        max_workers = min(3, len(selected_repos))
        successful = 0
        failed = 0

        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Submit all tasks
            future_to_repo = {
                executor.submit(self.process_repository, repo_path): repo_path
                for repo_path in selected_repos
            }

            # Process completed tasks
            for future in as_completed(future_to_repo):
                repo_path = future_to_repo[future]
                try:
                    success = future.result()
                    if success:
                        successful += 1
                    else:
                        failed += 1
                except Exception as e:
                    repo_name = os.path.basename(repo_path)
                    self.safe_print(f"✗ Exception processing {repo_name}: {e}")
                    failed += 1

        print(f"\n🏁 Summary: {successful} successful, {failed} failed out of {len(selected_repos)} repositories")


def parse_arguments():
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description="Sync local Git repositories to Gitea")

    parser.add_argument(
        "--projects-dir",
        type=str,
        default="./Projects",
        help="Path to the directory containing Git repositories (default: ./Projects)"
    )

    parser.add_argument(
        "--gitea-url",
        type=str,
        required=True,
        help="Gitea server URL (e.g., http://localhost:3000)"
    )

    parser.add_argument(
        "--username",
        type=str,
        required=True,
        help="Gitea username"
    )

    parser.add_argument(
        "--token",
        type=str,
        required=True,
        help="Gitea API token"
    )

    parser.add_argument(
        "--remove-remote",
        action="store_true",
        help="Remove the gitea remote after pushing"
    )

    parser.add_argument(
        "-y", "--yes",
        action="store_true",
        help="Automatically answer yes to all prompts"
    )

    return parser.parse_args()


def main():
    # Parse arguments
    args = parse_arguments()

    # Create and run GiteaSync instance
    syncer = GiteaSync(
        projects_dir=args.projects_dir,
        gitea_url=args.gitea_url,
        username=args.username,
        token=args.token,
        remove_remote=args.remove_remote,
        auto_yes=args.yes
    )

    syncer.run()

if __name__ == "__main__":
    main()
