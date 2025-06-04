#!/bin/bash
# bulk_gitea_sync.sh - Bulk sync multiple projects to Gitea from a predefined list

# Configuration
SYNC_SCRIPT="$HOME/Projects/environment/scripts/sync_to_gitea.py"

# Set text colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display error and exit
error_exit() {
    echo -e "${RED}ERROR: $1${NC}"
    exit 1
}

# Function to display info
info() {
    echo -e "${BLUE}INFO: $1${NC}"
}

# Function to display success
success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

# Function to display warning
warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

# Check for Python 3
if ! command -v python3 &> /dev/null; then
    error_exit "Python 3 is required but not found."
fi

# Check if the sync script exists
if [ ! -f "$SYNC_SCRIPT" ]; then
    error_exit "Sync script not found: $SYNC_SCRIPT"
fi

# Check for required environment variables
if [ -z "$GITEA_TOKEN" ]; then
    error_exit "GITEA_TOKEN environment variable is not set."
fi

if [ -z "$GITEA_USERNAME" ]; then
    error_exit "GITEA_USERNAME environment variable is not set."
fi

if [ -z "$GITEA_URL" ]; then
    error_exit "GITEA_URL environment variable is not set."
fi

if [ -z "$GITEA_PROJECTS" ]; then
    error_exit "GITEA_PROJECTS environment variable is not set."
fi

# Parse projects from environment variable (colon-separated)
IFS=':' read -ra PROJECT_PATHS <<< "$GITEA_PROJECTS"
PROJECTS=()

for project_path in "${PROJECT_PATHS[@]}"; do
    # Skip empty entries
    if [[ -n "$project_path" ]]; then
        # Expand tilde to home directory
        expanded_path="${project_path/#\~/$HOME}"
        PROJECTS+=("$expanded_path")
    fi
done

# Check if we have any projects to sync
if [ ${#PROJECTS[@]} -eq 0 ]; then
    warning "No projects found in GITEA_PROJECTS environment variable"
    warning "Please set GITEA_PROJECTS with colon-separated project directories."
    warning "Example: export GITEA_PROJECTS=\"~/Projects/repo1:~/Projects/repo2:/path/to/repo3\""
    exit 0
fi

# Display projects to be synced
info "Found ${#PROJECTS[@]} project directories to sync:"
for i in "${!PROJECTS[@]}"; do
    echo "  $((i+1)). ${PROJECTS[$i]}"
done

echo
info "Starting bulk sync to Gitea..."
echo

# Track results
SUCCESSFUL_SYNCS=0
FAILED_SYNCS=0
FAILED_PROJECTS=()

# Sync each project
for project_dir in "${PROJECTS[@]}"; do
    echo -e "${BLUE}===========================================${NC}"
    info "Processing: $project_dir"
    echo -e "${BLUE}===========================================${NC}"
    
    # Check if directory exists
    if [ ! -d "$project_dir" ]; then
        warning "Directory does not exist: $project_dir"
        FAILED_SYNCS=$((FAILED_SYNCS+1))
        FAILED_PROJECTS+=("$project_dir (directory not found)")
        continue
    fi
    
    # Run the sync script with auto-yes flag
    python3 "$SYNC_SCRIPT" \
        --projects-dir "$project_dir" \
        --gitea-url "$GITEA_URL" \
        --username "$GITEA_USERNAME" \
        --token "$GITEA_TOKEN" \
        --remove-remote \
        --yes
    
    # Check if the sync was successful
    if [ $? -eq 0 ]; then
        success "Completed sync for: $project_dir"
        SUCCESSFUL_SYNCS=$((SUCCESSFUL_SYNCS+1))
    else
        warning "Failed to sync: $project_dir"
        FAILED_SYNCS=$((FAILED_SYNCS+1))
        FAILED_PROJECTS+=("$project_dir")
    fi
    
    echo
done

# Display summary
echo -e "${BLUE}===========================================${NC}"
info "Bulk sync completed!"
echo -e "${BLUE}===========================================${NC}"

echo "Summary:"
echo "  Total projects: ${#PROJECTS[@]}"
echo "  Successful syncs: $SUCCESSFUL_SYNCS"
echo "  Failed syncs: $FAILED_SYNCS"

if [ $FAILED_SYNCS -gt 0 ]; then
    echo
    warning "Failed projects:"
    for failed_project in "${FAILED_PROJECTS[@]}"; do
        echo "  - $failed_project"
    done
fi

echo
if [ $FAILED_SYNCS -eq 0 ]; then
    success "All projects synced successfully! 🎉"
    exit 0
else
    warning "Some projects failed to sync. Check the output above for details."
    exit 1
fi