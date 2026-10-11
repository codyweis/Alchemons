#!/bin/zsh
# run.sh <codeDir> <outFile> [ENV=VAL ...]  -- runs the scaling harness measure step
D=$1; O=$2; shift 2
mkdir -p $(dirname $O)
cd $D && env "$@" OUT=$O flutter test test/ability_scaling_report_test.dart --tags preview --plain-name measure > ${O%.jsonl}.log 2>&1
echo "done $O $(tail -1 ${O%.jsonl}.log)"
