#!/bin/bash
DART=$(command -v dart 2>/dev/null || echo "$HOME/flutter/bin/dart")
FLUTTER=$(command -v flutter 2>/dev/null || echo "$HOME/flutter/bin/flutter")
"$DART" fix --apply 2>&1 > /tmp/dartfix.txt; tail -3 /tmp/dartfix.txt | tr '\r' '\n' | tail -1
"$FLUTTER" analyze 2>&1 > /tmp/analyze.txt; tail -3 /tmp/analyze.txt | tr '\r' '\n' | tail -1
