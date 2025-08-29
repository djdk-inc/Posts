#!/bin/bash
# TODO: IF AI IS ENABLED ONCE, DONT ASK FOR IT AGAIN
# TODO: smart git add, commit, push cycle is broken
# TODO: DONT USE TMP FILES
# TODO: If script fails, abort the entire workflow with an error code and message

# Smart Git Workflow - Auto-add, AI-powered commit messages, and push
echo "🚀 Smart Git Workflow"
echo "====================="

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: Not in a git repository"
    echo "💡 Please run this script from within a git repository"
    exit 1
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
git add -A

# Get context for commit message
CHANGED_FILES=$(git diff --cached --name-only | tr '\n' ' ')
DIFF_OUTPUT=$(git diff --cached)
RECENT_COMMITS=$(git log --oneline -3)


# Check if we can use Cursor's AI
USE_AI=false
if command -v cursor &> /dev/null; then
    read -p "🤖 Use Cursor's Claude AI to generate commit message? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        USE_AI=true
    fi
fi

# Generate commit message
if [[ "$USE_AI" == true ]]; then
    echo "🤖 Analyzing changes with Claude AI..."
    
    # Prepare Claude prompt
    CLAUDE_PROMPT="You are a senior software engineer writing commit messages. Analyze these git changes and write a clear, concise commit message.

CONTEXT:
- Recent commits: $RECENT_COMMITS

CHANGES:
Files modified: $CHANGED_FILES

Git diff:
$DIFF_OUTPUT

INSTRUCTIONS:
1. Write a commit message that's descriptive but concise (under 72 characters)
2. Use conventional commit format: <type>(<scope>): <description>
3. Focus on WHAT was changed and WHY (if clear from context)
4. Use present tense (\"Add feature\" not \"Added feature\")
5. Analyze the actual code changes, not just file names

Commit message:"

    # Use Cursor's AI chat with the prompt
    echo "🤖 Using Cursor's AI chat..."
    
    # Ensure we're in the git repository
    cd "$(git rev-parse --show-toplevel)"
    
    # Send prompt to Gemini
    COMMIT_MSG=$(echo "$CLAUDE_PROMPT" | gemini)
    echo "COMMIT_MSG: $COMMIT_MSG"N
    
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

# Create temporary file for commit message
echo "$COMMIT_MSG" > /tmp/smart_commit_msg.txt

# Ask user if they want to edit or use as-is
read -p "📝 Edit commit message? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Open editor for user to review/edit commit message
    if command -v vim &> /dev/null; then
        vim /tmp/smart_commit_msg.txt
    elif command -v code &> /dev/null; then
        code --wait /tmp/smart_commit_msg.txt
    else
        echo "Please edit the commit message in /tmp/smart_commit_msg.txt"
        read -p "Press Enter when done..."
    fi
    # Read the final commit message
    FINAL_MSG=$(cat /tmp/smart_commit_msg.txt)
else
    # Use the generated message as-is
    FINAL_MSG="$COMMIT_MSG"
    echo "✅ Using generated commit message: $FINAL_MSG"
fi


# Commit with the message
echo "💾 Committing changes..."
git commit -m "$FINAL_MSG"

# Ask user if they want to push
read -p "🚀 Push to remote? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📤 Pushing to remote..."
    git push
    echo "✅ Done!"
else
    echo "⏸️  Skipped push. You can push manually later with 'git push'"
fi