<#
.SYNOPSIS
    LaTeX Core Setup for Windows (Scoop + MiKTeX).

.DESCRIPTION
    Installs MiKTeX, SumatraPDF. Configures automatic package installation.

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
# Avoid environment conflicts caused by pre-installed git, aria2, and 7zip on the system
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
            scoop install $Package
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
            scoop install $Package
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

# 4. MiKTeX Initialization (Crucial: Run finish to finalize the installation)
# In CI environments, newly installed apps might not be in PATH immediately.
# Inject the MiKTeX bin path directly into the session.
Write-Host "Checking MiKTeX core environment..." -ForegroundColor Cyan
$RequiredPaths = @(
    "$env:USERPROFILE\scoop\shims",
    "$env:USERPROFILE\scoop\apps\miktex\current\miktex\bin\x64"
)
foreach ($Item in $RequiredPaths){
    if ((Test-Path $Item) -and ($env:PATH -notlike "*$Item*")){
        $env:PATH = "$Item;$env:PATH"
        Write-Host "Added to PATH: $($Item)" -ForegroundColor Gray
    }
    else{
        Write-Host "[√] Already in PATH: $($Item)" -ForegroundColor Gray
    }
}



# 5. Build Tool Installation
    # Installing latexmk via MiKTeX's package manager to ensure engine compatibility.
if (!(Get-Command initexmf -ErrorAction SilentlyContinue)){
    Write-Host "MiKTeX core not detected in PATH. Initializing..." -ForegroundColor Yellow
    & miktexsetup finish --verbose
    # Enable Automatic Package Installation (The "MPM" feature)
    # This allows MiKTeX to download missing .sty files silently during build.
    & initexmf --set-config-value=[MPM]AutoInstall=yes
    & initexmf --set-config-value=[General]AllowUserInteractions=0
    & initexmf --mkmaps --quiet

    Write-Host "Installing latexmk via mpm..." -ForegroundColor Cyan
    if ($Mirror -and -not $env:GITHUB_ACTIONS) {
        Write-Host "Mirror flag detected. Switching MiKTeX to TUNA mirror..." -ForegroundColor Green
        & mpm --set-repository=https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/win32/miktex/tm/packages/
    }
    & mpm --install=latexmk
}
else{
    Write-Host "[√] MiKTeX core is already initialized."
}




# 6. Verification
Write-Host "Verifying installation..." -ForegroundColor Cyan
if (Get-Command latexmk -ErrorAction SilentlyContinue) {
    & latexmk -v
    Write-Host "MiKTeX setup completed successfully! Packages will auto-install on first use." -ForegroundColor Green
}
else {
    Write-Warning "MiKTeX initialized, but 'latexmk' is not accessible in this process."
    Write-Warning "Please try: 1. Restart Terminal  2. Run 'scoop install miktex' again if missing."
}