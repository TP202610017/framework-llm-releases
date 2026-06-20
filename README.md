<!--
  framework-llm — public releases repository
  Source code is private. Only pre-compiled binaries are distributed here.
-->

<div align="center">

```
  ██╗███████╗███████╗██╗    ██╗
  ██║██╔════╝██╔════╝██║    ██║
  ██║███████╗███████╗██║ █╗ ██║
  ██║╚════██║╚════██║██║███╗██║
  ██║███████║███████║╚███╔███╔╝
  ╚═╝╚══════╝╚══════╝ ╚══╝╚══╝
```

**Energy-aware code analysis and LLM-assisted optimization framework**

![release](https://img.shields.io/github/v/release/TP202610017/framework-llm-releases?color=4a9eff&label=latest)
![platforms](https://img.shields.io/badge/platforms-Linux%20%C2%B7%20macOS%20%C2%B7%20Windows-5c9e6b)
![license](https://img.shields.io/badge/license-research%20use-8e44ad)

</div>

---

> **Binaries only.** This repository distributes pre-compiled, obfuscated binaries.
> The source code lives in a separate private repository and is not published here.

---

## What is `issw`?

`issw` is a command-line tool that helps developers understand and reduce the
computational cost of their codebases. It works in two layers:

**Offline analysis** — no network, no API key required:
- Scans source files across JavaScript, TypeScript, Python, Java, C, C++, and C#
- Scores every file with the **EPU metric** (Energy Points per Use, 1.0–10.0)
- Ranks hotspots by their estimated energy impact
- Runs a sensitivity analysis to verify that rankings are robust to parameter changes
- Measures real runtime, CPU, and RAM via a subprocess probe (Intel RAPL on Linux)

**LLM-assisted optimization** — opt-in, requires your own API key:
- Enriches the refactoring plan with an AI agent
- Proposes concrete, developer-supervised changes
- Never writes without `--apply`; dry-run is the default

---

## Install

### Windows

```powershell
irm https://github.com/TP202610017/framework-llm-releases/releases/latest/download/install.ps1 | iex
```

The installer detects your CPU architecture, downloads the matching binary,
places it at `%LOCALAPPDATA%\Programs\issw\issw.exe`, and adds it to your
user `PATH` automatically.

### macOS / Linux

```bash
curl -fsSL https://github.com/TP202610017/framework-llm-releases/releases/latest/download/install.sh | bash
```

The binary is placed at `~/.local/bin/issw`. If that directory is not yet
on your `PATH`, the installer prints the one-line export to add to your shell rc.

### Manual install

Download the binary for your platform from the
[latest release](https://github.com/TP202610017/framework-llm-releases/releases/latest),
make it executable (`chmod +x issw` on Unix), and move it anywhere on your `PATH`.
Verify your download against the included `checksums.txt`.

---

## Quick start

```bash
# Analyze the current directory
issw analyze -p .

# Rank files by energy impact
issw hotspots -p .

# Full EPU score breakdown per file (CSV)
issw scores -p . -o csv

# LLM-assisted refactoring plan (dry-run, no writes)
issw refactor -p . --agent --dry-run

# Interactive menu (no subcommand needed)
issw
```

---

## Commands

All commands accept `-o / --output` with values `table` (default), `json`, `yaml`, `csv`,
and `-p / --path` to point at any directory. Every command except `refactor --agent` runs
fully offline.

### `analyze` — project overview

```bash
issw analyze -p <dir>
issw a -p .
```

Reports file count, total size, total lines, and language breakdown.
Useful as the entry point before running deeper analysis.

```
EXTENSION   FILES   LINES    BYTES
----------  ------  -------  -------
.py         84      12 430   318 204
.js         47      9 812    241 003
.ts         31      6 540    167 880
.java       15      3 210     88 400
```

---

### `hotspots` — energy ranking

```bash
issw hotspots -p <dir>
issw h -p . -o json
```

Scores every non-test source file with the EPU formula and returns the top-ranked
files. Files with higher EPU scores have a proportionally larger estimated energy
footprint and are the best candidates for refactoring.

```
RANK  FILE                     EPU    CTX     SHARE
----  -----------------------  -----  ------  ------
   1  src/engine/parser.py     8.74   0.91    0.87
   2  lib/core/resolver.js     7.52   0.83    0.74
   3  service/cache/lru.ts     6.91   0.78    0.69
```

> Test files (`*_test.go`, `test_*.py`, `*.test.ts`, `*Test.java`, etc.) are
> automatically excluded from all rankings.

---

### `scores` — per-file EPU breakdown

```bash
issw scores -p <dir>
issw sc -p . -o csv
```

Returns the full EPU breakdown for every scored file: both the context score
(`ctx`) and the sharing penalty (`share`) that compose the final EPU. Useful for
exporting to a spreadsheet or running your own analysis.

---

### `sensitivity` — robustness analysis

```bash
issw sensitivity -p <dir>
issw sens -p . -o json
```

Runs 8 parameter scenarios (weight sweeps, saturation jitter) and computes
Kendall-τ-b and Spearman-ρ correlation against the baseline ranking. A high τ
(≥ 0.90) means the hotspot ranking is stable regardless of exact parameter choices.

```
SCENARIO              KENDALL-T   SPEARMAN-R   TOP5-KEPT
--------------------  ----------  -----------  ---------
w=0.50 (flat)         0.947       0.963        5/5
w=0.70 (ctx-heavy)    0.931       0.952        5/5
saturation +10%       0.958       0.971        5/5
weight jitter ±0.05   0.944       0.961        5/5
```

---

### `measure` — runtime and energy probe

```bash
issw measure --command "python main.py" --args "--input data.csv"
issw measure --command "node server.js" --runs 5
```

Runs the specified command, captures wall time, CPU time, peak RSS, and — on
Linux with Intel RAPL — actual hardware energy in joules. On Windows and macOS
the tool falls back to a parametric energy estimate and labels the output
clearly so you know what was measured vs. modelled.

| Field           | Linux (RAPL)    | Windows / macOS         |
|-----------------|-----------------|-------------------------|
| Wall time       | measured        | measured                |
| CPU time        | measured        | measured                |
| Peak RSS        | measured        | measured                |
| Energy (joules) | measured (HW)   | estimated (parametric)  |

---

### `metrics` — resource estimates

```bash
issw metrics -p <dir> -o yaml
issw m -p .
```

Returns a coarse, deterministic estimate of CPU cores, RAM, and disk usage for
the project. Conservative by design; useful as a quick capacity sanity check.

---

### `recommend` — offline recommendations

```bash
issw recommend -p <dir>
issw r -p . -o json
```

Algorithmic, fully offline recommendations derived from the metrics and hotspot
analysis. No LLM is consulted. Covers file structure, dependency load, and
energy-impact patterns.

---

### `report` — combined report

```bash
issw report -p <dir>
issw rep -p . -o json
```

Bundles `analyze`, `metrics`, `hotspots`, and `recommend` into a single payload.
Useful for CI pipelines or for feeding into downstream tooling.

---

### `refactor` — LLM-assisted optimization

```bash
# Offline plan, dry-run (default — no files are written)
issw refactor -p .
issw fx -p .

# Agent-enriched plan (requires an API key)
issw fx -p . --agent --dry-run

# Apply the plan interactively, with backup
issw fx -p . --apply --backup --max-files 5 --risk-level low

# Apply without confirmation prompt
issw fx -p . --apply --backup --yes
```

| Flag               | Default  | Description                                              |
|--------------------|----------|----------------------------------------------------------|
| `--agent`          | off      | Enable the LLM agent to enrich the refactoring plan      |
| `--dry-run`        | on       | Preview changes without writing any file                 |
| `--apply`          | off      | Write the changes (disables dry-run)                     |
| `--backup`         | off      | Snapshot original files to `.issw-framework/backups/`    |
| `--max-files`      | 3        | Maximum files the plan may touch                         |
| `--risk-level`     | low      | Hint for the agent: `low` / `medium` / `high`            |
| `-y / --yes`       | off      | Skip the interactive confirmation (requires `--apply`)   |
| `-m / --model`     | config   | Override the LLM model for this run                      |
| `--update-gitignore` | off    | Add `.issw-framework/` to `.gitignore` after apply       |

Safety guarantees:
- Without `--apply`, **no file is ever modified** — dry-run is enforced at the write layer, not just the flag parser.
- `--apply` is rejected in non-table output modes to keep automation paths safe.
- With `--agent` but no API key, the tool falls back to a deterministic mock and reports the fallback explicitly.

---

### `calibrate` — correlation with measured energy

```bash
issw calibrate --data measurements.csv --epu-col epu --energy-col joules
```

Reads a paired CSV of EPU scores and measured energy values, fits a linear
model, and reports Pearson-r, R², and a verdict on criterion validity.
Useful for validating the EPU metric against real hardware measurements.

---

### `config show`

```bash
issw config show
issw c show
```

Prints the fully resolved configuration. The API key is redacted; only
`llm_api_key_set: true/false` is shown.

---

### `version`

```bash
issw version
issw v
```

Prints name, version, commit hash, and build date.

---

## Configuration

Settings are resolved in this order (highest priority first):

```
CLI flags  >  environment variables  >  issw.yaml  >  built-in defaults
```

### Environment variables

| Variable              | Description                                             |
|-----------------------|---------------------------------------------------------|
| `ANTHROPIC_API_KEY`   | API key for the Claude provider (default key env)       |
| `ISSW_LLM_PROVIDER`   | LLM provider: `claude`, `openai`, `gemini`, or `mock`   |
| `ISSW_LLM_MODEL`      | Model name override                                     |
| `ISSW_LLM_API_KEY_ENV`| Name of the env var that holds the API key              |

### Config file (`issw.yaml`)

Place this file in your project root or pass `--config path/to/issw.yaml`:

```yaml
llm:
  provider: claude          # mock | claude | openai | gemini
  model: claude-haiku-4-5

refactor:
  dry_run: true
  backup: true
  max_files: 5
  risk_level: low

ui:
  interactive: true
  color: true

scoring:
  saturation_scale: 1.0    # scales all knee/cap values uniformly
```

---

## EPU — Energy Points per Use

EPU is the core metric produced by `issw`. It assigns every source file a score
from **1.0** (minimal footprint) to **10.0** (high energy impact), derived from:

- **Context score** — density of computationally expensive patterns (loops, I/O,
  database calls, regex, cryptographic operations) weighted by file size and depth.
- **Sharing penalty** — degree to which the file is likely called from many places,
  amplifying its energy cost per deployment.

```
EPU = round( 1 + 9 * (0.6 * ctx_score + 0.4 * share_score) , 2)
```

Both components pass through a saturation function that compresses extreme values,
making the metric robust to outlier files and to exact parameter choices (verified
by the `sensitivity` command).

---

## Output formats

Every command supports `-o / --output`:

| Format  | Use case                                 |
|---------|------------------------------------------|
| `table` | Human-readable, terminal-friendly        |
| `json`  | Scripting, CI pipelines                  |
| `yaml`  | Configuration-style tooling              |
| `csv`   | Spreadsheets, R/Python data analysis     |

```bash
issw hotspots -p . -o json | jq '.[] | select(.epu > 7)'
issw scores   -p . -o csv  > scores.csv
issw report   -p . -o yaml > report.yaml
```

---

## Command aliases

| Command       | Alias |
|---------------|-------|
| `analyze`     | `a`   |
| `metrics`     | `m`   |
| `hotspots`    | `h`   |
| `scores`      | `sc`  |
| `sensitivity` | `sens`|
| `benchmark`   | `b`   |
| `recommend`   | `r`   |
| `report`      | `rep` |
| `refactor`    | `fx`  |
| `calibrate`   | `cal` |
| `interactive` | `i`   |
| `config`      | `c`   |
| `version`     | `v`   |

---

## Platforms

Single static binary, no runtime dependencies, no installer required beyond the
one-liner above.

| Platform        | Architecture |
|-----------------|--------------|
| Linux           | amd64, arm64 |
| macOS           | amd64, arm64 |
| Windows         | amd64        |

Each release includes a `checksums.txt` (SHA-256) to verify your download.

---

## License

Binaries are distributed for academic and research use.
© 2026 TP202610017. All rights reserved to the source code.
Redistribution of the binaries is permitted; reverse engineering is not.
