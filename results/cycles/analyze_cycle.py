#!/usr/bin/env python3

import csv
import re
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

# ============================================================
# CONFIGURATION
# ============================================================

RESULTS_DIR = Path(__file__).resolve().parent
ANALYSIS_DIR = RESULTS_DIR / "analysis"
TABLES_DIR = ANALYSIS_DIR / "tables"
FIGURES_DIR = ANALYSIS_DIR / "figures"

BASELINE_NAME = "baseline"

BENCHMARK_FILES = {
    "imatmul": "imatmul.txt",
    "iconv2d-output": "iconv2d-output.txt",
    "iconv2d-ifmap": "iconv2d-ifmap.txt",
}

# ============================================================
# PARSING - IMATMUL
# ============================================================

def parse_imatmul(filename):

    results = []

    pattern = re.compile(
        r"S=\s*(\d+)\s+"
        r"cycles=\s*(\d+)\s+"
        r"verify=\s*(\d+)"
    )

    with open(filename, "r") as f:
        for line in f:
            match = pattern.search(line)

            if not match:
                continue

            results.append({
                "size"  : int(match.group(1)),
                "cycles": int(match.group(2)),
                "verify": int(match.group(3)),
            })

    return results

# ============================================================
# PARSING - ICONV2D
# ============================================================

def parse_iconv2d(filename):

    results = []

    header_pattern = re.compile(
        r"F=\s*(\d+)\s+(IFMAP|OUTPUT)=\s*(\d+)"
    )

    result_pattern = re.compile(
        r"iter\s+(\d+):\s+"
        r"cycles=\s*(\d+)\s+"
        r"verify=\s*(\d+)"
    )

    current_filter = None
    current_parameter = None
    current_size = None

    with open(filename, "r") as f:
        for line in f:

            header = header_pattern.search(line)

            if header:
                current_filter = int(header.group(1))
                current_parameter = header.group(2)
                current_size = int(header.group(3))
                continue

            result = result_pattern.search(line)

            if result and current_filter is not None:

                results.append({
                    "filter": current_filter,
                    "parameter": current_parameter,
                    "size": current_size,
                    "iteration": int(result.group(1)),
                    "cycles": int(result.group(2)),
                    "verify": int(result.group(3)),
                })

    return results

# ============================================================
# FIND RESULT FILES
# ============================================================

def find_result_files(config_dir, benchmark):

    filename = BENCHMARK_FILES[benchmark]

    return sorted(config_dir.rglob(filename))

# ============================================================
# LOAD BENCHMARK
# ============================================================

def load_benchmark(config_dir, benchmark):

    files = find_result_files(config_dir, benchmark)
    results = []

    for filename in files:

        if benchmark == "imatmul":
            parsed = parse_imatmul(filename)

        elif benchmark in ("iconv2d-output", "iconv2d-ifmap"):
            parsed = parse_iconv2d(filename)

        else:
            raise ValueError(f"Unknown benchmark: {benchmark}")

        results.extend(parsed)

    return results, files

# ============================================================
# INVALID RESULT FILTERING (verify > 0)
# ============================================================

def remove_invalid(samples):

    return [
        sample
        for sample in samples
        if sample["verify"] == 0 and sample["cycles"] > 0
    ]


# ============================================================
# IQR FILTER (IQR = Q3 - Q1)
# ============================================================

def remove_outliers_iqr(samples):

    if len(samples) < 4:
        return samples.copy()

    cycles = np.array(
        [sample["cycles"] for sample in samples],
        dtype=float
    )

    q1 = np.percentile(cycles, 25)
    q3 = np.percentile(cycles, 75)

    iqr = q3 - q1

    lower = q1 - 1.5 * iqr
    upper = q3 + 1.5 * iqr

    return [
        sample
        for sample in samples
        if lower <= sample["cycles"] <= upper
    ]


# ============================================================
# STATISTICS
# ============================================================

