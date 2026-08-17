# latex-devenv

[English](README.md) | [简体中文](README_zh.md)

[![CI/CD 状态](https://github.com/autentisitet/latex-devenv/actions/workflows/ltx-ci.yml/badge.svg)](https://github.com/autentisitet/latex-devenv/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Debian%2FUbuntu%20%7C%20Podman-blue)](https://github.com/autentisitet/latex-devenv)
[![LaTeX](https://img.shields.io/badge/LaTeX-XeLaTeX-green)](https://tug.org/xetex/)

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
irm get.scoop.sh | iex
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

内置模板：

- `template/lab-report-template/main.tex`
- `template/paper-slides-template/main.tex`
- `template/ppt-template/main.tex`

---

## CI/CD <a id="zh-ci"></a>

当前 GitHub Actions 工作流只使用 apt/Podman 环境：

1. 在 Ubuntu runner 上通过 apt 安装 Podman。
2. 尝试恢复已经构建完成的 Podman apt/TeX Live 镜像缓存。
3. 缓存未命中时，使用 `Containerfile` 构建 Ubuntu 24.04 LaTeX 镜像并保存缓存。
4. 在容器内构建三个模板。
5. 上传 `pdf-assets-apt-podman` PDF 构建产物。

这样本地 Podman 与 CI 使用完全相同的 apt 包列表，不依赖 runner 预装的 LaTeX 环境。

缓存键由 `Containerfile` 和 `installer.sh` 的内容生成。修改基础镜像或 apt 包列表会自动重建缓存；只修改模板、README 或构建脚本不会重新下载整个 TeX Live 环境，因为编译时会将当前仓库挂载到容器的 `/workspace`。首次运行仍然需要完整安装，后续运行会直接加载缓存镜像。

CI 全程不需要 GUI 或人工确认：apt 使用无交互模式，基础镜像使用完整 registry 地址避免 Podman 弹出镜像源选择，每个模板最多构建八分钟，异常时会直接失败而不是等待整个 job 超时。

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
- 许可证：[MIT](LICENSE)

[返回顶部](#latex-devenv) · [English README](README.md)
