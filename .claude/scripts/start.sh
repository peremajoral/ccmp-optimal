#!/bin/bash

# ABOUTME: Epic starter following specifications from .claude/commands/start.md
# ABOUTME: Activates epic context, loads progress, switches branches, and prepares development environment

set -euo pipefail

# Configuration
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
CLAUDE_DIR="$PROJECT_ROOT/.claude"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# STEP 1: Validate Epic Exists
epic_name="$1"

# Validate epic name provided
[[ -n "$epic_name" ]] || { echo "Error: Epic name required"; exit 1; }

# Check epic exists
epic_dir=".claude/epics/$epic_name"
[[ -d "$epic_dir" ]] || { echo "Error: Epic '$epic_name' not found"; exit 1; }

deliverables_file="$epic_dir/deliverables.json"
[[ -f "$deliverables_file" ]] || { echo "Error: deliverables.json not found"; exit 1; }

# STEP 2: Load Epic Context
echo "🚀 Activating epic: $epic_name"

# Extract epic information
description=$(jq -r '.description // ("Epic: " + .epic)' "$deliverables_file")
github_issue=$(jq -r '.github_issue // "null"' "$deliverables_file")
repository=$(jq -r '.repository // ""' "$deliverables_file")

echo "📝 Description: $description"
if [[ "$github_issue" != "null" && "$github_issue" != "" ]]; then
  echo "🔗 GitHub Issue: #$github_issue"
else
  echo "⚠️  No GitHub issue linked"
fi

# STEP 3: Calculate Current Progress
# Calculate completion status
total=$(jq -r '.deliverables | length' "$deliverables_file")
completed=0

echo "📊 Deliverable Status:"
while IFS= read -r deliverable; do
  pattern=$(echo "$deliverable" | jq -r '.pattern')
  required=$(echo "$deliverable" | jq -r '.required // false')
  desc=$(echo "$deliverable" | jq -r '.description // ""')

  if [[ -f "$pattern" && -s "$pattern" ]]; then
    ((completed++))
    echo "- ✅ $pattern (completed)"
  else
    req_text=""
    [[ "$required" == "true" ]] && req_text=" (required)" || req_text=" (optional)"
    echo "- 📋 $pattern (pending)$req_text"
  fi

  if [[ -n "$desc" ]]; then
    echo "     $desc"
  fi
done < <(jq -c '.deliverables[]' "$deliverables_file")

percentage=$((completed * 100 / total))
echo "📈 Progress: ${completed}/${total} deliverables complete (${percentage}%)"

# STEP 4: Switch to Epic Branch
expected_branch="feature/epic-$epic_name"
current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")

echo "🌿 Git Branch Management:"
if [[ "$current_branch" == "$expected_branch" ]]; then
  echo "- Already on epic branch: $expected_branch"
else
  echo "- Current branch: $current_branch"
  echo "- Switching to epic branch: $expected_branch"

  # Check if epic branch exists
  if git show-ref --verify --quiet "refs/heads/$expected_branch"; then
    git checkout "$expected_branch"
    echo "✅ Switched to existing epic branch"
  else
    echo "⚠️  Epic branch $expected_branch doesn't exist"
    echo "🔧 Creating epic branch from main..."

    git checkout main
    git pull origin main
    git checkout -b "$expected_branch"
    echo "✅ Created and switched to epic branch"
  fi
fi

# STEP 5: Load Supermemory Context
echo "💭 Loading context from Supermemory..."

# Search for related patterns and decisions
if command -v mcp__api-supermemory-ai__search >/dev/null 2>&1; then
  echo "🔍 Searching for epic-related context..."

  # Search for architectural patterns
  arch_context=$(mcp__api-supermemory-ai__search "$epic_name architecture patterns" 2>/dev/null || echo "")
  if [[ -n "$arch_context" ]]; then
    echo "📋 Found architectural context for $epic_name"
  fi

  # Search for similar implementations
  impl_context=$(mcp__api-supermemory-ai__search "similar $epic_name implementations" 2>/dev/null || echo "")
  if [[ -n "$impl_context" ]]; then
    echo "📋 Found similar implementation patterns"
  fi
else
  echo "⚠️  Supermemory search not available"
fi

# STEP 6: Verify Auto-Sync Status
echo "🔄 Auto-Sync Verification:"

# Check if post-commit hook exists and is executable
post_commit_hook=".git/hooks/post-commit"
if [[ -x "$post_commit_hook" ]]; then
  echo "✅ Post-commit hook active"
else
  echo "⚠️  Post-commit hook not found or not executable"
fi

# Check GitHub CLI authentication
if gh auth status >/dev/null 2>&1; then
  echo "✅ GitHub CLI authenticated"
else
  echo "⚠️  GitHub CLI not authenticated"
fi

# Check if auto-sync is enabled
auto_sync_enabled=$(jq -r '.auto_sync_enabled // true' "$deliverables_file")
if [[ "$auto_sync_enabled" == "true" ]]; then
  echo "✅ Auto-sync enabled for this epic"
else
  echo "⚠️  Auto-sync disabled for this epic"
fi

# STEP 7: Show Next Steps
echo ""
echo "🎯 Next Steps:"

if [[ "$percentage" -eq 0 ]]; then
  echo "1. 🚀 Start implementing deliverables"
  # Show first pending deliverable
  first_pending=$(jq -r '.deliverables[0].pattern' "$deliverables_file")
  echo "   Begin with: $first_pending"
elif [[ "$percentage" -eq 100 ]]; then
  echo "1. 🎉 Epic is complete! Ready to close"
  echo "   Run: close $epic_name"
else
  echo "1. 🔧 Continue implementing remaining deliverables"
  # Show next pending deliverable
  while IFS= read -r pattern; do
    if [[ ! -f "$pattern" || ! -s "$pattern" ]]; then
      echo "   Next: $pattern"
      break
    fi
  done < <(jq -r '.deliverables[].pattern' "$deliverables_file")
fi

echo "2. 💾 Commit changes to trigger auto-sync"
echo "3. 🔍 Monitor progress with: status $epic_name"

if [[ "$github_issue" != "null" && "$github_issue" != "" ]]; then
  echo "4. 👀 Track progress at: https://github.com/$repository/issues/$github_issue"
fi

echo ""
echo "Ready for development! 🛠️"