def compute_statistics(samples):

    if not samples:
        return {
            "median": None,
            "mean": None,
            "std": None,
        }

    cycles = np.array(
        [sample["cycles"] for sample in samples],
        dtype=float
    )

    return {
        "median": float(np.median(cycles)),
        "mean": float(np.mean(cycles)),
        "std": float(np.std(cycles)),
    }

# ============================================================
# GROUP IMATMUL
# ============================================================

def group_imatmul(results):
    groups = {}

    for sample in results:
        key = sample["size"]
        groups.setdefault(key, []).append(sample)

    return groups

# ============================================================
# GROUP ICONV2D
# ============================================================

def group_iconv2d(results):
    groups = {}

    for sample in results:

        key = (
            sample["filter"],
            sample["parameter"],
            sample["size"],
        )

        groups.setdefault(key, []).append(sample)

    return groups


# ============================================================
# ANALYZE ONE BENCHMARK
# ============================================================

def analyze_benchmark(results, benchmark):

    if benchmark == "imatmul":
        groups = group_imatmul(results)
    else:
        groups = group_iconv2d(results)

    analysis = {}

    for key, raw_samples in groups.items():

        valid_samples = remove_invalid(raw_samples)
        filtered_samples = remove_outliers_iqr(valid_samples)

        stats = compute_statistics(filtered_samples)

        analysis[key] = {
            "raw": len(raw_samples),
            "valid": len(valid_samples),
            "after_iqr": len(filtered_samples),
            "median": stats["median"],
            "mean": stats["mean"],
            "std": stats["std"],
        }

    return analysis


# ============================================================
# DISPLAY HELPERS
# ============================================================

def format_number(value):
    if value is None:
        return "N/A"

    return f"{value:.2f}"

def print_statistics(config, benchmark, analysis):

    print()
    print("=" * 90)
    print(f"{config.upper()} - {benchmark}")
    print("=" * 90)

    if not analysis:
        print("No results found.")
        return

    if benchmark == "imatmul":

        print(
            f"{'Size':>8}"
            f"{'Raw':>8}"
            f"{'Valid':>10}"
            f"{'IQR':>10}"
            f"{'Median':>15}"
            f"{'Mean':>15}"
            f"{'Std dev':>15}"
        )

        print("-" * 90)

        for size in sorted(analysis):

            stats = analysis[size]

            print(
                f"{size:>8}"
                f"{stats['raw']:>8}"
                f"{stats['valid']:>10}"
                f"{stats['after_iqr']:>10}"
                f"{format_number(stats['median']):>15}"
                f"{format_number(stats['mean']):>15}"
                f"{format_number(stats['std']):>15}"
            )

    else:

        print(
            f"{'F':>5}"
            f"{'Parameter':>12}"
            f"{'Size':>8}"
            f"{'Raw':>8}"
            f"{'Valid':>10}"
            f"{'IQR':>10}"
            f"{'Median':>15}"
            f"{'Mean':>15}"
            f"{'Std dev':>15}"
        )

        print("-" * 100)

        for key in sorted(analysis):

            F, parameter, size = key
            stats = analysis[key]

            print(
                f"{F:>5}"
                f"{parameter:>12}"
                f"{size:>8}"
                f"{stats['raw']:>8}"
                f"{stats['valid']:>10}"
                f"{stats['after_iqr']:>10}"
                f"{format_number(stats['median']):>15}"
                f"{format_number(stats['mean']):>15}"
                f"{format_number(stats['std']):>15}"
            )

# ============================================================
# WRITE STATISTICS CSV
# ============================================================

