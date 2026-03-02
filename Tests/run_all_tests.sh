#!/usr/bin/env bash
# CiteTrack 一键运行全部测试（功能 + 压力）
# 用法: ./Tests/run_all_tests.sh  或  bash Tests/run_all_tests.sh
# 可选: CITETRACK_PROJECT_ROOT=/path/to/repo ./Tests/run_all_tests.sh

set -e
ROOT="${CITETRACK_PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT"

echo "=============================================="
echo "  CiteTrack 完整测试套件"
echo "  项目根目录: $ROOT"
echo "=============================================="
echo ""

FAILED=0

echo ">>> 1/2 功能与规范测试 (CiteTrackTests)..."
if swift Tests/CiteTrackTests.swift; then
  echo ""
else
  FAILED=1
fi

echo ">>> 2/2 压力测试 (CiteTrackStressTests)..."
export CITETRACK_PROJECT_ROOT="$ROOT"
if swift Tests/CiteTrackStressTests.swift; then
  echo ""
else
  FAILED=1
fi

echo "=============================================="
if [ "$FAILED" -eq 0 ]; then
  echo "  全部测试通过"
  echo "=============================================="
  exit 0
else
  echo "  部分测试失败，请查看上方输出"
  echo "=============================================="
  exit 1
fi
