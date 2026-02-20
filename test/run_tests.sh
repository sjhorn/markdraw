#!/bin/bash
flutter test 2>&1 > /tmp/test.txt; tail -3 /tmp/test.txt | tr '\r' '\n' | tail -1
