#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://api.github.com/repos/Allra-Fintech/allra-ai-commands/contents"
RAW_URL="https://raw.githubusercontent.com/Allra-Fintech/allra-ai-commands/main"

# Usage
usage() {
  echo "Usage: $0 <ai-tool> <role>"
  echo ""
  echo "AI Tools: claude, cursor, codex"
  echo "Roles: backend, frontend, data-engineering, devops, common"
  echo ""
  echo "Example: $0 claude backend"
  exit 1
}

# Get target directory based on AI tool
get_target_dir() {
  local tool=$1
  case $tool in
    claude)
      echo "$HOME/.claude/commands"
      ;;
    cursor)
      echo "$HOME/.cursor/commands"
      ;;
    codex)
      echo "$HOME/.codex/commands"
      ;;
    *)
      echo ""
      ;;
  esac
}

# Main
main() {
  local ai_tool=$1
  local role=$2

  # Validate arguments
  if [ -z "$ai_tool" ] || [ -z "$role" ]; then
    usage
  fi

  # Validate AI tool
  local target_dir=$(get_target_dir "$ai_tool")
  if [ -z "$target_dir" ]; then
    echo -e "${RED}Error: Unknown AI tool '$ai_tool'${NC}"
    echo "Supported tools: claude, cursor, codex"
    exit 1
  fi

  # Validate role
  case $role in
    backend|frontend|data-engineering|devops|common)
      ;;
    *)
      echo -e "${RED}Error: Unknown role '$role'${NC}"
      echo "Supported roles: backend, frontend, data-engineering, devops, common"
      exit 1
      ;;
  esac

  echo -e "${GREEN}Installing $ai_tool/$role commands...${NC}"

  # Create target directory if not exists
  mkdir -p "$target_dir"

  # Fetch file list from GitHub API
  local api_url="${REPO_URL}/${ai_tool}/${role}"
  local files=$(curl -sL "$api_url" | grep '"name"' | grep '\.md"' | sed 's/.*"name": "\(.*\)".*/\1/')

  if [ -z "$files" ]; then
    echo -e "${YELLOW}No commands found for $ai_tool/$role${NC}"
    exit 0
  fi

  # Download each file
  local count=0
  for file in $files; do
    local source_url="${RAW_URL}/${ai_tool}/${role}/${file}"
    local target_path="${target_dir}/${file}"

    # Backup if exists
    if [ -f "$target_path" ]; then
      cp "$target_path" "${target_path}.bak"
      echo -e "${YELLOW}Backed up: ${file} -> ${file}.bak${NC}"
    fi

    # Download
    curl -sL "$source_url" -o "$target_path"
    echo -e "${GREEN}Installed: ${file}${NC}"
    ((count++))
  done

  echo ""
  echo -e "${GREEN}Done! Installed $count command(s) to $target_dir${NC}"
}

main "$@"
