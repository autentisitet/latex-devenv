<#
.SYNOPSIS
    LaTeX Core Setup for Windows (Scoop + MiKTeX).

.DESCRIPTION
    Installs MiKTeX, SumatraPDF. Configures automatic package installation. Supports automatic package installation
    and handles environment path registration for both local and global scopes.

.PARAMETER Mirror
    Use TUNA (Tsinghua University) mirror for faster downloads in China.

.PARAMETER Help
    Show this help message.

.PARAMETER MpmGlobal
    Configures MiKTeX (mpm) to operate in Administrative mode.
    - Effect: Installs packages to the system-wide directory (C:\ProgramData\MiKTeX).
    - Requirement: Requires the current process to have Administrator privileges.
    - Context: Highly recommended for CI/CD environments (e.g., GitHub Actions) to ensure
      cross-user access to TeX components.

.PARAMETER ScoopGlobal
    Triggers Scoop's global installation mode.
    - Effect: Appends the '-g' flag to 'scoop install' commands.
    - Result: Packages are installed in 'C:\ProgramData\scoop' instead of the user's
      profile directory.
    - Context: Use this when you want to share the LaTeX binaries across all system accounts.

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
    Installs LaTeX components for the current user using a high-speed Chinese mirror.

.EXAMPLE
    .\installer.ps1 -MpmGlobal -ScoopGlobal
    Performs a full system-wide installation, ideal for setting up a fresh CI runner.
#>

param (
    [switch]$Mirror = $false,
    [switch]$Help = $false,
    [switch]$MpmGlobal = $false,
    [switch]$ScoopGlobal = $false
)

if ($Help) {
    Get-Help $PSCommandPath
    exit
}


# GitHub Actions output grouping helpers
if ($env:GITHUB_ACTIONS -eq 'true') {
    function Githubgroup { Write-Host "::group::$args" }
    function Githubendgroup { Write-Host "::endgroup::" }
} else {
    function Githubgroup { Write-Host "=== $args ===" -ForegroundColor Cyan }
    function Githubendgroup { Write-Host "==================" -ForegroundColor Gray }
}


# 1. Privilege Check (MiKTeX requires admin rights for system-wide path registration)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "It is recommended to run this script as Administrator to ensure MiKTeX can register environment variables correctly."
}


# Utilize PowerShell's array splatting mechanism to pass optional parameters.
# a. Avoid passing empty strings ("") to prevent native commands (such as scoop/mpm) from misinterpreting them as invalid parameters or package names.
# b. Implement dynamic logic of "passing if it exists, disappearing if it doesn't," ensuring the extreme robustness of command-line calls.
$ScoopArgs = @()
if ($ScoopGlobal){ $ScoopArgs += "-g" }

$MpmArgs = @()
if ($MpmGlobal) { $MpmArgs += "-admin" }



# 2. Dependency Check (Scoop)
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)){
    Write-Host "[!] ERROR: Scoop is not detected on your system." -ForegroundColor Red
    Write-Host "This script uses Scoop to manage LaTeX components gracefully."
    Write-Host ""
    Write-Host "To install Scoop, run the following command in PowerShell:" -ForegroundColor White
    Write-Host "irm get.scoop.sh | iex" -ForegroundColor Cyan
    exit 1
}

# 3. Core Component Installation
# - miktex: The LaTeX engine and package manager.
# - sumatrapdf: Lightweight PDF viewer (optional but recommended for Windows).
# - git: Required by some latexmk features and package updates.
# Avoid environment conflicts caused by pre-installed git, aria2, and 7zip on the system
Githubgroup "Installing core dependencies"
$Dependencies = @(
    @{ Cmd = '7z';   Pkg = "7zip" },
    @{ Cmd = "git";  Pkg = "git" },
    @{ Cmd = "aria2c";  Pkg = "aria2" }
)

foreach ($Item in $Dependencies){
    $Command = $Item.Cmd
    $Package = $Item.Pkg
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)){
        Write-Host "$($Package) is not installed. It will be installed by scoop." -ForegroundColor Gray
        try{
            & scoop install @ScoopArgs $Package
        }
        catch{
            Write-Error "The $($Package) installation failed. `
                    Please check your computer environment."
            throw
        }
    }
    else{
        Write-Host "[√] $($Package) has been installed already." -ForegroundColor Green
    }
}
Githubendgroup


Githubgroup "Adding Scoop buckets"
$RequiredBuckets = @("extras", "versions")
foreach ($Bucket in $RequiredBuckets) {
    $result = scoop bucket add $Bucket 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[✓] Bucket '$Bucket' ready" -ForegroundColor Green
    } else {
        # Errors are only displayed when a true failure occurs.
        if ($result -notlike "*already exists*") {
            Write-Host "[!] Failed to add bucket '$Bucket': $result" -ForegroundColor Yellow
        }
    }
}
Githubendgroup


