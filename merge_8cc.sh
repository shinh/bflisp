#!/bin/sh

set -e

mkdir -p tmp8cc

cat libf.h

for c in 8cc/*.h 8cc/*.c; do
    grep -v '#include <' $c > tmp$c
done

for c in cpp.c debug.c dict.c  error.c gen.c lex.c list.c main.c parse.c string.c; do
    echo "// $c start"
    8cc/8cc -E tmp8cc/$c
    echo "// $c end"
done
