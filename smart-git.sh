#!/bin/bash

# Smart Git Workflow - Auto-add, AI-powered commit messages, and push
echo "🚀 Smart Git Workflow"
echo "====================="

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
CURRENT_BRANCH=$(git branch --show-current)
RECENT_COMMITS=$(git log --oneline -3)

# Check if we can use Cursor's AI
USE_AI=false
if command -v code &> /dev/null; then
    read -p "🤖 Use Cursor's Claude AI to generate commit message? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        USE_AI=true
        AI_TOOL="cursor"
    fi
fi

# Generate commit message
if [[ "$USE_AI" == true ]]; then
    echo "🤖 Analyzing changes with Claude AI..."
    
    # Get branch context
    BRANCH_CONTEXT=""
    if [[ $CURRENT_BRANCH =~ (feature|fix|bug|hotfix|chore)/([A-Z]+-[0-9]+) ]]; then
        TICKET_ID="${BASH_REMATCH[2]}"
        BRANCH_CONTEXT="Branch: $CURRENT_BRANCH (Ticket: $TICKET_ID)"
    elif [[ $CURRENT_BRANCH =~ (feature|fix|bug|hotfix|chore)/(.+) ]]; then
        BRANCH_CONTEXT="Branch: $CURRENT_BRANCH"
    fi
    
    # Get codebase context
    CODEBASE_CONTEXT=""
    if [[ -f "README.md" ]]; then
        README_SUMMARY=$(head -20 README.md | grep -v "^#" | head -3)
        CODEBASE_CONTEXT="README context: $README_SUMMARY"
    fi
    
    # Prepare Claude prompt
    CLAUDE_PROMPT=$(cat <<EOF
You are a senior software engineer writing commit messages. Analyze these git changes and write a clear, concise commit message.

CONTEXT:
- $BRANCH_CONTEXT
- Recent commits: $RECENT_COMMITS
- $CODEBASE_CONTEXT

CHANGES:
Files modified: $CHANGED_FILES

Git diff:
$DIFF_OUTPUT

INSTRUCTIONS:
1. Write a commit message that's descriptive but concise (under 72 characters)
2. Use conventional commit format: <type>(<scope>): <description>
3. If there's a ticket number, include it: <type>(<scope>): <description> [TICKET-123]
4. Focus on WHAT was changed and WHY (if clear from context)
5. Use present tense ("Add feature" not "Added feature")

Examples:
- feat(auth): add OAuth2 login support [AUTH-456]
- fix(api): resolve user data validation error
- docs(readme): update installation instructions
- refactor(utils): extract common validation logic

Commit message:
EOF
)

    # Use Cursor's AI to generate commit message
    echo "🤖 Using Cursor's Claude AI..."
    
    # Create a temporary file with the prompt for Cursor
    echo "$CLAUDE_PROMPT" > /tmp/cursor_ai_prompt.txt
    
    # Open the prompt in Cursor and ask user to get AI response
    echo "📝 Opening Cursor with AI prompt..."
    echo "💡 Please use Cmd+K and ask Claude to generate a commit message based on the prompt."
    echo "💡 Copy the generated message and paste it when prompted."
    
    code /tmp/cursor_ai_prompt.txt
    
    # Wait for user to get AI response
    read -p "🤖 Press Enter after you've generated the commit message with Cursor's AI..."
    
    # Ask user to paste the AI-generated message
    echo "📝 Please paste the AI-generated commit message:"
    read -r COMMIT_MSG
    
    # Clean up the response
    COMMIT_MSG=$(echo "$COMMIT_MSG" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Fallback if no message provided
    if [[ -z "$COMMIT_MSG" ]]; then
        echo "⚠️  No AI message provided. Using fallback commit message."
        COMMIT_MSG="Update: $CHANGED_FILES"
    fi
    
    # Clean up
    rm -f /tmp/cursor_ai_prompt.txt
else
    # Simple commit message generation
    if [[ $CHANGED_FILES == *"PLATFORM SLOs"* ]]; then
        COMMIT_MSG="Update PLATFORM SLOs document"
    elif [[ $CHANGED_FILES == *".md"* ]]; then
        COMMIT_MSG="Update documentation"
    elif [[ $CHANGED_FILES == *".js"* ]] || [[ $CHANGED_FILES == *".ts"* ]]; then
        COMMIT_MSG="Update JavaScript/TypeScript code"
    elif [[ $CHANGED_FILES == *".py"* ]]; then
        COMMIT_MSG="Update Python code"
    else
        COMMIT_MSG="Update: $CHANGED_FILES"
    fi
fi

echo "📝 Generated commit message:"
echo "   $COMMIT_MSG"
echo ""
echo "💡 You can edit this message before committing"
echo "💡 Or press Enter to use the generated message as-is"

# Create temporary file for commit message
echo "$COMMIT_MSG" > /tmp/smart_commit_msg.txt

brew
npm
claude
cursor
chatgpt Ask user if they want to edit or use as-is
read -p "📝 Edit commit message? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Open editor for user to review/edit commit message
    if command -v vim &> /dev/null; then
        vim /tmp/smart_commit_msg.txt
    elif command -v nano &> /dev/null; then
        nano /tmp/smart_commit_msg.txt
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

# Clean up
rm -f /tmp/smart_commit_msg.txt
