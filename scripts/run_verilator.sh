#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"

if ! command -v verilator >/dev/null 2>&1; then
  echo "Error: verilator was not found in PATH." >&2
  echo "Run: source ~/tools/oss-cad-suite/environment" >&2
  exit 1
fi

mkdir -p "${BUILD_DIR}"
cd "${PROJECT_ROOT}"

verilator \
  --binary \
  --timing \
  --trace \
  -Wall \
  -Wno-BLKSEQ \
  --top-module packet_fsm_tb \
  --Mdir "${BUILD_DIR}/obj_dir" \
  "${PROJECT_ROOT}/rtl/packet_fsm.sv" \
  "${PROJECT_ROOT}/tb/packet_fsm_tb.sv"

"${BUILD_DIR}/obj_dir/Vpacket_fsm_tb"
