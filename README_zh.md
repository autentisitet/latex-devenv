# latex-devenv

[English](README.md) | [简体中文](README_zh.md)

[![CI/CD 状态](https://github.com/autentisitet/latex-devenv/actions/workflows/ltx-ci.yml/badge.svg?branch=main)](https://github.com/autentisitet/latex-devenv/actions/workflows/ltx-ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Debian%2FUbuntu%20%7C%20Podman-blue)](https://github.com/autentisitet/latex-devenv)
[![LaTeX](https://img.shields.io/badge/LaTeX-XeLaTeX-green)](https://tug.org/xetex/)
[![Version](https://img.shields.io/badge/version-1.0.2-blue.svg)](https://github.com/autentisitet/latex-devenv)

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

容器构建时会运行 installer.sh，启动后的环境包含与 CI 相同的 Ubuntu apt/TeX Live 依赖。

### 使用 Compose（推荐）

```bash
podman compose up -d --build
podman compose exec latex bash
```

PDF 始终由容器内的 XeLaTeX 编译。宿主机只把 template 目录挂载到容器的 /workspace/template，用于提供源文件并接收生成的 PDF；构建脚本和 LaTeX 环境都来自镜像。

停止服务：

```bash
podman compose down
```

如果还要删除 Compose 创建的孤立容器：

```bash
podman compose down --remove-orphans
```

```bash
podman compose images
```

确认镜像 ID 后删除：

```bash
podman image rm <image-id>
```

### 不使用 Compose

Linux、macOS 或 WSL：

```bash
podman build -t latex-devenv:apt -f Containerfile .
podman run --rm -it --mount type=bind,source="$PWD/template",target=/workspace/template --workdir /workspace latex-devenv:apt bash -lc "bash ./ltx-build.sh template/lab-report-template/main.tex --clean"
```

Windows PowerShell：

```powershell
podman build -t latex-devenv:apt -f Containerfile .
podman run --rm -it --mount type=bind,source="$($PWD.Path)\template",target=/workspace/template --workdir /workspace latex-devenv:apt bash -lc "bash ./ltx-build.sh template/lab-report-template/main.tex --clean"
```

### 清理容器、镜像和构建缓存

使用 podman run 时，--rm 会在容器退出后自动删除容器。若之前启动过未自动删除的容器，可先查看：

```bash
podman ps -a
```

删除指定容器：

```bash
podman rm -f <container-name-or-id>
```

删除这个项目的独立镜像：

```bash
podman image rm latex-devenv:apt
```

查看构建缓存占用：

```bash
podman system df
```

清理未使用的构建缓存：

```bash
podman system prune --build
```

确认不再需要未使用的镜像、容器和网络后，再执行更彻底的清理：

```bash
podman system prune
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

当前 GitHub Actions 会并行检查 Windows/MiKTeX 和 Linux/Podman/TeX Live；两者使用不同的工具链和缓存目录，因此保留为两个独立 job，而不是强行合并成一个包含大量条件分支的 matrix job。只有 Podman 生成的 PDF 被视为最终版本：

1. Windows job 恢复或安装用户级 Scoop/MiKTeX，检查宏包并编译三个模板。
2. Linux job 在 Ubuntu runner 上恢复或构建 Podman apt/TeX Live 镜像。
3. Linux job 检查 XeLaTeX、模板宏包以及 Noto、TeX Gyre、Latin Modern 字体。
4. 两个平台分别编译三个模板，任意一边失败都会使 CI 失败。
5. Windows PDF 只用于临时验证，runner 结束后丢弃。
6. 仅上传 Podman 生成的 `pdf-assets-apt-podman` PDF 构建产物。
7. 两个平台都通过后，对 `main` 的 push 构建，将 Podman 生成的 PDF 由专用 `latex-devenv-pdf-bot` GitHub App 自动提交回仓库；PR 和手动运行不会写入仓库。

这样本地 Podman 与 CI 使用完全相同的 apt 包列表，不依赖 runner 预装的 LaTeX 环境。

缓存键同时计算 Containerfile 和 installer.sh，并包含可手动递增的缓存代际标记。修改基础镜像、apt 包列表或缓存代际会自动重建镜像；缓存还提供按 Linux runner 匹配的前缀回退。若缓存归档无法被 Podman 加载，CI 会自动重新构建。只修改模板、README 或构建脚本不会重新下载整个 TeX Live 环境，因为 CI 只把宿主机的 template 目录挂载到容器的 /workspace/template，构建脚本来自镜像。

Podman 镜像缓存只适用于 Linux。Windows CI 使用独立的 Scoop/MiKTeX 环境，并缓存用户级 Scoop、LOCALAPPDATA/MiKTeX 和 APPDATA/MiKTeX。两套缓存不能互相复用。MiKTeX 会预装模板直接使用的顶层宏包，同时保留 JIT 自动安装以处理间接依赖和未来新增依赖。

CI 的运行约束：

- apt 使用无交互模式；MiKTeX 禁止用户交互并启用宏包自动安装。
- Windows CI 跳过 SumatraPDF 和所有桌面组件。
- Linux 模板构建、Windows 安装和 Windows 编译都有独立硬超时。
- 自动生成的 PDF commit 带有 [skip ci]，不会触发递归构建。

PDF 提交需要两个仓库配置：

- 仓库变量：PDF_BOT_APP_ID
- Actions secret：PDF_BOT_PRIVATE_KEY

专用 GitHub App 只需要当前仓库的 Contents: Read and write 权限，并应作为唯一允许绕过 main Ruleset 的自动化身份。

安全边界：

- 两个构建 job 只有仓库只读权限，checkout 后不保留 Git 凭据。
- PDF 提交 job 默认使用只读 GITHUB_TOKEN，只在 checkout 和 push 时生成限定到当前仓库的短期 GitHub App token。
- PDF 提交 job 不执行仓库中的构建脚本。
- 官方 GitHub Actions 固定到已核验的完整 commit SHA。
- PR 可以读取 main 的可信缓存，但不能写入新缓存或推送文件。
- Windows job 会校验固定的 Scoop 安装器提交；apt、Scoop 和 MiKTeX 分别校验各自的包或元数据。
- TUNA 镜像使用 HTTPS。剩余供应链边界是 Ubuntu、Scoop、MiKTeX、GitHub 和 Docker Hub 的上游基础设施。

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
- 版本：1.0.2
- 许可证：[MIT](LICENSE)

[返回顶部](#latex-devenv) · [English README](README.md)
