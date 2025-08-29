#!/bin/bash

 # Smart Git Workflow - Auto-add, AI-powered commit messages, and push
# Exit on any error
set -e

# Check for debug flag
ECHO_PROMPT=false
if [[ "$1" == "--echo-prompt" ]]; then
    ECHO_PROMPT=true
fi

# Function to handle errors
error_exit() {
    echo "❌ Error: $1" >&2
    echo "💡 Workflow aborted" >&2
    exit 1
}

echo "🚀 Smart Git Workflow"
echo "====================="

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    error_exit "Not in a git repository. Please run this script from within a git repository."
fi

# Check if there are changes
if [[ -z $(git status --porcelain) ]]; then
    echo "✅ No changes to commit"
    exit 0
fi

# Show what files have changed
echo "📝 Changed files:"
git status --short

# Auto-add all changes
echo "➕ Adding all changes..."
git add -A || error_exit "Failed to add changes to git staging area."

# Get context for commit message
CHANGED_FILES=$(git diff --cached --name-only | tr '\n' ' ')
DIFF_OUTPUT=$(git diff --cached)
RECENT_COMMITS=$(git log --oneline -3)


# Check if we can use Gemini AI
USE_AI=false
if command -v gemini &> /dev/null; then
    # Check if AI preference is already set
    if [[ -f ".git/smart-git-ai-enabled" ]]; then
        export USE_AI=true
        echo "🤖 Using Gemini AI (previously enabled)"
    else
        read -p "🤖 Use Gemini AI to generate commit message? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            export USE_AI=true
            # Remember the preference
            touch .git/smart-git-ai-enabled
            echo "✅ AI enabled for future commits"
        fi
    fi
fi

# Generate commit message
if [[ "$USE_AI" == true ]]; then
    echo "🤖 Analyzing changes with Gemini AI..."
    
    # Prepare Gemini prompt
    GEMINI_PROMPT="You are a senior software engineer writing commit messages. Analyze these git changes and write a clear, concise commit message.

CONTEXT:
- Recent commits: $RECENT_COMMITS

CHANGES:
Files modified: $CHANGED_FILES

Git diff:
$DIFF_OUTPUT

INSTRUCTIONS:
1. Write a commit message that's descriptive and concise 
2. Use conventional commit format: <type>(<scope>): <description>
3. Focus on WHAT was changed and WHY (if clear from context)
4. Use present tense (\"Add feature\" not \"Added feature\")
5. Analyze the actual code changes, not just file names
6. Note any file addition / deletions with this format: (add/delete):filename - one per line

Commit message:"

    # Use Gemini AI with the prompt
    echo "🤖 Using Gemini AI..."
    
    # Ensure we're in the git repository
    cd "$(git rev-parse --show-toplevel)"
    
    # Send prompt to Gemini with better error handling
    echo "🤖 Sending prompt to Gemini..."
    
    # Echo prompt if debug flag is set
    if [[ "$ECHO_PROMPT" == true ]]; then
        echo "🔍 DEBUG: Gemini Prompt:"
        echo "$GEMINI_PROMPT"
        echo "🔍 END PROMPT"
    fi
    
    COMMIT_MSG=$(echo "$GEMINI_PROMPT" | gemini 2>&1)
    GEMINI_EXIT_CODE=$?
    
    if [[ $GEMINI_EXIT_CODE -eq 124 ]]; then
        echo "⚠️  Gemini timed out after 15 seconds"
        echo "⚠️  Using fallback commit message."
        COMMIT_MSG="Update: $CHANGED_FILES"
    elif [[ $GEMINI_EXIT_CODE -ne 0 ]]; then
        echo "⚠️  Gemini failed with exit code: $GEMINI_EXIT_CODE"
        echo "⚠️  Gemini output: $COMMIT_MSG"
        echo "⚠️  Using fallback commit message."
        COMMIT_MSG="Update: $CHANGED_FILES"
    else
        echo "✅ Gemini response: $COMMIT_MSG"
    fi
    
    # Fallback if no message provided
    if [[ -z "$COMMIT_MSG" ]]; then
        echo "⚠️  AI chat failed. Using fallback commit message."
        COMMIT_MSG="Update: $CHANGED_FILES"
    fi
else
    # Simple fallback when AI is not used
    echo "🤖 Using simple commit message generation..."
    COMMIT_MSG="Update: $CHANGED_FILES"
fi

echo "📝 Generated commit message:"
echo "   $COMMIT_MSG"
echo ""
echo "💡 You can edit this message before committing"
echo "💡 Or press Enter to use the generated message as-is"

# Ask user if they want to edit or use as-is
read -p "📝 Edit commit message? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Ask user to input the edited message
    echo "📝 Please enter your edited commit message:"
    read -r FINAL_MSG
    if [[ -z "$FINAL_MSG" ]]; then
        FINAL_MSG="$COMMIT_MSG"
        echo "✅ Using original commit message: $FINAL_MSG"
    else
        echo "✅ Using edited commit message: $FINAL_MSG"
    fi
else
    # Use the generated message as-is
    FINAL_MSG="$COMMIT_MSG"
    echo "✅ Using generated commit message: $FINAL_MSG"
fi


# Commit with the message
echo "💾 Committing changes..."
git commit -m "$FINAL_MSG" || error_exit "Failed to commit changes."

# Ask user if they want to push
read -p "🚀 Push to remote? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📤 Pushing to remote..."
    git push || error_exit "Failed to push changes to remote repository."
    echo "✅ Done!"
else
    echo "⏸️  Skipped push. You can push manually later with 'git push'"
fi