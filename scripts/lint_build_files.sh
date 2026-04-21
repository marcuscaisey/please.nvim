#!/usr/bin/env bash

./pleasew format --write
if ! git diff --quiet; then
    echo 'The following files need to be formatted with "plz format --write"':
    git --no-pager diff --name-only
    exit 1
fi
