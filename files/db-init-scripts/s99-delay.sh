#!/bin/bash 
set -e

i=10
while (( i > 0 )); do
    echo "Sleeping... (i=$i)"
    sleep 1
    i=$((i - 1))
done
