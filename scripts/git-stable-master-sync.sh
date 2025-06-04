#!/bin/bash

# Function to display usage
function display_usage {
    echo "Usage: $0 <source-branch> <target-branch> [base-source-branch] [base-target-branch]"
    echo "Example: $0 PBI-110614-s PBI-110614-m release/stable master"
    echo "If base branches are not provided, defaults (release/stable and master) will be used"
    exit 1
}

# Check if at least the two branch names are provided
if [ $# -lt 2 ]; then
    display_usage
fi

SOURCE_BRANCH=$1
TARGET_BRANCH=$2
BASE_SOURCE_BRANCH=${3:-"release/stable"}  # Default to release/stable if not provided
BASE_TARGET_BRANCH=${4:-"master"}          # Default to master if not provided

echo "Starting branch automation..."
echo "Source branch: ${SOURCE_BRANCH}"
echo "Target branch: ${TARGET_BRANCH}"
echo "Base source branch: ${BASE_SOURCE_BRANCH}"
echo "Base target branch: ${BASE_TARGET_BRANCH}"

# Make sure we have the latest code
echo "Fetching latest changes..."
git fetch --all

# Function to check if a branch exists (locally or remotely)
function branch_exists {
    local branch_name=$1

    # Check if branch exists locally
    if git show-ref --verify --quiet refs/heads/${branch_name}; then
        return 0  # Branch exists locally
    fi

    # Check if branch exists remotely
    if git show-ref --verify --quiet refs/remotes/origin/${branch_name}; then
        return 0  # Branch exists remotely
    fi

    return 1  # Branch does not exist
}

# Function to handle cherry-pick conflicts
function handle_cherry_pick_conflict {
    local commit=$1
    local commit_msg=$2

    echo "Cherry-pick conflict for commit ${commit} (${commit_msg})"
    echo "Please resolve the conflicts, then press:"
    echo "  [c] to continue cherry-picking after you've resolved conflicts"
    echo "  [s] to skip this commit"
    echo "  [a] to abort the entire cherry-pick process"

    while true; do
        read -p "Choose an option [c/s/a]: " conflict_choice

        case $conflict_choice in
            [Cc]* )
                # User has resolved conflicts and wants to continue
                git add .
                git cherry-pick --continue
                if [ $? -eq 0 ]; then
                    echo "Conflict resolved, continuing cherry-pick."
                    return 0
                else
                    echo "Cherry-pick failed to continue. Please check your conflict resolution."
                    # Ask again
                    continue
                fi
                ;;
            [Ss]* )
                # Skip this commit
                git cherry-pick --abort
                echo "Skipped commit ${commit}"
                return 1
                ;;
            [Aa]* )
                # Abort entire process
                git cherry-pick --abort
                echo "Cherry-pick process aborted by user."
                exit 1
                ;;
            * )
                echo "Please answer c (continue), s (skip), or a (abort)."
                ;;
        esac
    done
}

# Step 1: Handle source branch creation
if branch_exists ${SOURCE_BRANCH}; then
    echo "Branch ${SOURCE_BRANCH} already exists."
    read -p "Do you want to use the existing branch? (y/n): " use_existing_source

    if [[ $use_existing_source != "y" && $use_existing_source != "Y" ]]; then
        echo "Aborting operation."
        exit 1
    fi

    echo "Using existing branch ${SOURCE_BRANCH}..."
    git checkout ${SOURCE_BRANCH}
    git pull origin ${SOURCE_BRANCH}
else
    echo "Creating ${SOURCE_BRANCH} from ${BASE_SOURCE_BRANCH}..."
    git checkout ${BASE_SOURCE_BRANCH}
    git pull origin ${BASE_SOURCE_BRANCH}
    git checkout -b ${SOURCE_BRANCH}
    git push -u origin ${SOURCE_BRANCH}
fi

