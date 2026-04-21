#!/usr/bin/env bash

if ./pleasew format --quiet; then
    printf '\x1b[1;32mBUILD files formatted correctly\x1b[0m\n'
else
    printf '\x1b[1;31mBUILD files not formatted correctly. Run "plz format --write".\x1b[0m\n'
    exit 1
fi