def write_statistics_csv(config, benchmark, analysis):

    filename = TABLES_DIR / f"{config}_{benchmark}.csv"

    with open(filename, "w", newline="") as f:

        writer = csv.writer(f)

        if benchmark == "imatmul":

            writer.writerow([
                "matrix_size",
                "raw_results",
                "valid_results",
                "after_iqr",
                "median_cycles",
                "mean_cycles",
                "std_cycles",
            ])

            for size in sorted(analysis):

                stats = analysis[size]

                writer.writerow([
                    size,
                    stats["raw"],
                    stats["valid"],
                    stats["after_iqr"],
                    stats["median"],
                    stats["mean"],
                    stats["std"],
                ])

        else:

            writer.writerow([
                "filter_size",
                "parameter",
                "matrix_size",
                "raw_results",
                "valid_results",
                "after_iqr",
                "median_cycles",
                "mean_cycles",
                "std_cycles",
            ])

            for key in sorted(analysis):

                F, parameter, size = key
                stats = analysis[key]

                writer.writerow([
                    F,
                    parameter,
                    size,
                    stats["raw"],
                    stats["valid"],
                    stats["after_iqr"],
                    stats["median"],
                    stats["mean"],
                    stats["std"],
                ])

    print(f"Saved: {filename}")


# ============================================================
# BASELINE COMPARISON (variation %)
# ============================================================

def compare_with_baseline(baseline, test):

    comparison = {}

    common_keys = sorted(set(baseline.keys()) & set(test.keys()))

    for key in common_keys:

        baseline_median = baseline[key]["median"]
        test_median = test[key]["median"]

        if (
            baseline_median is None
            or test_median is None
            or baseline_median == 0
        ):
            variation = None

        else:
            variation = ((test_median - baseline_median) / baseline_median * 100.0)

        comparison[key] = {
            "baseline_median": baseline_median,
            "test_median": test_median,
            "variation": variation,
        }

    return comparison


# ============================================================
# PRINT COMPARISON
# ============================================================

def print_comparison(benchmark, test_config, comparison):

    print()
    print("=" * 90)
    print(
        f"BASELINE vs {test_config.upper()} - {benchmark}"
    )
    print("=" * 90)

    if not comparison:
        print("No common results available.")
        return

    if benchmark == "imatmul":

        print(
            f"{'Size':>8}"
            f"{'Baseline':>18}"
            f"{test_config:>22}"
            f"{'Variation (%)':>18}"
        )

        print("-" * 70)

        for size in sorted(comparison):

            row = comparison[size]

            print(
                f"{size:>8}"
                f"{format_number(row['baseline_median']):>18}"
                f"{format_number(row['test_median']):>22}"
                f"{format_number(row['variation']):>18}"
            )

    else:

        print(
            f"{'F':>5}"
            f"{'Parameter':>12}"
            f"{'Size':>8}"
            f"{'Baseline':>18}"
            f"{test_config:>22}"
            f"{'Variation (%)':>18}"
        )

        print("-" * 90)

        for key in sorted(comparison):

            F, parameter, size = key
            row = comparison[key]

            print(
                f"{F:>5}"
                f"{parameter:>12}"
                f"{size:>8}"
                f"{format_number(row['baseline_median']):>18}"
                f"{format_number(row['test_median']):>22}"
                f"{format_number(row['variation']):>18}"
            )


# ============================================================
# WRITE COMPARISON CSV
# ============================================================

def write_comparison_csv(benchmark, test_config,comparison):

    filename = TABLES_DIR / (f"compare_baseline_vs_{test_config}_{benchmark}.csv")

    with open(filename, "w", newline="") as f:

        writer = csv.writer(f)

        if benchmark == "imatmul":

            writer.writerow([
                "matrix_size",
                "baseline_median_cycles",
                f"{test_config}_median_cycles",
                "variation_percent",
            ])

            for size in sorted(comparison):

                row = comparison[size]

                writer.writerow([
                    size,
                    row["baseline_median"],
                    row["test_median"],
                    row["variation"],
                ])

        else:

            writer.writerow([
                "filter_size",
                "parameter",
                "matrix_size",
                "baseline_median_cycles",
                f"{test_config}_median_cycles",
                "variation_percent",
            ])

            for key in sorted(comparison):

                F, parameter, size = key
                row = comparison[key]

                writer.writerow([
                    F,
                    parameter,
                    size,
                    row["baseline_median"],
                    row["test_median"],
                    row["variation"],
                ])

    print(f"Saved: {filename}")