# Step 2: Handle target branch creation
if branch_exists ${TARGET_BRANCH}; then
    echo "Branch ${TARGET_BRANCH} already exists."
    read -p "Do you want to use the existing branch? (y/n): " use_existing_target

    if [[ $use_existing_target != "y" && $use_existing_target != "Y" ]]; then
        echo "Aborting operation."
        exit 1
    fi

    read -p "Do you want to reset ${TARGET_BRANCH} to match ${BASE_TARGET_BRANCH} before cherry-picking? (y/n): " reset_target

    if [[ $reset_target == "y" || $reset_target == "Y" ]]; then
        echo "Resetting ${TARGET_BRANCH} to match ${BASE_TARGET_BRANCH}..."
        git checkout ${TARGET_BRANCH}
        git reset --hard origin/${BASE_TARGET_BRANCH}
        git push --force origin ${TARGET_BRANCH}
    else
        echo "Using existing branch ${TARGET_BRANCH} as is..."
        git checkout ${TARGET_BRANCH}
        git pull origin ${TARGET_BRANCH}
    fi
else
    echo "Creating ${TARGET_BRANCH} from ${BASE_TARGET_BRANCH}..."
    git checkout ${BASE_TARGET_BRANCH}
    git pull origin ${BASE_TARGET_BRANCH}
    git checkout -b ${TARGET_BRANCH}
    git push -u origin ${TARGET_BRANCH}
fi

# Step 3: Get commit hashes from source branch to cherry-pick, excluding merge commits
echo "Getting commits from ${SOURCE_BRANCH} (excluding merge commits)..."
git checkout ${SOURCE_BRANCH}

# Determine the base for comparing commits
if branch_exists ${BASE_SOURCE_BRANCH}; then
    # Using --no-merges to exclude merge commits
    COMMIT_HASHES=$(git log --no-merges --format=%H ${BASE_SOURCE_BRANCH}..${SOURCE_BRANCH})
else
    # If base branch doesn't exist or isn't accessible, find the common ancestor
    echo "Base branch not found. Using merge-base to determine common ancestor..."
    COMMON_ANCESTOR=$(git merge-base ${SOURCE_BRANCH} ${TARGET_BRANCH})
    COMMIT_HASHES=$(git log --no-merges --format=%H ${COMMON_ANCESTOR}..${SOURCE_BRANCH})
fi

# Step 4: Check which commits need to be cherry-picked (skip already cherry-picked commits)
echo "Checking which commits need to be cherry-picked to ${TARGET_BRANCH}..."
git checkout ${TARGET_BRANCH}

COMMITS_TO_CHERRY_PICK=()

if [ -z "$COMMIT_HASHES" ]; then
    echo "No commits found on ${SOURCE_BRANCH} to cherry-pick"
else
    # Cherry-pick in reverse order (oldest first)
    COMMIT_ARRAY=($(echo "$COMMIT_HASHES" | tac))

    for COMMIT in "${COMMIT_ARRAY[@]}"; do
        # Get the commit message and hash to check if it's already in the target branch
        COMMIT_MSG=$(git log -1 --format=%s ${COMMIT})
        COMMIT_PATCH=$(git show ${COMMIT})

        # Check if this commit is already in the target branch
        # We use git log with --grep to search for the commit message
        # and then use diff to compare the actual changes
        ALREADY_PICKED=false

        # First check: Look for commits with the same message
        MATCHING_COMMITS=$(git log --grep="$COMMIT_MSG" --format=%H ${TARGET_BRANCH})

        if [ ! -z "$MATCHING_COMMITS" ]; then
            # Second check: For each potential match, compare the actual changes
            for POTENTIAL_MATCH in $MATCHING_COMMITS; do
                POTENTIAL_PATCH=$(git show ${POTENTIAL_MATCH})

                # Compare patches, ignoring date, commit hash and other metadata
                # Extract just the actual code changes for comparison
                COMMIT_DIFF=$(echo "$COMMIT_PATCH" | grep -A 1000000 "^diff --git" | grep -v "^index" | grep -v "^---" | grep -v "^+++" | grep -E "^(\+|-)[^+-]")
                POTENTIAL_DIFF=$(echo "$POTENTIAL_PATCH" | grep -A 1000000 "^diff --git" | grep -v "^index" | grep -v "^---" | grep -v "^+++" | grep -E "^(\+|-)[^+-]")

                if [ "$COMMIT_DIFF" = "$POTENTIAL_DIFF" ]; then
                    echo "Commit ${COMMIT} (${COMMIT_MSG}) already cherry-picked to ${TARGET_BRANCH}"
                    ALREADY_PICKED=true
                    break
                fi
            done
        fi

        if [ "$ALREADY_PICKED" = false ]; then
            COMMITS_TO_CHERRY_PICK+=($COMMIT)
        fi
    done
