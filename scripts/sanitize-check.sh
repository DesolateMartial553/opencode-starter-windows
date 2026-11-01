#!/usr/bin/env bash
# Run before every push: fails if the tree contains secrets or personal references.
# Usage: scripts/sanitize-check.sh
cd "$(dirname "$0")/.." || exit 2
fail=0

# 1) personal / secret patterns anywhere
pat='/home/|AIza[0-9A-Za-z_-]{20,}|sk-[A-Za-z0-9]{20,}|sk-or-v1-[A-Za-z0-9]{10,}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|eyJ[A-Za-z0-9_-]{20,}|BEGIN [A-Z ]*PRIVATE KEY'
# maintainer-only personal terms (names, handles, ids) live in an untracked file so they are never published
if [ -f scripts/personal-patterns.txt ]; then pat="$pat|$(paste -sd'|' scripts/personal-patterns.txt)"; fi
if grep -rnIE --exclude-dir=.git --exclude=sanitize-check.sh --exclude=personal-patterns.txt "$pat" .; then
  echo "FAIL: personal/secret pattern found (above)"; fail=1
fi

# 2) the repo owner name is allowed only in the docs and the installer scripts
if grep -rIl --exclude-dir=.git "DesolateMartial553" . | grep -vE '^\./(README\.md|GETTING-STARTED\.md|TROUBLESHOOTING\.md|[A-Za-z0-9_-]+\.ps1|scripts/sanitize-check\.sh)$'; then
  echo "FAIL: GitHub username appears outside README/installers"; fail=1
fi

# 3) files that must never be shipped
if find . -path ./.git -prune -o \( -name 'service.json' -o -name 'credentials.json' -o -name 'auth.json' -o -name '.env' -o -name '*.log' -o -name '*.bak*' -o -name node_modules \) -print | grep .; then
  echo "FAIL: forbidden file present"; fail=1
fi

# 4) every commit must use the GitHub noreply address
bad=$(git log --format='%ae%n%ce' | sort -u | grep -v '@users.noreply.github.com$')
if [ -n "$bad" ]; then echo "FAIL: non-noreply author/committer email in history:"; echo "$bad"; fail=1; fi

[ $fail -eq 0 ] && echo "sanitize-check: clean"
exit $fail
