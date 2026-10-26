#!/usr/bin/env python3

import argparse
import csv
import random
from pathlib import Path

DATA_WIDTH = 128
CODEWORD_WIDTH = 144

def generate_error_mask(
    error_weight: int,
    rng: random.Random,
    injectable_positions: list[int],
    test_index: int,
) -> int:
    """
    Generate a mask containing exactly error_weight bits.

    For weight 1, positions are traversed sequentially so that every
    injectable bit is eventually tested. For larger weights, positions
    are selected pseudo-randomly using a reproducible seed.
    """
    if error_weight == 0:
        return 0

    if error_weight > len(injectable_positions):
        raise ValueError(
            f"Error weight {error_weight} exceeds the number of "
            f"injectable positions ({len(injectable_positions)})."
        )

    if error_weight == 1:
        position = injectable_positions[
            test_index % len(injectable_positions)
        ]
        return 1 << position

    positions = rng.sample(injectable_positions, error_weight)

    mask = 0
    for position in positions:
        mask |= 1 << position

    return mask


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate common ECC comparison test vectors."
    )

    parser.add_argument(
        "--output",
        type=Path,
        default=Path("test_vectors/ecc_comparison_vectors.csv"),
        help="Output CSV file.",
    )

    parser.add_argument(
        "--weights",
        type=int,
        nargs="+",
        default=list(range(0, 9)),
        help="Error weights to generate.",
    )

    parser.add_argument(
        "--tests-per-weight",
        type=int,
        default=1000,
        help="Number of tests generated for each error weight.",
    )

    parser.add_argument(
        "--seed",
        type=int,
        default=20260909,
        help="Random seed used to make the experiment reproducible.",
    )

    parser.add_argument(
        "--scope",
        choices=("data", "codeword"),
        default="codeword",
        help=(
            "'data' injects errors only in bits 0-127. "
            "'codeword' injects errors anywhere in bits 0-143."
        ),
    )

    args = parser.parse_args()

    rng = random.Random(args.seed)

    if args.scope == "data":
        injectable_positions = list(range(DATA_WIDTH))
    else:
        injectable_positions = list(range(CODEWORD_WIDTH))

    args.output.parent.mkdir(parents=True, exist_ok=True)

    test_id = 0

    with args.output.open("w", newline="", encoding="utf-8") as output_file:
        writer = csv.DictWriter(
            output_file,
            fieldnames=[
                "test_id",
                "error_weight",
                "original_data",
                "error_mask",
            ],
        )

        writer.writeheader()

        for error_weight in args.weights:
            for test_index in range(args.tests_per_weight):
                original_data = rng.getrandbits(DATA_WIDTH)

                error_mask = generate_error_mask(
                    error_weight=error_weight,
                    rng=rng,
                    injectable_positions=injectable_positions,
                    test_index=test_index,
                )

                assert original_data.bit_length() <= DATA_WIDTH
                assert error_mask.bit_count() == error_weight
                assert error_mask.bit_length() <= CODEWORD_WIDTH

                writer.writerow(
                    {
                        "test_id": test_id,
                        "error_weight": error_weight,
                        "original_data": f"{original_data:032x}",
                        "error_mask": f"{error_mask:036x}",
                    }
                )

                test_id += 1

    total_tests = len(args.weights) * args.tests_per_weight

    print(f"Generated {total_tests} tests")
    print(f"Error weights: {args.weights}")
    print(f"Injection scope: {args.scope}")
    print(f"Random seed: {args.seed}")
    print(f"Output: {args.output}")


if __name__ == "__main__":
    main()