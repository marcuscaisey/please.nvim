#!/usr/bin/env bash

output=$1
if [ "$output" == "" ]; then
    echo "Usage: record_demo.sh <output> [<arg>...]"
fi

nvim_args=()
for arg in "${@:2}"; do
    printf -v quoted_arg '%q' "$arg"
    nvim_args+=("$quoted_arg")
done

asciinema record \
    --command "plz minimal_nvim -- ${nvim_args[*]}" \
    --window-size=120x29 \
    --overwrite "$output"
