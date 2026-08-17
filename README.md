# latex-devenv

[English](README.md) | [简体中文](README_zh.md)

[![CI/CD Status](https://github.com/autentisitet/latex-devenv/actions/workflows/ltx-ci.yml/badge.svg?branch=main)](https://github.com/autentisitet/latex-devenv/actions/workflows/ltx-ci.yml)
[![GitHub release](https://img.shields.io/github/v/release/autentisitet/latex-devenv?include_prereleases)](https://github.com/autentisitet/latex-devenv/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Debian%2FUbuntu%20%7C%20Podman-blue)](https://github.com/autentisitet/latex-devenv)
[![LaTeX](https://img.shields.io/badge/LaTeX-XeLaTeX-green)](https://tug.org/xetex/)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/autentisitet/latex-devenv)

**A cross-platform automation suite for on-premises LaTeX workflows.**

This suite optimizes LaTeX environment deployment by abstracting the complexities of multi-gigabyte distributions. It implements an orchestration layer that leverages MiKTeX's dynamic JIT (Just-in-Time) package management for storage-constrained environments and TeX Live's monolithic stability for high-concurrency CI/CD pipelines.

---

## 📑 Table of Contents

* [⚠️ Prerequisite & Notices](#prerequisites)
* [🔍 Architecture & Design Decisions](#architecture-decisions)
* [🛠 Quick Start & Deployment](#setup-guide)
* [🛠 Installer Configuration](#installer-config)
* [🏗 The Enhanced Build Engine](#build-engine)
* [🎨 Template Gallery](#templates)
* [📖 Technical Reference](#technical-reference)
* [🛠 Maintenance & Troubleshooting](#maintenance)
* [🚀 CI/CD Integration](#cicd)
* [📄 Metadata & License](#metadata)

---

## ⚠️ Prerequisite & Notices <a id="prerequisites"></a>

> [!CAUTION]
> ### Execution Policy
> `Windows PowerShell` restricts script execution by default. To authorize the local toolchain, execute the following in an Admin session once:
>
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```

> [!WARNING]
> ### Network Dependency & Mirroring
> The Windows micro-kernel installer utilizes `MiKTeX JIT`. This drastically reduces initial storage footprint (~200MB), but **requires an active internet connection** during the first compilation of any new template to fetch missing `.sty` packages.
>
> * **Users in China**: It is highly recommended to use the `-Mirror` flag during installation to route downloads through the TUNA mirror for optimal speed.

---

## 🔍 Architecture & Design Decisions <a id="architecture-decisions"></a>

* **Focused Toolchain Orchestration** – PowerShell retains MiKTeX support on Windows, while Bash and CI use one Debian/Ubuntu apt-based TeX Live environment.

* **Deterministic Build Pipeline** – Implements an idempotent atomic state machine. The multi-pass compilation logic guarantees that auxiliary data (`TOC`, `TikZ`, `Cross-references`) is correctly synchronized without manual intervention.

* **Self-Healing Pre-flight Audit** – Instead of failing mid-compilation, the engine performs a static analysis of `\usepackage` declarations, cross-referencing them against the local `kpsewhich` database to preemptively flag and resolve missing assets.

* **Non-Intrusive Mirror Injection** - Implements stateless repository routing. Mirror sources are injected via temporary scoped configurations, accelerating downloads without modifying global system software sources.

* **Standardized Engine Interface** – Standardized on `XeLaTeX` to leverage native UTF-8 handling and system-level font mapping (OpenType/TrueType), eliminating "font-not-found" regressions across different OS environments.

* **Deep Workspace Decoupling** – Implements a strict separation between source logic (`.tex`, `.sty`) and transient metadata (`.aux`, `.log`), enforced via industrial-standard `.gitignore` patterns.

* **Container Parity** – Local Podman and GitHub Actions both build from the same Ubuntu `Containerfile`, so they receive the same apt packages.

* **CI/CD Log Optimization** – Implements smart log grouping (`::group::` / `::endgroup::`) with nested hierarchy support. Critical phases (dependency audit, compilation passes, result validation) are automatically foldable in GitHub Actions, dramatically reducing CI log noise while preserving full debugging capability.

**Decision: Single-Engine Architecture**
By standardizing exclusively on XeLaTeX, the suite eliminates "font-not-found" regressions across different operating systems while providing out-of-the-box UTF-8 support for CJK templates.

---

## 🛠 Quick Start & Deployment <a id="setup-guide"></a>

### 1. Environment Bootstrapping

**Ad-hoc Execution (Standalone)**
Suitable for rapid environment setup without local repository persistence.

* Windows (PowerShell Admin):

```Powershell
# Download first so the script can be inspected before execution.
Invoke-WebRequest https://raw.githubusercontent.com/autentisitet/latex-devenv/main/installer.ps1 -OutFile installer.ps1
Get-Content .\installer.ps1
.\installer.ps1

# For users in China (enables the TUNA mirror)
.\installer.ps1 -Mirror
```

* Debian / Ubuntu / WSL (Bash):

```Bash
# Download first so the script can be inspected before execution.
curl --fail --location --output installer.sh \
  https://raw.githubusercontent.com/autentisitet/latex-devenv/main/installer.sh
less installer.sh
bash installer.sh

# For users in China (enables the TUNA mirror)
bash installer.sh --mirror
```

> [!IMPORTANT]
> ### 🌐 Mirror Strategy & System Integrity
> To ensure high-speed downloads in restricted networks without compromising system stability, the suite implements a **Non-Intrusive Mirror Injection** logic. We use **Scoped Injection** instead of permanently overwriting global configurations:

| Environment | Mirror Source | Injection Mechanism | Restoration / Persistence |
| :--- | :--- | :--- | :--- |
| **Ubuntu / WSL** | TUNA (Tsinghua) | Temporary `/tmp/tuna_sources.list` via `-o Dir::Etc::SourceList` | **Atomic**: Temporary config is deleted immediately after execution. |

**Repository Integration (Development)**
Recommended for full access to internal build engines and template structures.

* Windows (PowerShell):

```powershell
git clone https://github.com/autentisitet/latex-devenv.git
cd latex-devenv
powershell -ExecutionPolicy Bypass -File .\installer.ps1
```

* Debian / Ubuntu / WSL (Bash):

```Bash
git clone https://github.com/autentisitet/latex-devenv.git
cd latex-devenv
chmod +x installer.sh
./installer.sh
```

* Podman (same apt environment as CI):

```bash
podman compose up -d --build
podman compose exec latex bash
```

### 2. Atomic Build Execution

The build engine provides a standardized interface for both PowerShell and Bash.

* Windows

```powershell
cd latex-devenv
powershell -ExecutionPolicy Bypass -File .\ltx-build.ps1 -Template ".\template\lab-report-template\main.tex" -Clean
```

* Debian / Ubuntu / WSL

```bash
cd latex-devenv
chmod +x ltx-build.sh
./ltx-build.sh "./template/lab-report-template/main.tex" --clean
```

---

## 🛠 Installer Configuration <a id="installer-config"></a>

The `installer` script supports the following parameters for environment customization:

| Parameter | PowerShell | Bash | Description |
| :--- | :--- | :--- | :--- |
| **Mirror** | `-Mirror` | `--mirror` | Use TUNA (Tsinghua University) mirror for faster downloads in China |
| **Global Mode (Scoop)** | `-ScoopGlobal` | N/A | Install packages system-wide (Windows only) |
| **Global Mode (MiKTeX)** | `-MpmGlobal` | N/A | Configure MiKTeX in administrative mode (Windows only) |
| **Help** | `-Help` | `--help` | Display help information |

**Usage Examples:**

```powershell
# Windows: Install with TUNA mirror and global mode
.\installer.ps1 -Mirror -ScoopGlobal -MpmGlobal
```

---

## 🏗 The Enhanced Build Engine <a id="build-engine"></a>

`ltx-build` is an automated state machine that orchestrates the LaTeX compilation lifecycle.

**Logic Parameters:**

| Function | PowerShell (Windows) | Bash (Debian/Ubuntu/WSL) | Description |
| :--- | :--- | :--- | :--- |
| **Entry Point** | `-Template` or `Pos 0` | `$1` | Defines the entry point (Defaults to `main.tex`) |
| **Cleanup** | `-Clean` or `-c` | `-c` or `--clean` | Purges 20+ transient auxiliary extensions before building |
| **-Help** | `-Help` or `-h`or`-?` | `--help` or `-h` | Displays the help documentation |

**Intelligent Workspace Sanitization:**

The --clean flag triggers a deep-clean state machine that purges 25+ types of transient LaTeX debris, ensuring a deterministic "pristine" state for every build. Targeted assets include:

* **Core Metadata:** `.aux,` `.log`, `.out`, `.toc`, `.fls`, `.fdb_latexmk`, `.synctex.gz`

* **Bibliographies:** `.bbl`, `.blg`, `.bcf`, `.run.xml` (BibTeX/Biber support)

* **Interactive Elements:** `.nav`, `.snm`, `.vrb` (Full Beamer support)

* **Indexing & Lists:** `.idx`, `.ind`, `.ilg`, `.lof`, `.lot`, `.maf`, `.mtc*`

* **Dynamic Graphics & Logic:** `.tikz`, `.pgf`, `.pyg` (Minted cache), `.thm`
>
> [!TIP]
> **Why deep clean?** LaTeX auxiliary files can sometimes become "stale" (e.g., after changing section titles or moving files), leading to persistent compilation errors. The --clean flag eliminates these ghost regressions.

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
> Templates prefer Windows system fonts when available and automatically fall back to TeX Gyre, Latin Modern, or Noto CJK fonts in Debian/Ubuntu and Podman environments.

---

## 🛠 Maintenance & Troubleshooting <a id="maintenance"></a>

### Workspace Hygiene

The suite utilizes a strict `.gitignore` to filter out 20+ types of transient LaTeX debris. To keep your repository pristine:

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

> [!TIP]
> Regularly running git clean -fdX is recommended before major CI/CD deployments to ensure no stale auxiliary data interferes with the build engine.

---

## 🚀 CI/CD Integration <a id="cicd"></a>

LtxEngine uses a single apt-based Podman environment in GitHub Actions. The CI image is built from `Containerfile`, then all templates are compiled inside that image.

**Key Infrastructure Features:**

* **Environment parity:** CI and local Podman use the same Ubuntu apt packages.

* **Container isolation:** Builds do not depend on LaTeX packages installed on the runner host.

* **Reusable Podman image cache:** CI saves the completed apt/TeX Live image immediately after its dependency smoke test and restores it on later runs. The environment remains reusable even if a subsequent template build fails. The cache key is derived from `Containerfile` and `installer.sh`, so package or image changes automatically trigger a clean rebuild.

* **Non-interactive execution:** apt uses non-interactive mode, the base image uses a fully qualified registry name, and each template build has an eight-minute timeout. No CI step requires a GUI or manual confirmation.

* **Artifact and repository output:** Generated PDFs are uploaded as the `pdf-assets-apt-podman` artifact. On pushes to `main`, changed template PDFs are also committed back by `github-actions[bot]`; PRs and manually dispatched runs never write to the repository.

The first CI run still downloads and installs the complete TeX Live environment. Later runs load the cached image unless `Containerfile` or `installer.sh` changes. Template and build-script changes do not invalidate the environment cache because the repository is mounted into `/workspace` when compilation starts.

The PDF update commit contains `[skip ci]` to prevent recursive workflow runs. Repository settings must allow GitHub Actions to write repository contents, and branch protection rules must permit `github-actions[bot]` to push to `main`.

For token safety, the build job has read-only repository access and checks out code without persisting credentials. Only the separate PDF commit job receives `contents: write`, and it never executes repository build scripts. Official GitHub Actions are pinned to verified full commit SHAs. Pull requests may restore the trusted `main` image cache but cannot publish new cache entries or push generated files.

The Podman image cache is Linux-specific. Windows uses a separate Scoop/MiKTeX installation: the installer preloads the templates' top-level packages and keeps automatic package installation enabled for transitive or future dependencies. A future Windows CI job should cache the applicable Scoop root plus `%LOCALAPPDATA%\MiKTeX` and `%APPDATA%\MiKTeX` for a user installation, or the corresponding `C:\ProgramData` directories for a global installation. It must not restore the Linux image archive. Linux CI also performs a smoke test for the required TeX packages and the Noto, TeX Gyre, and Latin Modern font families before compiling templates.

---

## 📄 Metadata & License <a id="metadata"></a>

* **Author**: [@autentisitet](https://github.com/autentisitet)
* **Compiler**: XeLaTeX (Primary Engine)
* **Distribution**: MiKTeX (Windows) / TeX Live (Debian, Ubuntu, WSL and Podman)
* **Version**: 1.0.0
* **License**: [MIT](LICENSE)
