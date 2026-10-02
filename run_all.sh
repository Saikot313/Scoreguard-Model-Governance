#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
for s in 01_generate_data 02_scorecard 03_policy 04_monitoring; do echo "== $s"; python3 python/$s.py > /dev/null; done
echo done
