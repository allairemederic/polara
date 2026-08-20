#!/bin/bash

set -e

export PITON_NUM_TILES=4

TESTFILE=$1

if [ -z "$TESTFILE" ]; then
    echo "Usage: ./run_debug.sh <source_file.c>"
    exit 1
fi

echo "Compiling..."
rv64_cc "$TESTFILE"
rv64_img
riscv64-unknown-elf-objcopy -I elf64-littleriscv -O binary diag.exe diag.bin
riscv64-unknown-elf-objcopy --reverse-bytes 8 -I binary -O binary diag.bin diag_reversed.bin

echo
echo "Clearing DDR buffer..."

dma-to-device -d /dev/qdma01000-MM-1 -s 4096 -a 0x88000000

echo "Booting FPGA..."
sh /export/tmp/humblet/PolyMTL/u280_pcie_hbm/boot_ariane.sh diag_reversed.bin
sleep 4

echo "Reading DDR..."
dma-from-device -d /dev/qdma01000-MM-1 -a 0x88000000 -s 4096 -f results.bin

echo
echo "DDR dump (first 10 lines):"
od -Ax -tx8 results.bin | tee raw_dump.txt | head -n 10