#!/usr/bin/env python3

# Generate reference test vectors for the SystemVerilog LDPC encoder
#
# Loads the generator matrix G from the .gen file
# Verifies that G has the systematic form G = [I_K | P]
# Generates deterministic edge-case messages
# Generates random messages
# Computes each expected codeword using c = mG mod 2
# Writes message/codeword pairs to a test-vector file
#
# The generated vectors are used by tb_ldpc_encoder.sv to automatically
# compare the RTL encoder output against an independent software reference

import argparse
import numpy as np

NUM_RANDOM_TESTS = 1000

# Load generator matrix G
def load_generator_matrix(filename):

    G = np.loadtxt(filename, dtype=int)

    if G.ndim != 2:
        raise ValueError("Generator matrix must be two-dimensional")

    if not np.all((G == 0) | (G == 1)):
        raise ValueError("Generator matrix must contain only 0 and 1")

    return G

# Load the LDPC parity-check matrix H from an alist (.al) file
#
# Expected alist format:
#   line 1: N M
#   line 2: max_VN_degree max_CN_degree
#   line 3: degree of each of the N variable nodes
#   line 4: degree of each of the M check nodes
#   next N lines: check-node connections for each variable node
#
# The alist uses 1-based indices, while NumPy uses 0-based indices
def load_parity_check_matrix(alist_filename):

    with open(alist_filename, "r", encoding="utf-8") as file:

        # Number of variable nodes N and check nodes M
        n, m = map(int, file.readline().split())

        # Maximum VN and CN degrees
        max_vn_degree, max_cn_degree = map(int, file.readline().split())

        # Degree of each node
        vn_degrees = list(map(int, file.readline().split()))
        cn_degrees = list(map(int, file.readline().split()))

        if len(vn_degrees) != n:
            raise ValueError(f"Expected {n} VN degrees, got {len(vn_degrees)}")

        if len(cn_degrees) != m:
            raise ValueError(f"Expected {m} CN degrees, got {len(cn_degrees)}")

        # Reconstruct dense parity-check matrix H
        H = np.zeros((m, n), dtype=int)

        # The next N lines describe the check-node connections of each variable node
        for vn in range(n):

            connections = list(map(int, file.readline().split()))

            if len(connections) != vn_degrees[vn]:
                raise ValueError(f"VN {vn} has {len(connections)} connections, "f"expected {vn_degrees[vn]}")

            for cn in connections:
                H[cn - 1, vn] = 1 # alist indices start at 1

    return H

# Verify systematic generator matrix
# Expected: G = [I_K | P]
def verify_generator_matrix(G):

    k, n = G.shape

    if n <= k:
        raise ValueError(
            f"Invalid generator matrix dimensions: K={k}, N={n}"
        )

    identity = np.eye(k, dtype=int)

    if not np.array_equal(G[:, :k], identity):
        raise ValueError(
            "Generator matrix is not in systematic form [I_K | P]"
        )

    return k, n

# Reference LDPC encoder
# Compute: c = mG mod 2
# Uses the complete gen matrix G and is independent from the PARITY_MATRIX used by the RTL encoder
def encode_reference(message, G):

    return (message @ G) % 2

# Convert a binary NumPy vector to hexadecimal
# Matrix/vector index 0 is written as the leftmost bit
def bits_to_hex(bits):

    bit_string = "".join(str(int(bit)) for bit in bits)

    width = (len(bits) + 3) // 4

    return f"{int(bit_string, 2):0{width}x}"

# Generate deterministic edge-case messages
def generate_edge_cases(k):

    messages = []

    messages.append(np.zeros(k, dtype=int)) # All zeros
    messages.append(np.ones(k, dtype=int)) # All ones

    # First information bit only
    msg = np.zeros(k, dtype=int)
    msg[0] = 1
    messages.append(msg)

    # Last information bit only
    msg = np.zeros(k, dtype=int)
    msg[-1] = 1
    messages.append(msg)

    messages.append(np.arange(k) % 2) # Alternating 0101...
    messages.append(1 - (np.arange(k) % 2)) # Alternating 1010...

    return messages

# Generate random messages
# A fixed seed makes the test repeatable
def generate_random_messages(k, count, seed):

    rng = np.random.default_rng(seed)

    return [
        rng.integers(0, 2, size=k, dtype=int)
        for _ in range(count)
    ]

# Main
def main():

    parser = argparse.ArgumentParser(description="Generate LDPC encoder reference test vectors")

    parser.add_argument("gen_file", help="LDPC generator matrix (.gen)")
    parser.add_argument("al_file", help="LDPC parity-check matrix (.al)")
    parser.add_argument("-o", "--output", default="encoder_test_vectors.txt", help="Output test-vector file")
    parser.add_argument("-n", "--num_random", type=int, default=NUM_RANDOM_TESTS, help="Number of random test vectors")
    parser.add_argument("--seed", type=int, default=12345, help="Random generator seed")

    args = parser.parse_args()

    # Load matrices
    G = load_generator_matrix(args.gen_file)
    H = load_parity_check_matrix(args.al_file)

    # Validate dimensions
    k, n = verify_generator_matrix(G)

    if H.shape[1] != n:
        raise ValueError(f"G and H dimensions do not match: " f"G has N={n}, H has N={H.shape[1]}")

    # Print parameters
    parity_bits = n - k

    print("---------------------------------------")
    print("LDPC encoder reference")
    print("---------------------------------------")
    print(f"K                : {k}")
    print(f"N                : {n}")
    print(f"Parity bits      : {parity_bits}")
    print("G format         : [I_K | P] verified")

    # Generate messages
    messages = generate_edge_cases(k)
    messages += generate_random_messages(k, args.num_random, args.seed)

    # Generate reference codewords

    with open(args.output, "w", encoding="utf-8") as output_file:

        for message in messages:

            codeword = encode_reference(message, G)

            # Mathematical validation
            syndrome = (H @ codeword) % 2

            if np.any(syndrome):
                raise RuntimeError("Invalid reference codeword: H * c^T != 0")

            # Only write the vector if it is mathematically valid
            message_hex = bits_to_hex(message)
            codeword_hex = bits_to_hex(codeword)

            output_file.write(f"{message_hex} {codeword_hex}\n")

    print(f"Test vectors     : {len(messages)}")
    print(f"Output           : {args.output}")
    print("---------------------------------------")


if __name__ == "__main__":
    main()