# ============================================================
# PLOT - IMATMUL MEDIAN CYCLES
# ============================================================

def plot_imatmul_medians(all_results):

    plt.figure(figsize=(8, 5))

    plotted = False

    for config, benchmarks in all_results.items():

        analysis = benchmarks.get("imatmul", {})

        x = []
        y = []

        for size in sorted(analysis):

            median = analysis[size]["median"]

            if median is not None:
                x.append(size)
                y.append(median)

        if x:
            plt.plot(x, y, marker="o", label=config)
            plotted = True

    if not plotted:
        plt.close()
        return

    plt.xlabel("Matrix size")
    plt.ylabel("Median cycles")
    plt.title("imatmul - Median Execution Cycles")
    plt.grid(True, alpha=0.3)
    plt.legend()
    plt.tight_layout()

    filename = FIGURES_DIR / "imatmul_median_cycles.png"

    plt.savefig(filename, dpi=300)
    plt.close()

    print(f"Saved: {filename}")


# ============================================================
# PLOT - IMATMUL OVERHEAD
# ============================================================

def plot_imatmul_overhead(all_results):

    if BASELINE_NAME not in all_results:
        return

    baseline = all_results[BASELINE_NAME].get("imatmul", {})

    plt.figure(figsize=(8, 5))

    plotted = False

    for config, benchmarks in all_results.items():

        if config == BASELINE_NAME:
            continue

        test = benchmarks.get("imatmul", {})

        comparison = compare_with_baseline(baseline, test)

        x = []
        y = []

        for size in sorted(comparison):

            variation = comparison[size]["variation"]

            if variation is not None:
                x.append(size)
                y.append(variation)

        if x:
            plt.plot(x, y, marker="o", label=config)
            plotted = True

    if not plotted:
        plt.close()
        return

    plt.axhline(0, linewidth=1)

    plt.xlabel("Matrix size")
    plt.ylabel("Variation from baseline (%)")
    plt.title("imatmul - Performance Overhead")
    plt.grid(True, alpha=0.3)
    plt.legend()
    plt.tight_layout()

    filename = FIGURES_DIR / "imatmul_overhead.png"

    plt.savefig(filename, dpi=300)
    plt.close()

    print(f"Saved: {filename}")


# ============================================================
# PLOT - ICONV2D MEDIAN CYCLES
# ============================================================

def plot_iconv2d_medians(all_results, benchmark):

    filters = set()

    for config, benchmarks in all_results.items():

        analysis = benchmarks.get(benchmark, {})

        for key in analysis:
            F, _, _ = key
            filters.add(F)

    for F in sorted(filters):

        plt.figure(figsize=(8, 5))

        plotted = False
        parameter_name = None

        for config, benchmarks in all_results.items():

            analysis = benchmarks.get(benchmark, {})

            x = []
            y = []

            for key in sorted(analysis):

                filter_size, parameter, size = key

                if filter_size != F:
                    continue

                median = analysis[key]["median"]

                if median is None:
                    continue

                parameter_name = parameter

                x.append(size)
                y.append(median)

            if x:
                plt.plot(x, y, marker="o", label=config)
                plotted = True

        if not plotted:
            plt.close()
            continue

        plt.xlabel(
            f"{parameter_name} size"
            if parameter_name
            else "Matrix size"
        )

        plt.ylabel("Median cycles")

        plt.title(f"{benchmark} - F={F} - Median Execution Cycles")

        plt.grid(True, alpha=0.3)
        plt.legend()
        plt.tight_layout()

        filename = FIGURES_DIR / (f"{benchmark}_F{F}_median_cycles.png")

        plt.savefig(filename, dpi=300)
        plt.close()

        print(f"Saved: {filename}")


# ============================================================
# PLOT - ICONV2D OVERHEAD
# ============================================================

