#!/usr/bin/env python3

import argparse
import csv
from collections import defaultdict
from pathlib import Path

import matplotlib.pyplot as plt


REQUIRED_COLUMNS = {
    "test_id",
    "error_weight",
    "recovered",
    "error_detected",
    "decode_cycles",
}


def read_results(path: Path) -> dict[int, dict[str, int]]:
    results = {}

    with path.open("r", newline="", encoding="utf-8") as input_file:
        reader = csv.DictReader(input_file)

        if reader.fieldnames is None:
            raise ValueError(f"{path} does not contain a CSV header.")

        missing_columns = REQUIRED_COLUMNS - set(reader.fieldnames)
        if missing_columns:
            raise ValueError(
                f"{path} is missing columns: "
                f"{sorted(missing_columns)}"
            )

        for row in reader:
            test_id = int(row["test_id"])

            if test_id in results:
                raise ValueError(
                    f"Duplicate test_id {test_id} in {path}"
                )

            results[test_id] = {
                "test_id": test_id,
                "error_weight": int(row["error_weight"]),
                "recovered": int(row["recovered"]),
                "error_detected": int(row["error_detected"]),
                "decode_cycles": int(row["decode_cycles"]),
            }

    return results


def validate_matching_tests(
    secded_results: dict[int, dict[str, int]],
    ldpc_results: dict[int, dict[str, int]],
) -> None:
    secded_ids = set(secded_results)
    ldpc_ids = set(ldpc_results)

    if secded_ids != ldpc_ids:
        only_secded = sorted(secded_ids - ldpc_ids)
        only_ldpc = sorted(ldpc_ids - secded_ids)

        raise ValueError(
            "SECDED and LDPC results do not contain the same test IDs.\n"
            f"Only in SECDED: {only_secded[:10]}\n"
            f"Only in LDPC: {only_ldpc[:10]}"
        )

    for test_id in secded_ids:
        secded_weight = secded_results[test_id]["error_weight"]
        ldpc_weight = ldpc_results[test_id]["error_weight"]

        if secded_weight != ldpc_weight:
            raise ValueError(
                f"Different error weights for test {test_id}: "
                f"SECDED={secded_weight}, LDPC={ldpc_weight}"
            )


def aggregate_results(
    ecc_name: str,
    results: dict[int, dict[str, int]],
) -> list[dict]:
    by_weight = defaultdict(list)

    for result in results.values():
        by_weight[result["error_weight"]].append(result)

    summary = []

    for weight in sorted(by_weight):
        tests = by_weight[weight]

        total = len(tests)
        recovered = sum(test["recovered"] for test in tests)
        detected = sum(test["error_detected"] for test in tests)

        detected_not_recovered = sum(
            test["error_detected"] and not test["recovered"]
            for test in tests
        )

        undetected = sum(
            not test["error_detected"] and not test["recovered"]
            for test in tests
        )

        decode_cycles = [
            test["decode_cycles"]
            for test in tests
        ]

        recovery_rate = 100.0 * recovered / total
        detection_rate = 100.0 * detected / total
        average_decode_cycles = sum(decode_cycles) / total

        summary.append(
            {
                "ecc": ecc_name,
                "error_weight": weight,
                "tests": total,
                "recovered": recovered,
                "detected": detected,
                "detected_not_recovered": detected_not_recovered,
                "undetected": undetected,
                "recovery_rate_percent": recovery_rate,
                "detection_rate_percent": detection_rate,
                "average_decode_cycles": average_decode_cycles,
                "minimum_decode_cycles": min(decode_cycles),
                "maximum_decode_cycles": max(decode_cycles),
            }
        )

    return summary


def write_summary(path: Path, summaries: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

    fieldnames = [
        "ecc",
        "error_weight",
        "tests",
        "recovered",
        "detected",
        "detected_not_recovered",
        "undetected",
        "recovery_rate_percent",
        "detection_rate_percent",
        "average_decode_cycles",
        "minimum_decode_cycles",
        "maximum_decode_cycles",
    ]

    with path.open("w", newline="", encoding="utf-8") as output_file:
        writer = csv.DictWriter(output_file, fieldnames=fieldnames)
        writer.writeheader()

        for row in summaries:
            formatted_row = dict(row)
            formatted_row["recovery_rate_percent"] = (
                f"{row['recovery_rate_percent']:.6f}"
            )
            formatted_row["detection_rate_percent"] = (
                f"{row['detection_rate_percent']:.6f}"
            )
            formatted_row["average_decode_cycles"] = (
                f"{row['average_decode_cycles']:.3f}"
            )
            writer.writerow(formatted_row)


def plot_recovery_rate(
    output_path: Path,
    summaries: list[dict],
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    for ecc_name in ("SECDED", "LDPC"):
        rows = [
            row for row in summaries
            if row["ecc"] == ecc_name
        ]

        weights = [row["error_weight"] for row in rows]
        rates = [row["recovery_rate_percent"] for row in rows]

        plt.plot(
            weights,
            rates,
            marker="o",
            linewidth=2,
            label=ecc_name,
        )

    plt.xlabel("Number of injected bit errors")
    plt.ylabel("Recovery rate (%)")
    plt.title("SECDED vs LDPC error recovery")
    plt.ylim(-2, 102)
    plt.grid(True, alpha=0.3)
    plt.legend()
    plt.tight_layout()
    plt.savefig(output_path, dpi=300)
    plt.close()


def print_summary(summaries: list[dict]) -> None:
    print(
        f"{'ECC':<8} "
        f"{'Weight':>6} "
        f"{'Tests':>8} "
        f"{'Recovered':>10} "
        f"{'Rate':>10} "
        f"{'Undetected':>11} "
        f"{'Avg cycles':>11}"
    )

    for row in summaries:
        print(
            f"{row['ecc']:<8} "
            f"{row['error_weight']:>6} "
            f"{row['tests']:>8} "
            f"{row['recovered']:>10} "
            f"{row['recovery_rate_percent']:>9.3f}% "
            f"{row['undetected']:>11} "
            f"{row['average_decode_cycles']:>11.3f}"
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Analyze SECDED and LDPC comparison results."
    )

    parser.add_argument(
        "--secded",
        type=Path,
        default=Path("results/secded_results.csv"),
        help="SECDED simulation results.",
    )

    parser.add_argument(
        "--ldpc",
        type=Path,
        default=Path("results/ldpc_results.csv"),
        help="LDPC simulation results.",
    )

    parser.add_argument(
        "--summary",
        type=Path,
        default=Path("results/comparison.csv"),
        help="Aggregated comparison CSV.",
    )

    parser.add_argument(
        "--plot",
        type=Path,
        default=Path("results/recovery_rate.png"),
        help="Recovery-rate plot.",
    )

    args = parser.parse_args()

    secded_results = read_results(args.secded)
    ldpc_results = read_results(args.ldpc)

    validate_matching_tests(secded_results, ldpc_results)

    summaries = (
        aggregate_results("SECDED", secded_results)
        + aggregate_results("LDPC", ldpc_results)
    )

    write_summary(args.summary, summaries)
    plot_recovery_rate(args.plot, summaries)
    print_summary(summaries)

    print()
    print(f"Comparison CSV: {args.summary}")
    print(f"Recovery plot: {args.plot}")


if __name__ == "__main__":
    main()