fi

# Step 5: Cherry-pick the needed commits to target branch
echo "Cherry-picking commits to ${TARGET_BRANCH}..."

if [ ${#COMMITS_TO_CHERRY_PICK[@]} -eq 0 ]; then
    echo "No new commits to cherry-pick"
else
    echo "Found ${#COMMITS_TO_CHERRY_PICK[@]} commits to cherry-pick"

    # Track how many commits were successfully cherry-picked
    SUCCESSFUL_CHERRY_PICKS=0
    SKIPPED_COMMITS=0

    for COMMIT in "${COMMITS_TO_CHERRY_PICK[@]}"; do
        COMMIT_MSG=$(git log -1 --format=%s ${COMMIT})
        echo "Cherry-picking commit ${COMMIT} (${COMMIT_MSG})..."
        git cherry-pick ${COMMIT}

        # Check if cherry-pick was successful
        if [ $? -ne 0 ]; then
            # Handle the conflict
            handle_cherry_pick_conflict ${COMMIT} "${COMMIT_MSG}"

            # Check the return value of the conflict handler
            if [ $? -eq 0 ]; then
                SUCCESSFUL_CHERRY_PICKS=$((SUCCESSFUL_CHERRY_PICKS+1))
            else
                SKIPPED_COMMITS=$((SKIPPED_COMMITS+1))
            fi
        else
            SUCCESSFUL_CHERRY_PICKS=$((SUCCESSFUL_CHERRY_PICKS+1))
        fi
    done

    # Push the changes to target branch
    if [ $SUCCESSFUL_CHERRY_PICKS -gt 0 ]; then
        echo "Pushing changes to origin/${TARGET_BRANCH}..."
        git push origin ${TARGET_BRANCH}
    fi
fi

echo "Branch automation completed successfully!"
if branch_exists ${SOURCE_BRANCH} && [[ $use_existing_source == "y" || $use_existing_source == "Y" ]]; then
    echo "Used existing ${SOURCE_BRANCH}"
else
    echo "Created ${SOURCE_BRANCH} from ${BASE_SOURCE_BRANCH}"
fi

if branch_exists ${TARGET_BRANCH} && [[ $use_existing_target == "y" || $use_existing_target == "Y" ]]; then
    echo "Used existing ${TARGET_BRANCH}"
else
    echo "Created ${TARGET_BRANCH} from ${BASE_TARGET_BRANCH}"
fi

if [ ${#COMMITS_TO_CHERRY_PICK[@]} -eq 0 ]; then
    echo "No new commits needed to be cherry-picked"
else
    echo "Cherry-pick summary:"
    echo "  - Found ${#COMMITS_TO_CHERRY_PICK[@]} new commits to cherry-pick"
    echo "  - Successfully cherry-picked: $SUCCESSFUL_CHERRY_PICKS"

    if [ $SKIPPED_COMMITS -gt 0 ]; then
        echo "  - Skipped due to conflicts: $SKIPPED_COMMITS"
    fi
fi