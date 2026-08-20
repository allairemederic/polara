#!/usr/bin/env python3

import struct
import sys

# ==========================================================
# TO PRINT ALL VALUES
# ==========================================================

def decode_raw(values):

    for i, value in enumerate(values):
        print(f"results[{i}] = {value} (0x{value:016x})")


# ==========================================================
# FOR IMATMUL
# ==========================================================

def decode_imatmul(values):

    for i in range(0, len(values), 3):

        if i + 2 >= len(values):
            break

        s      = values[i]
        cycles = values[i + 1]
        verify = values[i + 2]

        if s == 0:
            break

        print(f"S={s:3d}  cycles={cycles:10d}  verify={verify}")

# ==========================================================
# FOR ICONV2D
# ==========================================================

def decode_iconv2d(values, label, iterations):

    idx = 0

    while idx < len(values):

        # Verify the header
        if idx + 1 >= len(values):
            break

        F = values[idx]
        parameter = values[idx + 1]

        if F == 0:
            break

        print(f"\nF={F} {label}={parameter}")

        idx += 2

        for iter in range(iterations):

            if idx + 1 >= len(values):
                return

            cycles = values[idx]
            verify = values[idx + 1]

            print(
                f"  iter {iter:2d}: "
                f"cycles={cycles:12d} "
                f"verify={verify}"
            )

            idx += 2

# ==========================================================
# CHOOSE THE RIGHT DECODER BASED ON BENCHMARK USED
# ==========================================================

def main():

    if len(sys.argv) != 3:
        print("Usage: decode_results_ddr.py results.bin benchmark")
        sys.exit(1)

    filename = sys.argv[1]
    benchmark = sys.argv[2].replace("_ddr", "")

    print(f"DEBUG: filename  = {filename}")
    print(f"DEBUG: benchmark = {benchmark}")

    with open(filename, "rb") as f:
        data = f.read()

    values = struct.unpack(">" + "Q" * (len(data) // 8), data)

    print(f"DEBUG: loaded {len(values)} values")

    if benchmark == "imatmul":
        print("DEBUG: calling decode_imatmul()")
        decode_imatmul(values)

    elif benchmark == "iconv2d_output":
        print("DEBUG: calling decode_iconv2d()")
        decode_iconv2d(values, "OUTPUT", 10)

    elif benchmark == "iconv2d_ifmap":
        print("DEBUG: calling decode_iconv2d()")
        decode_iconv2d(values, "IFMAP", 10)

    elif benchmark == "iconv2d_channels":
        print("DEBUG: calling decode_iconv2d()")
        decode_iconv2d(values)

    else:
        print("DEBUG: calling decode_raw()")
        decode_raw(values)


if __name__ == "__main__":
    main()