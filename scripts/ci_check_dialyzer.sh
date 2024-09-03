#!/bin/bash
# To be run in check-all.yml GH workflow

# Exit early on error
set -e

# Duplicate stdout and stderr to a file, while still printing
mix dialyzer --format github 2>&1 | tee dialyzer_output.txt

# tee always exits with 0, so need to get dialyzer exit code using PIPESTATUS
dialyzer_exit_code="${PIPESTATUS[0]}"

# We only want to hard fail workflow if errors were emitted, not warnings
if [[ ! $dialyzer_exit_code =~ ^0|2$ ]]; then
  echo "Error: dialyzer returned a non-success (0) and non-warning (2) exit code $dialyzer_exit_code"
  exit $dialyzer_exit_code
fi