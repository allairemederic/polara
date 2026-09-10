# ECC Comparison

This directory compares the error-correction capability of the SECDED and LDPC implementations used in the L2 cache.

```text
128-bit data → Encoder → Error injection → Decoder → Verification
```

## Usage

To generate reproducible test vectors:
```bash
python3 generate_ecc_comparison_test_vectors.py \
    --weights 0 1 2 3 4 5 6 7 8 \
    --tests-per-weight 1000 \
    --scope data
```

Use `--scope codeword` to inject errors across all 144 codeword bits.

To run both simulations:

```bash
chmod +x run_comparison.sh
./run_comparison.sh
```
To analyse the results:
```bash
python3 analyze_ecc_comparison_results.py
```
## Outputs

```text
results/
├── secded_results.csv
├── ldpc_results.csv
├── comparison.csv
└── recovery_rate.png
```

The recovery rate is:

```text
recovered words / tested words × 100
```

Both ECC implementations use the same data and error masks.