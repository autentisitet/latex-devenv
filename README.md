# latex-devenv

**A cross-platform automation suite for on-premises LaTeX workflows.**

This suite optimizes LaTeX environment deployment by abstracting the complexities of multi-gigabyte distributions. It implements an orchestration layer that leverages MiKTeX's dynamic JIT (Just-in-Time) package management for storage-constrained environments and TeX Live's monolithic stability for high-concurrency CI/CD pipelines.

---

## 📑 Table of Contents

* [⚠️ Prerequisite & Notices](#prerequisites)
* [🔍 Architecture & Design Decisions](#architecture-decisions)
* [🛠 Quick Start & Deployment](#setup-guide)
* [🏗 The Enhanced Build Engine](#build-engine)
* [🎨 Template Gallery](#templates)
* [📖 Technical Reference](#technical-reference)
* [🧹 Git Hygiene](#git-hygiene)
* [🚀 CI/CD Integration](#cicd)
* [📄 Metadata & License](#metadata)

---

## ⚠️ Prerequisite & Notices <a id="prerequisites"></a>

> **CAUTION: Execution Policy**
>
> `Windows PowerShell` restricts script execution by default. To authorize the local toolchain, execute the following in an Admin session once:
>
> ``` Powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```
>
> **WARNING: Network Dependency & Mirroring**
>
> The Windows micro-kernel installer utilizes `MiKTeX JIT`. This drastically reduces initial storage footprint (~200MB), but **requires an active internet connection** during the first compilation of any new template to fetch missing `.sty` packages.
>
> * **Users in China**: It is highly recommended to use the `-Mirror` flag during installation to route downloads through the TUNA mirror for optimal speed.

---

## 🔍 Architecture & Design Decisions <a id="architecture-decisions"></a>

* Hybrid Toolchain Orchestration – The suite abstracts distribution-specific differences, implementing MiKTeX JIT logic on Windows for storage efficiency and TeX Live on Unix/WSL for environment consistency.

* Deterministic Build Pipeline – Implements an atomic state machine that ensures idempotency. The multi-pass compilation logic guarantees that auxiliary data (`TOC`,  `TikZ`) is correctly synchronized without manual intervention.

* Self-Healing Pre-flight Audit – Instead of failing mid-compilation, the engine performs a static analysis of \usepackage declarations, cross-referencing them against the local kpsewhich database to preemptively flag and resolve missing assets.

* Unified Engine Interface – Standardized on `XeLaTeX` to leverage native UTF-8 handling and system-level font mapping (OpenType/TrueType), eliminating the complexity of legacy TeX font encoding.

* Workspace Decoupling – Implements a strict separation between source logic (`.tex`, `.sty`) and transient metadata (`.aux`, `.log`), enforced via industrial-standard `.gitignore` patterns.

**Decision: Single-Engine Architecture**
By standardizing exclusively on XeLaTeX, the suite eliminates "font-not-found" regressions across different operating systems while providing out-of-the-box UTF-8 support for CJK templates.

---

## 🛠 Quick Start & Deployment <a id="setup-guide"></a>

### 1. Environment Bootstrapping

**Ad-hoc Execution (Standalone)**
Suitable for rapid environment setup without local repository persistence.

* Windows (PowerShell Admin):

```Powershell
# For international users
irm https://raw.githubusercontent.com/autentisitet/latex-devenv/main/installer.ps1 | iex
# For users in China (Enables TUNA mirror)
$script = irm https://raw.githubusercontent.com/autentisitet/latex-devenv/main/installer.ps1
Invoke-Command -ScriptBlock ([scriptblock]::Create($script)) -ArgumentList "-Mirror"
```

* Linux / macOS / WSL (Bash):

```Bash
# For international users
curl -sSL https://raw.githubusercontent.com/autentisitet/latex-devenv/main/installer.sh | bash
# For users in China (Enables TUNA mirror)
curl -sSL https://raw.githubusercontent.com/autentisitet/latex-devenv/main/installer.sh | bash -s -- --mirror
```

**Repository Integration (Development)**
Recommended for full access to internal build engines and template structures.

* Windows (PowerShell):

```Powershell
git clone https://github.com/autentisitet/latex-devenv.git
cd latex-devenv
powershell -ExecutionPolicy Bypass -File .\installer.ps1
```

* Linux / macOS / WSL (Bash):

```Bash
git clone https://github.com/autentisitet/latex-devenv.git
cd latex-devenv
chmod +x *.sh
./installer.sh
```

### 2. Atomic Build Execution

The build engine provides a standardized interface for both PowerShell and Bash.

* Windows

```powershell
powershell -ExecutionPolicy Bypass -File .\ltx-build.ps1 -Template "./template/lab-report_template/main.tex" -Clean
```

* Linux / macOS / WSL

```bash
chmod +x ltx-build.sh && ./ltx-build.sh "./template/lab-report_template/main.tex" -c
```

---

## 🏗 The Enhanced Build Engine <a id="build-engine"></a>

`ltx-build` is an automated state machine that orchestrates the LaTeX compilation lifecycle.

**Logic Parameters:**

| Function | PowerShell (Windows) | Bash (Linux/macOS) | Description |
| :--- | :--- | :--- | :--- |
| **Entry Point** | `-Template` or `Pos 0` | `$1` | Defines the entry point (Defaults to `main.tex`) |
| **Cleanup** | `-Clean` or `-c` | `-c` or `--clean` | Purges 20+ transient auxiliary extensions before building |
| **-Help** | `-Help` or `-h`or`-?` | `--help` or `-h` | Displays the help documentation |

---

## 🎨 Template Gallery <a id="templates"></a>

| Template | Engine | Optimization Focus | Core Component |
| --- | --- | --- | --- |
| **Lab Report** | XeLaTeX | Structural Logic | `report-style.sty` (tcolorbox) |
| **PPT Modern** | XeLaTeX | Vector Graphics | TikZ Overlay Headers |
| **Paper Slides** | XeLaTeX | Minimalist Layout | Beamer-based White-space Optimization |

---

## 📖 Technical Reference: LaTeX Compilers <a id="technical-reference"></a>

This suite prioritizes **XeLaTeX** for modern Unicode (UTF-8) handling and system-level font mapping.

| **Compiler** | **Logical Tier** | **Use Case** |
| --- | --- | --- |
| **XeLaTeX** | **The Modern Standard**. Native support for Unicode (UTF-8) and system fonts (e.g., Arial, Microsoft YaHei). | **Default choice**. Essential for CJK (Chinese/Japanese/Korean) and modern typography. |
| **pdfLaTeX** | **The Legacy Workhorse**. Extremely fast and stable, but limited to older font formats. | Standard English-only submissions with no special font requirements. |
| **LuaLaTeX** | **The Powerhouse**. Includes an embedded Lua engine for ultimate extensibility and complex layouts. | Advanced projects requiring dynamic scripting or extremely complex math. |
| **LaTeX** | **The Heritage Engine**. The original engine that outputs `.dvi` files instead of PDF. | Historical projects only; largely deprecated for modern workflows. |

> **Note**: The build scripts (`ltx-build.ps1`/`ltx-build.sh`) default to **XeLaTeX** to ensure cross-platform font consistency.

---

## 🧹 Git Hygiene <a id="git-hygiene"></a>

This repository enforces a strict "Source-Only" policy. Transient "build debris" is filtered via `.gitignore`.

* **Auxiliary Data**: `.aux`, `.fdb_latexmk`, `.fls`, `.synctex.gz` (Metadata).

* **Beamer State**: `.nav`, `.snm`, `.vrb` (Slide-specific artifacts).

* **Log Files**: `.log`, `.blg`, `.ilg` (Forensic diagnostics).

### Maintenance Commands

#### 1. To purge existing tracked debris (Safety First)

If you have already committed auxiliary files, run this to remove them from the Git index without deleting your local files:

```bash
git rm -r --cached .
git add .
git commit -m "chore: apply strict gitignore hygiene"
```

#### 2. To hard-reset your workspace (Physical Cleanup)

To physically delete all files listed in `.gitignore` and restore a "pristine" source state:

```bash
# ⚠️ WARNING: This permanently deletes all ignored files (including generated PDFs)
git clean -fdX
```

---

## 🚀 CI/CD Integration <a id="cicd"></a>

LtxEngine features a robust dual-stack CI/CD pipeline via GitHub Actions. Every push or tag triggers an atomic build process on both Ubuntu and Windows Server environments to ensure 100% template compatibility.

**Key Infrastructure Features:**

* Multi-Platform Audit: Validates installer.sh on Linux (TeX Live) and installer.ps1 on Windows (MiKTeX) simultaneously.

* Intelligent Caching: Implements multi-layer caching for TeX Live packages and MiKTeX JIT data.

* Automated Release: When a version tag (e.g., v1.0.0) is pushed, the engine automatically aggregates compiled PDFs from all platforms and creates a GitHub Release.

---

## 📄 Metadata & License <a id="metadata"></a>

* **Author**: [@autentisitet](https://github.com/autentisitet)
* **Compiler**: XeLaTeX (Primary Engine)
* **Distribution**: MiKTeX(Windows) / TeX Live(Unix)
* **Version**: 0.1.0 (pre-release)
* **License**: [MIT](LICENSE)
