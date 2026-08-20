#!/bin/bash

set -e

export PITON_NUM_TILES=4

TESTFILE=$1

if [ -z "$TESTFILE" ]; then
    echo "Usage: ./run_uart_test.sh <source_file.c>"
    exit 1
fi

echo "Compiling..."
rv64_cc "$TESTFILE"
rv64_img

echo "Generating binary image..."
riscv64-unknown-elf-objcopy -I elf64-littleriscv -O binary diag.exe diag.bin
riscv64-unknown-elf-objcopy --reverse-bytes 8 -I binary -O binary diag.bin diag_reversed.bin

echo
echo "Booting FPGA..."
sh /export/tmp/humblet/PolyMTL/u280_pcie_hbm/boot_ariane.sh diag_reversed.bin diag_reversed.bin

echo
echo "Opening UART..."
screen /dev/ttyUSB0 115200