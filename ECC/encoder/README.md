# LDPC Encoder

The encoder converts each 128-bit L2 data word into a systematic 144-bit LDPC codeword containing 16 parity bits.

## Implementation

[`L2_ecc_encoder_wrapper.sv`](L2_ecc_encoder_wrapper.sv) selects the protection mechanism using `USE_LDPC_ECC`:

- `enabled`: combinational LDPC encoder;
- `disabled`: original SECDED encoder.

[`ldpc_encoder.sv`](ldpc_encoder.sv) computes the parity bits using the systematic generator matrix:

```text
G = [ P | I ]
```
The resulting codeword is organized as:
```textMessage    [143:16] 
┌─────────────────┬────────────────────────────────────┐
│ Parity   [15:0] │           Message    [143:16]      │
└─────────────────┴────────────────────────────────────┘
```
The encoder is fully combinational and adds no pipeline cycle to the L2 write paths.

## Matrix Generation

[`generate_encoder_matrix_pkg.py`](generator/generate_encoder_matrix_pkg.py) extracts the 128×16 parity matrix P from the generator matrix and produces `ldpc_encoder_matrix_pkg.sv`.

The generated matrix is constant at synthesis time and is implemented as parallel XOR logic.

## Integration and Verification

- [`L2 Datapath Integration`](integration/datapath-encoder.md)
- [`tb_ldpc_encoder.sv`](verification/tb_ldpc_encoder.sv)
- [`tb_L2_ecc_encoder_wrapper.sv`](verification/tb_L2_ecc_encoder_wrapper.sv)