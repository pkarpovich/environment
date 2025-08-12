---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git push:*), Grep, Read, Write
argument-hint: [optional commit message hints]
description: Generate a git commit message based on changes and history, then ask about push
---

## Generate Git Commit Message

I'll analyze your current changes and git history to generate an appropriate commit message.

### Step 1: Analyze current changes
First, let me check the current git status and changes:

!git status --porcelain

### Step 2: Review detailed changes
Now let me examine the actual changes:

!git diff --cached
!git diff

### Step 3: Review recent commit history
Let me check recent commits to understand the commit message style:

!git log --oneline -10

### Step 4: Generate commit message
Based on the changes and commit history style, I'll now generate an appropriate commit message that:
- Follows the repository's commit message conventions
- Accurately describes the changes
- Uses appropriate commit type (feat, fix, refactor, docs, test, etc.)
- Is concise yet informative

$ARGUMENTS

### Step 5: Create the commit
After analyzing all the changes and history, I'll create a commit with the generated message.

### Step 6: Ask about push
Once the commit is created, I'll ask if you'd like to push the changes to the remote repository.

Note: I will NOT automatically push changes. I'll always ask for your confirmation before pushing to remote.