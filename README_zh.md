# latex-devenv

[English](README.md) | [简体中文](README_zh.md)

[![CI/CD 状态](https://github.com/autentisitet/latex-devenv/actions/workflows/ltx-ci.yml/badge.svg?branch=main)](https://github.com/autentisitet/latex-devenv/actions/workflows/ltx-ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Debian%2FUbuntu%20%7C%20Podman-blue)](https://github.com/autentisitet/latex-devenv)
[![LaTeX](https://img.shields.io/badge/LaTeX-XeLaTeX-green)](https://tug.org/xetex/)
[![Version](https://img.shields.io/badge/version-1.0.1-blue.svg)](https://github.com/autentisitet/latex-devenv)

面向本地 LaTeX 工作流的自动化开发环境。Windows 使用 MiKTeX，Bash、Podman 与 CI 使用统一的 Debian/Ubuntu apt TeX Live 环境。

## 目录

- [前置要求](#zh-prerequisites)
- [快速开始](#zh-quick-start)
- [Podman 容器](#zh-podman)
- [安装参数](#zh-installer)
- [构建模板](#zh-build)
- [CI/CD](#zh-ci)
- [Windows CI 超时说明](#zh-windows-timeout)
- [维护与许可证](#zh-maintenance)

---

## 前置要求 <a id="zh-prerequisites"></a>

Windows PowerShell 默认可能禁止执行本地脚本，可在管理员终端中执行：

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

支持的安装环境：

- Windows：PowerShell、Scoop、MiKTeX。
- Debian、Ubuntu、WSL：Bash、apt、TeX Live。
- Podman：使用 Ubuntu 24.04 镜像和相同的 apt 包列表。

MiKTeX 会在首次编译时下载缺少的 LaTeX 包，因此 Windows 环境需要可用的网络连接。

---

## 快速开始 <a id="zh-quick-start"></a>

### Windows

先安装 Scoop：

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-WebRequest https://get.scoop.sh -OutFile install-scoop.ps1
Get-Content .\install-scoop.ps1
.\install-scoop.ps1
```

然后安装 LaTeX 环境：

```powershell
git clone https://github.com/autentisitet/latex-devenv.git
cd latex-devenv
.\installer.ps1
```

管理员级全局安装：

```powershell
.\installer.ps1 -ScoopGlobal -MpmGlobal
```

### Debian / Ubuntu / WSL

```bash
git clone https://github.com/autentisitet/latex-devenv.git
cd latex-devenv
chmod +x installer.sh ltx-build.sh
./installer.sh
```

使用清华 TUNA Ubuntu 镜像：

```bash
./installer.sh --mirror
```

镜像配置仅通过临时 apt sources 文件传入，不会覆盖系统原有的软件源。

---

## Podman 容器 <a id="zh-podman"></a>

容器构建时会运行 `installer.sh`，因此启动后的环境已经包含 CI 使用的全部 apt/LaTeX 包。

```bash
podman compose up -d --build
podman compose exec latex bash
```

不使用 Compose 时：

```bash
podman build -t latex-devenv:apt -f Containerfile .
podman run --rm -it -v "${PWD}:/workspace:Z" latex-devenv:apt bash
```

停止 Compose 服务：

```bash
podman compose down
```

---

## 安装参数 <a id="zh-installer"></a>

| 功能 | PowerShell | Bash | 说明 |
| --- | --- | --- | --- |
| 国内镜像 | `-Mirror` | `--mirror` | 使用 TUNA 镜像 |
| Scoop 全局安装 | `-ScoopGlobal` | 不适用 | 将 Scoop 包安装到全局目录，需要管理员权限 |
| MiKTeX 管理员模式 | `-MpmGlobal` | 不适用 | 使用 MiKTeX 管理员包目录，需要管理员权限 |
| 帮助 | `-Help` | `--help` | 显示帮助信息 |

在 GitHub Actions 中不安装 SumatraPDF，避免引入 CI 不需要的桌面应用。

---

## 构建模板 <a id="zh-build"></a>

Windows：

```powershell
.\ltx-build.ps1 -Template ".\template\lab-report-template\main.tex" -Clean
```

Debian、Ubuntu、WSL 或 Podman：

```bash
./ltx-build.sh "./template/lab-report-template/main.tex" --clean
```

`--clean`/`-Clean` 会在编译前清理 `.aux`、`.log`、`.toc`、`.nav` 等临时文件。构建引擎使用 XeLaTeX 并执行两轮编译，以解析目录和交叉引用。

模板会优先使用 Windows 系统字体；在 Debian、Ubuntu 和 Podman 中，会自动回退到 TeX Gyre、Latin Modern 和 Noto CJK 字体，不需要安装 Arial、Times New Roman 等专有字体。

内置模板：

- `template/lab-report-template/main.tex`
- `template/paper-slides-template/main.tex`
- `template/ppt-template/main.tex`

---

## CI/CD <a id="zh-ci"></a>

当前 GitHub Actions 会同时检查 Windows/MiKTeX 和 Linux/Podman/TeX Live；只有 Podman 生成的 PDF 被视为最终版本：

1. Windows job 恢复或安装用户级 Scoop/MiKTeX，检查宏包并编译三个模板。
2. Linux job 在 Ubuntu runner 上恢复或构建 Podman apt/TeX Live 镜像。
3. Linux job 检查 XeLaTeX、模板宏包以及 Noto、TeX Gyre、Latin Modern 字体。
4. 两个平台分别编译三个模板，任意一边失败都会使 CI 失败。
5. Windows PDF 只用于临时验证，runner 结束后丢弃。
6. 仅上传 Podman 生成的 `pdf-assets-apt-podman` PDF 构建产物。
7. 两个平台都通过后，对 `main` 的 push 构建，将 Podman 生成的 PDF 由专用 `latex-devenv-pdf-bot` GitHub App 自动提交回仓库；PR 和手动运行不会写入仓库。

这样本地 Podman 与 CI 使用完全相同的 apt 包列表，不依赖 runner 预装的 LaTeX 环境。

缓存键由 `Containerfile` 和 `installer.sh` 的内容生成。修改基础镜像或 apt 包列表会自动重建缓存；只修改模板、README 或构建脚本不会重新下载整个 TeX Live 环境，因为编译时会将当前仓库挂载到容器的 `/workspace`。首次运行仍然需要完整安装，后续运行会直接加载缓存镜像。

Podman 镜像缓存只适用于 Linux。Windows 使用独立的 Scoop/MiKTeX 环境：安装器会预装模板直接使用的顶层宏包，同时保留 JIT 自动安装以处理间接依赖和未来新增依赖。以后如果恢复 Windows CI，用户级安装应分别缓存 Scoop 根目录、`%LOCALAPPDATA%\MiKTeX` 和 `%APPDATA%\MiKTeX`；全局安装则缓存对应的 `C:\ProgramData` 目录，不能复用 Linux 镜像归档。Linux 镜像缓存会在环境构建完成后立即保存，因此后续模板编译即使失败，下一次运行仍可复用已经准备好的 LaTeX 环境。

CI 全程不需要 GUI 或人工确认：apt 使用无交互模式；MiKTeX 禁止用户交互并启用宏包自动安装；Windows CI 明确跳过 SumatraPDF 和所有桌面组件。Linux 模板最多构建八分钟，Windows 安装和编译步骤也分别设置了硬超时，异常弹窗不会一直拖到整个 job 超时。

自动生成的 PDF commit 会包含 `[skip ci]`，避免 bot 提交再次触发递归构建。请将 App ID 配置为仓库变量 `PDF_BOT_APP_ID`，将私钥配置为 Actions secret `PDF_BOT_PRIVATE_KEY`。专用 GitHub App 只需要当前仓库的 `Contents: Read and write`，并应作为唯一允许绕过 `main` Ruleset 的自动化身份。

为保护 token，两个构建 job 都只有仓库只读权限，并且 checkout 后不保留 Git 凭据。独立的 PDF 提交 job 也将默认 `GITHUB_TOKEN` 保持为只读，只在 checkout 和 push 时生成限定到当前仓库的短期 GitHub App installation token，并且不执行仓库中的构建脚本。官方 GitHub Actions 均固定到已核验的完整 commit SHA。PR 可以读取 `main` 的可信缓存，但不能写入新缓存或推送生成文件。

Windows job 只 fetch 已核验的 Scoop 安装器 commit，并在执行前比较完整 SHA。apt 会验证 Ubuntu 仓库签名，Scoop 会验证包哈希，MiKTeX 管理宏包元数据和校验信息，配置的 TUNA 镜像使用 HTTPS。剩余供应链边界是 Ubuntu、Scoop、MiKTeX、GitHub 和 Docker Hub 的上游基础设施；两个构建 job 都无法访问长期仓库 token。

---

## Windows CI 超时说明 <a id="zh-windows-timeout"></a>

旧版 `installer.ps1` 的 MiKTeX 初始化条件存在问题：Scoop 安装 MiKTeX 后，`initexmf` 已经出现在 PATH 中，脚本因此跳过 `AutoInstall` 和无交互配置。编译遇到缺包时会等待用户确认，而 CI 无法输入，最终只能等到 job 超时。

目前脚本已调整为：

- 无论 MiKTeX 是否已经初始化，都设置自动安装与禁止用户交互。
- 检查 Scoop、MiKTeX 原生命令的退出码，失败时立即终止。
- 全局安装时使用全局 Scoop 根目录查找 MiKTeX。
- CI 中跳过不需要的 SumatraPDF。
- 使用全局安装参数但没有管理员权限时立即报错。

---

## 维护与许可证 <a id="zh-maintenance"></a>

清理被 `.gitignore` 忽略的构建文件：

```bash
git clean -fdX
```

此命令会永久删除生成的 PDF 和其他忽略文件，执行前请确认不需要保留这些文件。

- 主要编译器：XeLaTeX
- Windows 发行版：MiKTeX
- Debian/Ubuntu/Podman 发行版：TeX Live
- 版本：1.0.1
- 许可证：[MIT](LICENSE)

[返回顶部](#latex-devenv) · [English README](README.md)
