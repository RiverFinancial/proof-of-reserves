#!/bin/sh
# Runs mix and npm formatters against any files staged for commit

set -e

function filterStaged() {
  path=$1
  # Lists all non-deleted, staged, file paths and strips the path prefix
  git diff --diff-filter=d --cached --name-only $path
}

STAGED_FILES=$(filterStaged ".")
mix format $STAGED_FILES
git add $STAGED_FILES