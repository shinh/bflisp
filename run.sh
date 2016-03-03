#!/bin/sh

if [ -z $2 ]; then
    tn=$(basename $1 .exe)
elif [ -z $3 ]; then
    tn=$(basename $(echo $2 | sed 's/bfs$/bf/') .bf)
else
    tn=$(basename $(echo $3 | sed 's/bfs$/bf/') .bf)
fi
inputs=$(/bin/ls test/${tn}*.in 2> /dev/null | sort)

set -e

if [ "x" = "x${inputs}" ]; then
    inputs=/dev/null
fi

for input in ${inputs}; do
    if [ "/dev/null" != "${input}" ]; then
        echo "=== ${input} ==="
    fi
    "$@" < ${input}
    echo
done
