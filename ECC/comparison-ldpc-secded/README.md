# ECC Comparison

This directory compares the recovery capability of the SECDED and LDPC implementations using the same 128-bit data words and error masks.

```text
Data → Encoding → Error injection → Decoding → Verification
```

## Usage

Generate reproducible test vectors:

```bash
python3 generate_ecc_comparison_test_vectors.py \
    --weights 0 1 2 3 4 5 6 7 8 \
    --tests-per-weight 1000 \
    --scope data
```

Use `--scope codeword` to inject errors across all 144 codeword bits.

Run both simulations and analyze the results:

```bash
./run_ecc_comparison.sh
```

## Outputs

The generated CSV files and recovery-rate figure are written to `results/`.

Recovery rate is defined as:

```text
recovered words / tested words × 100
```