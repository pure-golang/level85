#!/bin/bash
set -euo pipefail

get_diff() {
  git diff -U0 --diff-filter=ACM "$1" HEAD \
    -- ':!*.lock' ':!go.sum' ':!package-lock.json' \
       ':!*.pb.go' ':!*_gen.go' ':!vendor/' \
    | sed 's|^diff --git a/.* b/\(.*\)|@@@ \1|; s|^@@ .* @@.*|@@|' \
    | grep -Ev '^(-([^-]|$)|---|Binary files|\\\ No newline|index |\+\+\+ )' || true
}

if [ -n "${CI_MERGE_REQUEST_DIFF_BASE_SHA:-}" ]; then
  echo "[debug] CI mode, base SHA=$CI_MERGE_REQUEST_DIFF_BASE_SHA" >&2
  GIT_DIFF=$(get_diff "$CI_MERGE_REQUEST_DIFF_BASE_SHA")
else
  CURRENT=$(git branch --show-current)
  echo "[debug] CURRENT=$CURRENT" >&2
  if [ -z "$CURRENT" ]; then
    echo "Ошибка: detached HEAD — переключитесь на ветку перед запуском" >&2
    exit 1
  fi
  mapfile -t _other_branches < <(git for-each-ref --format='%(refname:short)' refs/heads/ | grep -v "^${CURRENT}$")
  if [ "${#_other_branches[@]}" -gt 0 ]; then
    OLDEST_UNIQUE=$(git log HEAD --not "${_other_branches[@]}" --format="%H" 2>/dev/null | tail -1 || true)
  else
    OLDEST_UNIQUE=$(git log HEAD --format="%H" 2>/dev/null | tail -1 || true)
  fi
  echo "[debug] OLDEST_UNIQUE=$OLDEST_UNIQUE" >&2
  if [ -z "$OLDEST_UNIQUE" ]; then
    echo "Ошибка: не удалось найти уникальные коммиты ветки '$CURRENT'" >&2
    exit 1
  fi
  MERGE_BASE=$(git log --pretty=%P -1 "$OLDEST_UNIQUE" 2>/dev/null | awk '{print $1}' || true)
  echo "[debug] MERGE_BASE=$MERGE_BASE" >&2
  if [ -z "$MERGE_BASE" ]; then
    echo "Ошибка: не удалось определить точку ветвления для ветки '$CURRENT'" >&2
    exit 1
  fi
  GIT_DIFF=$(get_diff "$MERGE_BASE")
fi

echo "[debug] GIT_DIFF length=${#GIT_DIFF}" >&2

if [ -z "$GIT_DIFF" ]; then
  echo "Нет изменений для ревью" >&2
  exit 1
fi

echo "$GIT_DIFF"
