#!/bin/bash
FLUTTER=$(command -v flutter 2>/dev/null || echo "$HOME/flutter/bin/flutter")
"$FLUTTER" analyze "$@" 2>&1 > /tmp/analyze.txt
tr '\r' '\n' < /tmp/analyze.txt | grep -v '^\s*$'