Githubgroup "Installing LaTeX engine (MiKTeX)"
$LtxEngine = @(
    @{ Cmd = 'miktex';  Pkg = 'miktex' },
    @{ Cmd = 'SumatraPDF';  Pkg = 'sumatrapdf' }
)
foreach ($Item in $LtxEngine){
    $Command = $Item.Cmd
    $Package = $Item.Pkg
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)){
        Write-Host "$($Package) is not installed. It will be installed by scoop." -ForegroundColor Gray
        try{
            & scoop install @ScoopArgs $Package
        }
        catch{
            Write-Error "The $($Package) installation failed."
            throw
        }
    }
    else{
        Write-Host "[√] $($Package) has been installed already." -ForegroundColor Green
    }
}
Githubendgroup


# 4. Configuring PATH environment (Crucial for CI/CD)
# RATIONALE:
# a. IMMEDIATE USE: Injected into $env:PATH so the current script can run 'miktexsetup' and 'latexmk'.
# b. STEP PERSISTENCE: Exported to $env:GITHUB_PATH so subsequent CI steps (like ltx-build)
#    inherit these tools without needing to re-run the installer.
Githubgroup "Configuring PATH environment"
Write-Host "Configuring PATH environment..." -ForegroundColor Cyan
$ScoopRoot = scoop config root 2>$null
if (-not $ScoopRoot) { $ScoopRoot = "$env:USERPROFILE\scoop" }

$RequiredPaths = @(
    "$ScoopRoot\shims",
    "$ScoopRoot\apps\miktex\current\miktex\bin\x64"
)
foreach ($Item in $RequiredPaths){
    # Modify the current PowerShell process in memory.
    if ((Test-Path $Item) -and ($env:PATH -notlike "*$Item*")){
        $env:PATH = "$($Item);$($env:PATH)"
        Write-Host "Added to PATH: $($Item)" -ForegroundColor Gray
    }
    else{
        Write-Host "[√] Already in PATH: $($Item)" -ForegroundColor Gray
    }

    # Append the path to the environment variable pipeline file specified by GitHub.
    # `$env:GITHUB_PATH` is a file path, not a PATH string, so `-notlike "*$Item*"` is meaningless.
    # Adding the same path repeatedly has no side effects; GitHub will deduplicat it.
    if ($env:GITHUB_PATH){
        Add-Content -Path $env:GITHUB_PATH -Value $Item
        Write-Host "[→] Persisted to GITHUB_PATH for subsequent steps" -ForegroundColor Magenta
    }
}
Githubendgroup



# 5. Build Tool Installation
    # Installing latexmk via MiKTeX's package manager to ensure engine compatibility.
Githubgroup "Initializing MIKTEX"
    if (!(Get-Command initexmf -ErrorAction SilentlyContinue)){
    Write-Host "MiKTeX core not detected in PATH. Initializing..." -ForegroundColor Yellow
    & miktexsetup finish --verbose @MpmArgs
    # Enable Automatic Package Installation (The "MPM" feature)
    # This allows MiKTeX to download missing .sty files silently during build.
    & initexmf --set-config-value=[MPM]AutoInstall=yes @MpmArgs
    & initexmf --set-config-value=[General]AllowUserInteractions=0 @MpmArgs
    & initexmf --mkmaps --quiet @MpmArgs

    Write-Host "Installing latexmk via mpm..." -ForegroundColor Cyan
    if ($Mirror -and -not $env:GITHUB_ACTIONS) {
        Write-Host "Mirror flag detected. Switching MiKTeX to TUNA mirror..." -ForegroundColor Green
        & mpm @MpmArgs --set-repository=https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/win32/miktex/tm/packages/
    }

    # Abandon explicit installation of ctex to avoid manually applying dependency patches.
    & mpm @MpmArgs --install=latexmk

    # Windows: Fonts are managed uniformly by the system kernel and the registry.
    # As long as the font file is correctly installed (or linked to the system font directory by Scoop), Windows will notify the system in real time via API
    # XeLaTeX can then directly recognize the font by calling directwrite or the system API, without needing to manually refresh the cache.
}
else{
    Write-Host "[√] MiKTeX core is already initialized."
}
Githubendgroup



# 6. Verification
Githubgroup "Verifying installation"
Write-Host "Verifying installation..." -ForegroundColor Cyan
if (Get-Command latexmk -ErrorAction SilentlyContinue) {
    & latexmk -v
    Write-Host "MiKTeX setup completed successfully! Packages will auto-install on first use." -ForegroundColor Green
}
else {
    Write-Warning "MiKTeX initialized, but 'latexmk' is not accessible in this process."
    Write-Warning "Please try: 1. Restart Terminal  2. Run 'scoop install miktex' again if missing."
}
Githubendgroup