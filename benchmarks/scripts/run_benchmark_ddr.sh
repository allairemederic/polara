#!/bin/bash

set -e

echo
echo "POLARA TESTING USING DDR"

# ==========================================================
# CHECK ARGUMENTS
# ==========================================================

TESTFILE=$1

if [ -z "$TESTFILE" ]; then
    echo "Usage: ./benchmark_in_ddr.sh <source_file.c>"
    exit 1
fi

if [ ! -f "$TESTFILE" ]; then
    echo "Error: file not found: $TESTFILE"
    exit 1
fi

# ==========================================================
# CREATE A RUN DIRECTORY
# ==========================================================

BENCHMARK_NAME=$(basename "$TESTFILE" .c)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RUN_DIR="${BENCHMARK_NAME}_${TIMESTAMP}"

mkdir -p "$RUN_DIR"

# ==========================================================
# CONFIGURATION
# ==========================================================

export PITON_NUM_TILES=4

BUFFER_SIZE=4096
BUFFER_ADDRESS=0x88000000

echo
echo "BENCHMARK CONFIGURATION"
echo "Benchmark       : $TESTFILE"
echo "Run directory   : $RUN_DIR"
echo "Tiles           : ${PITON_NUM_TILES}"
echo "DDR address     : ${BUFFER_ADDRESS}"
echo "Buffer size     : ${BUFFER_SIZE} bytes"

# ==========================================================
# REDIRECT STDOUT/STDERR TO LOGFILE
# ==========================================================

LOGFILE="${RUN_DIR}/${BENCHMARK_NAME}.log"

exec 3>&1 4>&2
exec >> "$LOGFILE" 2>&1

# ==========================================================
# SAVE A COPY OF BENCHMARK SOURCE
# ==========================================================

cp "$TESTFILE" "$RUN_DIR/"

# ==========================================================
# COMPILATION
# ==========================================================

echo
echo "COMPILING TESTFILE"

rv64_cc "$TESTFILE"
rv64_img
riscv64-unknown-elf-objcopy -I elf64-littleriscv -O binary diag.exe diag.bin
riscv64-unknown-elf-objcopy --reverse-bytes 8 -I binary -O binary diag.bin diag_reversed.bin

# ==========================================================
# CLEAR DDR BUFFER
# ==========================================================

# Uncomment this section only if the QDMA driver has NOT already been initialized
# (if boot_ariane.sh was not first used to configure the FPGA)

# dma-ctl qdma01000 reg write bar 2 0x0 0x2
# dma-ctl qdma01000 reg write bar 2 0x0 0x3

# echo
# echo "CLEARING DDR BUFFER"

# dma-to-device -d /dev/qdma01000-MM-1 -s ${BUFFER_SIZE} -a ${BUFFER_ADDRESS}

# ==========================================================
# BOOT FPGA
# ==========================================================

echo
echo "BOOTING ARIANE"

sh /export/tmp/humblet/PolyMTL/u280_pcie_hbm/boot_ariane.sh diag_reversed.bin
sleep 4

# ==========================================================
# READING RESULTS FROM THE DDR
# ==========================================================

echo
echo "READING RESULTS FROM THE DDR"

dma-from-device -d /dev/qdma01000-MM-1 -a 0x88000000 -s ${BUFFER_SIZE} -f results.bin

# ==========================================================
# RAW MEMORY DUMP
# ==========================================================

echo
echo "GENERATING RAW MEMORY DUMP"

od -Ax -tx8 results.bin > "${RUN_DIR}/raw_dump.txt"

# ==========================================================
# DECODING RESULTS
# ==========================================================

echo
echo "DECODING RESULTS"

python3 decode_ddr.py results.bin "$BENCHMARK_NAME" tee "${RUN_DIR}/decoded_results.txt"

# ==========================================================
# MOVE ARTIFACTS TO RUN DIRECTORY
# ==========================================================

ARTIFACTS=(
    diag.bin
    diag_reversed.bin
    diag.exe
    diag.o
    diag.map
    diag.objdump
    diag.dump
    diag.ev
    mem.image
    symbol.tbl
    results.bin
)

for file in "${ARTIFACTS[@]}"; do
    [ -f "$file" ] && mv "$file" "$RUN_DIR/"
done

# ==========================================================
# RESTORE TERMINAL STDOUT/STDERR
# ==========================================================

exec 1>&3 2>&4

# ==========================================================
# SUMMARY
# ==========================================================

echo
echo "BENCHMARK COMPLETED"
echo "Files saved in  : ${RUN_DIR}"
echo "Log file        : $LOGFILE"
echo "Raw binary      : results.bin"
echo "Raw dump        : raw_dump.txt"
echo "Decoded results : decoded_results.txt"