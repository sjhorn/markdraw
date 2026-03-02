#!/bin/bash
# Wrapper for sed across the project.
# Usage: scripts/sed.sh <sed-expression> <file-or-glob>
# Example: scripts/sed.sh 's/old/new/g' lib/src/rendering/rough/draw_style.dart
sed "$@"
