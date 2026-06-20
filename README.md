# framework-llm (`issw`)

**Energy-aware code analysis & optimization framework.** A command-line tool that
detects computational-resource hotspots in software projects (JavaScript, TypeScript,
Java, Python, C/C++, C#) and proposes LLM-assisted, developer-supervised refactorings.

> ⚠️ This repository distributes **pre-compiled, obfuscated binaries only**.
> The source code lives in a **separate, private** repository and is **not published here**.

## Install (one-liner)

**Windows (PowerShell):**
```powershell
irm https://github.com/TP202610017/framework-llm-releases/releases/latest/download/install.ps1 | iex
```

**macOS / Linux (bash):**
```bash
curl -fsSL https://github.com/TP202610017/framework-llm-releases/releases/latest/download/install.sh | bash
```

Or grab the binary for your platform from the
[latest release](https://github.com/TP202610017/framework-llm-releases/releases/latest)
and put `issw` on your `PATH`.

## Usage

```text
issw analyze            Analyze the current project (files, languages, energy estimate)
issw hotspots           Rank source files by energy impact (EPU 1.0–10.0)
issw scores  -o csv     Per-file EPU breakdown (ctx/share components)
issw sensitivity        Parameter-robustness of the ranking (Kendall-τ, Spearman)
issw measure --command  Measure real runtime/CPU/RAM (and energy via Intel RAPL on Linux)
issw optimize           LLM-assisted refactoring suggestions (requires your own API key)
issw --help             Full command list
```

The LLM-assisted optimization is **opt-in** and needs an API key you configure yourself
(`issw config set llm.provider ...`); offline analysis works with no key and no network.

## Platforms

Single static binary, no dependencies. Linux · macOS · Windows (amd64 / arm64).
Each release ships a `checksums.txt` to verify your download.

## License

Binaries distributed for academic / research use. © 2026 TP202610017. All rights reserved
to the source. Redistribution of the binaries is permitted; reverse engineering is not.
