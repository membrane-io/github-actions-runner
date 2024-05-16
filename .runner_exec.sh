#!/bin/bash

set -e

# IMPORTANT: This script is intended to be run in a Docker container.
# It is not intended to be run on your local machine.

if [ -z "$RUNNER_NAME" ]; then
  echo "RUNNER_NAME is not set"
  exit 1
fi
if [ -z "$RUNNER_URL" ]; then
  echo "RUNNER_URL is not set"
  exit 1
fi
if [ -z "$RUNNER_TOKEN" ]; then
  echo "RUNNER_TOKEN is not set"
  exit 1
fi

if [ -n "$RUNNER_LABELS" ]; then
  labels="--labels $RUNNER_LABELS"
else
  labels=""
fi

./config.sh \
  --name "$RUNNER_NAME" \
  --url "$RUNNER_URL" \
  --token "$RUNNER_TOKEN" \
  $labels \
  --unattended \
  --ephemeral

./run.sh
