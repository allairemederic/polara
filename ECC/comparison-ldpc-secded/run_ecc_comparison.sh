#!/bin/bash
set -e

mkdir -p ecc_comparison_results

# Run SECDED
vcs -f filelists/secded.f -o simv_secded
./simv_secded > ecc_comparison_results/secded_results.log

# Run LDPC
vcs -f filelists/ldpc.f -o simv_ldpc
./simv_ldpc > ecc_comparison_results/ldpc.log

# Analyse results
python3 analyze_results.py