def plot_iconv2d_overhead(all_results, benchmark):

    if BASELINE_NAME not in all_results:
        return

    baseline = all_results[BASELINE_NAME].get(benchmark, {})

    filters = set()

    for key in baseline:
        F, _, _ = key
        filters.add(F)

    for F in sorted(filters):

        plt.figure(figsize=(8, 5))

        plotted = False
        parameter_name = None

        for config, benchmarks in all_results.items():

            if config == BASELINE_NAME:
                continue

            test = benchmarks.get(benchmark, {})

            comparison = compare_with_baseline(baseline, test)

            x = []
            y = []

            for key in sorted(comparison):

                filter_size, parameter, size = key

                if filter_size != F:
                    continue

                variation = comparison[key]["variation"]

                if variation is None:
                    continue

                parameter_name = parameter

                x.append(size)
                y.append(variation)

            if x:
                plt.plot(x, y, marker="o", label=config)
                plotted = True

        if not plotted:
            plt.close()
            continue

        plt.axhline(0, linewidth=1)

        plt.xlabel(
            f"{parameter_name} size"
            if parameter_name
            else "Matrix size"
        )

        plt.ylabel("Variation from baseline (%)")

        plt.title(f"{benchmark} - F={F} - Performance Overhead")

        plt.grid(True, alpha=0.3)
        plt.legend()
        plt.tight_layout()

        filename = FIGURES_DIR / (f"{benchmark}_F{F}_overhead.png")

        plt.savefig(filename, dpi=300)
        plt.close()

        print(f"Saved: {filename}")


# ============================================================
# FIND CONFIGURATIONS
# ============================================================

def find_configurations():

    configurations = []

    for path in RESULTS_DIR.iterdir():

        if not path.is_dir():
            continue

        if path.name == ANALYSIS_DIR.name:
            continue

        configurations.append(path)

    return sorted(configurations)


# ============================================================
# MAIN
# ============================================================

def main():

    TABLES_DIR.mkdir(parents=True, exist_ok=True)
    FIGURES_DIR.mkdir(parents=True, exist_ok=True)

    configurations = find_configurations()

    if not configurations:
        print("No result configurations found.")
        sys.exit(1)

    print("Configurations found:")

    for config in configurations:
        print(f"  - {config.name}")

    # Analyze every configuration

    all_results = {}

    for config_dir in configurations:

        config_name = config_dir.name

        all_results[config_name] = {}

        for benchmark in BENCHMARK_FILES:

            raw_results, files = load_benchmark(config_dir, benchmark)

            if not files:
                continue

            print()
            print(f"Reading {config_name}/{benchmark}")

            for filename in files:
                print(f"  {filename}")

            analysis = analyze_benchmark(raw_results, benchmark)

            all_results[config_name][benchmark] = analysis

            print_statistics(config_name, benchmark, analysis)

            write_statistics_csv(config_name, benchmark, analysis)

    # Baseline comparisons

    if BASELINE_NAME not in all_results:

        print()
        print(f"Warning: '{BASELINE_NAME}' configuration " "not found.")

    else:

        for config_name in all_results:

            if config_name == BASELINE_NAME:
                continue

            for benchmark in BENCHMARK_FILES:

                baseline = all_results[BASELINE_NAME].get(benchmark)

                test = all_results[config_name].get(benchmark)

                if baseline is None or test is None:
                    continue

                comparison = compare_with_baseline(baseline, test)

                print_comparison(benchmark, config_name, comparison)

                write_comparison_csv(benchmark, config_name, comparison)

    # Graphs

    plot_imatmul_medians(all_results)
    plot_imatmul_overhead(all_results)

    plot_iconv2d_medians(all_results, "iconv2d_ifmap")
    plot_iconv2d_overhead(all_results, "iconv2d_ifmap")

    plot_iconv2d_medians(all_results, "iconv2d_output")
    plot_iconv2d_overhead(all_results, "iconv2d_output")

    print()
    print("=" * 60)
    print("ANALYSIS COMPLETED")
    print("=" * 60)
    print(f"Tables  : {TABLES_DIR}")
    print(f"Figures : {FIGURES_DIR}")


if __name__ == "__main__":
    main()