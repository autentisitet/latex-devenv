<#
.SYNOPSIS
    LaTeX Core Setup for Windows (Scoop + MiKTeX).

.DESCRIPTION
    Installs MiKTeX, SumatraPDF, and Git via Scoop. Configures automatic package installation.

.PARAMETER Mirror
    Use TUNA (Tsinghua University) mirror for faster downloads in China.

.PARAMETER Help
    Show this help message.

.NOTES
    RATIONALE: Why MiKTeX instead of TeX Live for Windows?
    1. ON-DEMAND INSTALLATION: MiKTeX's "Just-in-Time" package management allows a
       minimal initial install (~200MB). Missing packages are downloaded automatically
       during compilation, saving GBs of disk space compared to a Full TeX Live install.
    2. WINDOWS NATIVE: MiKTeX is designed specifically for Windows, offering a robust
       GUI (MiKTeX Console) for easy updates and font management.
    3. FAST SETUP: Installation via Scoop takes minutes, whereas TeX Live's massive
       file extraction can take hours on Windows file systems.

.EXAMPLE
    .\installer.ps1 -Mirror
#>

param (
    [switch]$Mirror = $false,
    [switch]$Help = $false
)

if ($Help) {
    Get-Help $PSCommandPath
    exit
}

# 1. Privilege Check (MiKTeX requires admin rights for system-wide path registration)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "It is recommended to run this script as Administrator to ensure MiKTeX can register environment variables correctly."
}

# 2. Dependency Check (Scoop)
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)){
    Write-Error "Scoop is not installed. Please install it from https://scoop.sh"
    exit 1
}

# 3. Core Component Installation
# - miktex: The LaTeX engine and package manager.
# - sumatrapdf: Lightweight PDF viewer (optional but recommended for Windows).
# - git: Required by some latexmk features and package updates.
scoop bucket add extras version
scoop install miktex sumatrapdf git

# 4. MiKTeX Initialization (Crucial: Run finish to finalize the installation)
Write-Host "Initializing MiKTeX core..." -ForegroundColor Cyan
miktexsetup finish --verbose

# Enable Automatic Package Installation (The "MPM" feature)
# This allows MiKTeX to download missing .sty files silently during build.
initexmf --set-config-value=[MPM]AutoInstall=yes

# 5. Build Tool Installation
# Installing latexmk via MiKTeX's package manager to ensure engine compatibility.
Write-Host "Installing latexmk via mpm..." -ForegroundColor Cyan
if ($Mirror -and -not $env:GITHUB_ACTIONS) {
    Write-Host "Mirror flag detected. Switching MiKTeX to TUNA mirror..." -ForegroundColor Green
    mpm --set-repository=https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/win32/miktex/tm/packages/
}
mpm --install=latexmk

# Refresh Environment Variables
# Ensures that newly installed tools are available in the current session PATH.
$env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# 6. Verification
Write-Host "Verifying installation..." -ForegroundColor Cyan
latexmk -v
Write-Host "MiKTeX setup completed successfully! Packages will auto-install on first use." -ForegroundColor Green