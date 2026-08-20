#!/usr/bin/env python3

# ----------------------------------------------------------------------------------------
# Generate a SystemVerilog package containing the LDPC parity matrix
#
# Uses the same .cfg file as configPackage.py
# Ensure that the encoder/decoder configs are from the same LDPC code
# The .cfg file references a generator matrix (.gen)
# 
# This script:
#   1. Finds the .gen file from the .cfg file
#   2. Loads the generator matrix G
#   3. Verifies that G is systematic and has the form G = [I_K | P]
#   4. Extracts the parity matrix P
#   5. Generates ldpc_matrix_pkg.sv for use by the SystemVerilog encoder
#
# The generated PARITY_MATRIX is a compile-time constant
# It describes the XOR connections required by the encoder
# The matrix is not stored into memory
#
# Command line: python3 generate_encoder_matrix_pkg.py <CONFIG_FILENAME>
#
# Destination: python3 generate_encoder_matrix_pkg.py <CONFIG_FILENAME> -p <DEST_PATH>
# ----------------------------------------------------------------------------------------

import argparse
import os
import numpy as np

# ----------------------------------------------------------------------------------------
# Resolve a file path relative to the directory containing the .cfg file
# If the provided path is already absolute, it is simply normalized
# ----------------------------------------------------------------------------------------

def _resolve_against(base_dir, path):
    path = path.strip()

    if not path:
        raise ValueError("empty path")

    if os.path.isabs(path):
        return os.path.normpath(path)

    return os.path.normpath(os.path.join(base_dir, path))

# ----------------------------------------------------------------------------------------
# Find the generator matrix associated with an LDPC configuration
# 
# Takes the same hardware .cfg file used by configPackage.py
# This function searches the configuration for: gen_file = <generator matrix>
#
# Returns the resolved path to that .gen file
# ----------------------------------------------------------------------------------------

def read_gen_file_from_cfg(cfg_file_path):

    if not cfg_file_path.endswith(".cfg"):
        cfg_file_path += ".cfg"

    cfg_file_path = os.path.abspath(cfg_file_path)

    if not os.path.isfile(cfg_file_path):
        raise FileNotFoundError(f"cfg not found: {cfg_file_path!r}")

    cfg_dir = os.path.dirname(cfg_file_path)
    gen_file = None

    with open(cfg_file_path, "r", encoding="utf-8") as cfg_file:
        for raw_line in cfg_file:

            # Remove comments and whitespace
            line = raw_line.split("#", 1)[0].strip()

            if not line or "=" not in line:
                continue

            input_name, input_value = line.split("=", 1)
            input_name = input_name.strip()
            input_value = input_value.strip()

            if input_name == "gen_file":
                gen_file = input_value
                break

    if not gen_file:
        raise ValueError("cfg missing gen_file")

    return _resolve_against(cfg_dir, gen_file)


# ----------------------------------------------------------------------------------------
# Load the LDPC generator matrix G from the .gen file
# 
# Expected file contains one matrix row per line, with binary values separated by spaces
# Blank lines and comments beginnign with '#' are ignored
#
# The resulting NumPy array must have dimensions:  G.shape = (K, N)
# For example, the target (144,128) code should produce a 128 x 144 matrix
# 
# This function also performs basic format validation
# ----------------------------------------------------------------------------------------

def load_generator_matrix(filename):

    if not os.path.isfile(filename):
        raise FileNotFoundError(
            f"generator matrix not found: {filename!r}"
        )

    rows = []

    with open(filename, "r", encoding="utf-8") as gen_file:
        for raw_line in gen_file:

            line = raw_line.split("#", 1)[0].strip()

            if not line:
                continue

            row = [int(value) for value in line.split()]
            rows.append(row)

    if not rows:
        raise ValueError(f"generator matrix is empty: {filename!r}")

    n = len(rows[0])

    # Verify that all rows contain the same number of columns
    for row_index, row in enumerate(rows):
        if len(row) != n:
            raise ValueError(f"generator matrix has inconsistent row width at " f"row {row_index + 1}: {len(row)} vs {n}")

    G = np.asarray(rows, dtype=int)

    # LDPC matrices operate over GF(2), so only binary values are valid
    if not np.all((G == 0) | (G == 1)):
        raise ValueError("generator matrix must contain only 0 and 1")

    return G

# ----------------------------------------------------------------------------------------
# Extract the parity portion P from the generator matrix G
#
# Encoder assumes that the gen matrix is sytematic : G = [I_K | P]
#
# Format: 
#   G : K x N
#   I : K x K
#   P : K x (N-K)
#
# Function verifies that the final K columns of G are exactly I_K
# If not, the matrix does not match the format expected and package generation is stopped
# ----------------------------------------------------------------------------------------

