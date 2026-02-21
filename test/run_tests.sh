#!/bin/bash
FLUTTER=$(command -v flutter 2>/dev/null || echo "$HOME/flutter/bin/flutter")
"$FLUTTER" test "$@" 2>&1 > /tmp/test.txt; tail -3 /tmp/test.txt | tr '\r' '\n' | tail -1
