#!/usr/bin/env bash

input=$1
output=$2
if [ "$input" == "" ] || [ "$output" == "" ]; then
    echo "Usage: cast_to_gif.sh <input> <output>"
fi

agg --font-size 32 --fps-cap 60 --idle-time-limit 1 --last-frame-duration 3 "$input" "$output"