def extract_parity_matrix(G):

    k, n = G.shape
    parity_bits = n - k

    if parity_bits <= 0:
        raise ValueError(f"invalid generator matrix dimensions: K={k}, N={n}")

    
    # Split G according to the expected systematic form: G = [I_K | P]
    systematic_part = G[:, :k]
    P = G[:, k:]

    # Generate the expected K x K identity matrix
    expected_identity = np.eye(k, dtype=int)

    if systematic_part.shape != (k, k):
        raise ValueError(
            "generator matrix cannot have the expected systematic "
            f"form [I_K | P]: systematic part has shape "
            f"{systematic_part.shape}, expected ({k}, {k})"
        )

    # Verify that the first K columns are exactly I_K
    if not np.array_equal(systematic_part, expected_identity):

        mismatch_count = np.count_nonzero(systematic_part != expected_identity)

        raise ValueError(
            "generator matrix is not in the expected systematic "
            "form [P | I_K]. "
            f"The last {k} columns are not I_K "
            f"({mismatch_count} mismatching entries)."
        )

    return P

# ----------------------------------------------------------------------------------------
# Generate the SystemVerilog package used by the LDPC encoder
#
# Only P of the gen matrix is required by the encoder
# because the K bits are copied directly into systematic portion of the codeword
#
# Generated package contains:
#   K              = Number of information bits
#   N              = Total codeword length
#   PARITY_BITS    = Number of parity bits (N-K)
#   PARITY_MATRIX  = Constant representation of P
#
# Encoder will use these constants to calculate the parity vector using XOR
# These values are compile-time constants
# Converted into fixed XOR logic during synthesis and do not imply storage in memory
# ----------------------------------------------------------------------------------------

def generate_sv_package(G, output_filename):

    k, n = G.shape
    parity_bits = n - k

    # Extract P and verify that G = [I_K | P]
    P = extract_parity_matrix(G)

    with open(output_filename, "w", encoding="utf-8") as sv_file:

        sv_file.write("package ldpc_encoder_matrix_pkg;\n\n")
        sv_file.write("    // ----------------------------------------------------------\n")
        sv_file.write("    // Automatically generated LDPC encoder configuration.\n")
        sv_file.write("    // Do not edit manually.\n")
        sv_file.write("    //\n")
        sv_file.write("    // Generator matrix format: G = [I_K | P]\n")
        sv_file.write("    // PARITY_MATRIX contains only P.\n")
        sv_file.write("    // ----------------------------------------------------------\n\n")
        sv_file.write(f"    parameter int K = {k};\n")
        sv_file.write(f"    parameter int N = {n};\n")
        sv_file.write(f"    parameter int PARITY_BITS = {parity_bits};\n\n")
        sv_file.write("    localparam logic [PARITY_BITS-1:0] " "PARITY_MATRIX [K] = '{\n")

        # Convert each row of P into a SystemVerilog binary constant
        # P has K rows and PARITY_BITS columns
        # Each row therefore becomes one PARITY_BITS-wide SV constant
        for row_index in range(k):

            bits = "".join(str(int(bit)) for bit in P[row_index])
            comma = "," if row_index != k - 1 else ""
            sv_file.write(f"        {parity_bits}'b{bits}{comma}\n")

        sv_file.write("    };\n\n")
        sv_file.write("endpackage\n")

# ----------------------------------------------------------------------------------------
# Main generation flow
#
# The command-line input is the hardware .cfg file
# Matches the workflow used by configPackage.py
#
# The destination directory can optionally be selected with --dest_path / -p
# ----------------------------------------------------------------------------------------

def main():

    parser = argparse.ArgumentParser(
        description=(
            "Generate a SystemVerilog LDPC matrix package "
            "from the generator matrix referenced by a .cfg file"
        )
    )

    parser.add_argument(
        "config",
        type=str,
        help="Config file defining the LDPC code",
    )

    parser.add_argument(
        "-p",
        "--dest_path",
        type=str,
        default=".",
        help=(
            "Destination directory for ldpc_encoder_matrix_pkg.sv "
            "(default: current directory)"
        ),
    )

    args = parser.parse_args()

    # Resolve generator matrix through the same .cfg used by the decoder
    gen_file_path = read_gen_file_from_cfg(args.config)

    # Load and validate G
    G = load_generator_matrix(gen_file_path)

    k, n = G.shape
    parity_bits = n - k

    # Explicitly verify G = [I_K | P] and extract P
    P = extract_parity_matrix(G)

    # Create the destination directory if it does not already exist
    dest_path = os.path.abspath(args.dest_path)
    os.makedirs(dest_path, exist_ok=True)

    output_filename = os.path.join(dest_path, "ldpc_encoder_matrix_pkg.sv",)

    # Generate SystemVerilog package
    generate_sv_package(G, output_filename)

    print("---------------------------------------")
    print("SystemVerilog LDPC package generated")
    print(f"Config           : {os.path.abspath(args.config)}")
    print(f"Generator matrix : {gen_file_path}")
    print(f"K                : {k}")
    print(f"N                : {n}")
    print(f"Parity bits      : {parity_bits}")
    print(f"P dimensions     : {P.shape[0]} x {P.shape[1]}")
    print("G format         : [I_K | P] verified")
    print(f"Output           : {output_filename}")
    print("---------------------------------------")


if __name__ == "__main__":
    main()