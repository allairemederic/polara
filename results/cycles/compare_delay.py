from collections import defaultdict
from pathlib import Path
from statistics import median, quantiles
import re

ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "median_cycles_4iter_1cycle.txt"
DELAYS = (0, 1, 2, 3, 4, 6, 8, "LDPC")

FILES = {
    "imatmul": "imatmul.txt",
    "iconv2d-output": "iconv2d-output.txt",
    "iconv2d-ifmap": "iconv2d-ifmap.txt",
}


def median_after_iqr(values):
    values = sorted(values)

    if len(values) >= 4:
        q1, _, q3 = quantiles(values, n=4, method="inclusive")
        iqr = q3 - q1
        filtered = [
            x for x in values
            if q1 - 1.5 * iqr <= x <= q3 + 1.5 * iqr
        ]
        if filtered:
            values = filtered

    return median(values)


def read_results(path, benchmark):
    if not path.exists():
        return {}

    samples = defaultdict(list)
    current_key = None

    for line in path.read_text(encoding="utf-8").splitlines():
        if benchmark == "imatmul":
            match = re.search(
                r"S\s*=\s*(\d+)\s+cycles\s*=\s*(\d+)", line
            )
            if match:
                size, cycles = map(int, match.groups())
                samples[(size,)].append(cycles)
            continue

        header = re.search(
            r"F\s*=\s*(\d+)\s+(OUTPUT|IFMAP)\s*=\s*(\d+)", line
        )
        if header:
            filt, axis, size = header.groups()
            expected = (
                "OUTPUT" if benchmark == "iconv2d-output" else "IFMAP"
            )
            current_key = (
                (int(filt), int(size)) if axis == expected else None
            )
            continue

        match = re.search(r"cycles\s*=\s*(\d+)", line)
        if match and current_key is not None:
            samples[current_key].append(int(match.group(1)))

    return {
        key: median_after_iqr(values)
        for key, values in samples.items()
        if values
    }


def result_path(benchmark, delay):
    if delay == "LDPC":
        directory = ROOT / "ldpc-ecc" / "4iter_1cycle"
    elif delay == 0:
        directory = ROOT / "baseline"
    else:
        directory = (
            ROOT / "simulated-latency"
            / "datapath-delay"
            / f"DELAY_{delay}"
        )

    path = directory / FILES[benchmark]

    if benchmark == "iconv2d-output" and delay == 1 and not path.exists():
        alternative = directory / "icond2v-output.txt"
        if alternative.exists():
            return alternative

    return path


def format_cycles(value):
    if value is None:
        return "mesure absente"
    if value == int(value):
        return f"{int(value)} cycles"
    return f"{value:.1f} cycles"


lines = []

for benchmark in FILES:
    results = {
        delay: read_results(result_path(benchmark, delay), benchmark)
        for delay in DELAYS
    }

    keys = sorted(
        set().union(*(data.keys() for data in results.values()))
    )

    lines.append(benchmark)
    lines.append("=" * len(benchmark))

    for key in keys:
        if benchmark == "imatmul":
            parameter = f"S={key[0]}"
        else:
            axis = "OUTPUT" if benchmark == "iconv2d-output" else "IFMAP"
            parameter = f"F={key[0]}, {axis}={key[1]}"

        lines.append("")
        lines.append(parameter)

        for delay in DELAYS:
            value = results[delay].get(key)
            note = ""

            if delay == 2 and value is None:
                before = results[1].get(key)
                after = results[3].get(key)
                if before is not None and after is not None:
                    value = (before + after) / 2
                    note = " (interpolé)"

            label = "LDPC" if delay == "LDPC" else f"DELAY={delay}"
            lines.append(f"{label}: {format_cycles(value)}{note}")

    lines.append("")
    lines.append("")
    
OUTPUT.write_text("\n".join(lines), encoding="utf-8")
print(f"Résultats écrits dans : {OUTPUT}")