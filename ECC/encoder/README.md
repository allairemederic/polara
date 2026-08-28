# LDPC Encoder

The encoder converts each 128-bit L2 data word into a 144-bit LDPC codeword.

## Encoder Wrapper

`L2_ecc_encoder_wrapper` selects the ECC implementation according to the `USE_LDPC_ECC` compilation macro.

When `USE_LDPC_ECC` is enabled, the wrapper uses the combinational `ldpc_encoder` module. Otherwise, it uses the original SECDED implementation.

![alt text](../../docs/figures/encoder-wrapper.png)

## LDPC Encoder

`ldpc_encoder` computes the 16 parity bits defined by the generated LDPC matrix and appends them to the 128-bit input data.

The implementation is fully combinational and does not add a pipeline cycle to the L2 write path.

### Encoding Operation

The encoder uses a systematic generator matrix:

```text
G = [I_K | P]
```
where `I_K` is the 128×128 identity matrix and `P` is the generated 128×16 parity matrix.

All operations are performed in GF(2): addition is XOR and multiplication is AND.

Each parity bit corresponds to one column of `P`:

```text
parity[j] = XOR(message[i] AND P[i][j])
```

Because the code is systematic, the original message remains unchanged in the resulting codeword:

```text
┌───────────────────────────────┬─────────────────┐
│ Message    [143:16]           │ Parity   [15:0] │
└───────────────────────────────┴─────────────────┘
```

The RTL implements the matrix multiplication as 16 combinational XOR networks. `PARITY_MATRIX` is constant at synthesis time, allowing the synthesis tool to remove unused connections and optimize the resulting logic.

The reversed message index used in the RTL aligns the MSB-first `message_i` representation with the row ordering of the generated matrix.