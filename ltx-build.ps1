<#
.SYNOPSIS
    LaTeX Build Engine - Optimized for template library.

.DESCRIPTION
    Uses xelatex for dual-pass compilation, with automatic dependency audit and environment check.

.PARAMETER Template
    Specifies the .tex entry file to compile (e.g., lab-report/main.tex).
    Default value is "main.tex".

.PARAMETER Clean
    Switch parameter. If enabled, cleans all LaTeX cache and intermediate files before compilation.

.PARAMETER Help
    Show this help message.

.EXAMPLE
    .\ltx-build.ps1 -Template ".\template\lab-report_template\main.tex" -Clean
#>

param(
    [Parameter(Position = 0)]
    [string]$Template = "main.tex",

    [Alias("c")]
    [switch]$Clean,


    [Alias("h", "?")]
    [switch]$Help = $false
)

if ($Help) {
    Get-Help $PSCommandPath
    exit
}


# ---------------------------------------------------------
# 1. Visual header (always visible, useful for CI log search)
# ---------------------------------------------------------
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  LtxEngine: Automated Build Pipeline" -ForegroundColor Cyan
Write-Host "  Target: $Template" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Magenta

# Check source file
if (-not (Test-Path $Template)) {
    Write-Error "Error: Template file [$Template] not found"
    exit 1
}

# Check compiler
if (-not (Get-Command xelatex -ErrorAction SilentlyContinue)) {
    Write-Error "xelatex is not ready. Please ensure MiKTeX or TeX Live is added to PATH."
    Write-Host "Recommend installing via Scoop: scoop install miktex" -ForegroundColor Yellow
    exit 1
}

# ---------------------------------------------------------
# 2. Environment audit (dependency check)
# ---------------------------------------------------------
function Get-RequiredPackages {
    param([string]$Path)
    $content = Get-Content $Path -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return @() }

    $regex = '\\(?:usepackage|RequirePackage)(?:\[[^\]]*\])?\s*\{([^}]+)\}'
    $matchList = [regex]::Matches($content, $regex)

    $packages = foreach ($m in $matchList) {
        $m.Groups[1].Value -split ',' | ForEach-Object { $_.Trim() }
    }
    return $packages | Select-Object -Unique
}

$needed = Get-RequiredPackages -Path $Template
$missing = @()

foreach ($pkg in $needed) {
    $found = (kpsewhich "$pkg.sty" 2>$null) -or (kpsewhich "$pkg.cls" 2>$null)
    if (-not $found) { $missing += $pkg }
}

if ($missing.Count -gt 0) {
    Write-Host "[!] Hint: Local packages not found: $($missing -join ', ')" -ForegroundColor Yellow
    Write-Host "    MiKTeX will start Auto-Install mode to silently download them." -ForegroundColor Gray
}

# ---------------------------------------------------------
# 3. Perform cleanup (based on -Clean switch)
# ---------------------------------------------------------
if ($Clean) {
    Write-Host ">>> Performing deep sanitization (25+ extensions)..." -ForegroundColor Cyan

    # Comprehensive list of LaTeX-related auxiliary extensions (25+ types)
    $exts = @(
        # Standard Core Metadata
        "*.aux", "*.log", "*.out", "*.toc", "*.fls", "*.fdb_latexmk", "*.synctex.gz",

        # Bibliography & Citations (BibTeX/Biber)
        "*.bbl", "*.blg", "*.bcf", "*.run.xml", "*.bib.bak", "*.sav",

        # Beamer Slides & Interactive Components
        "*.nav", "*.snm", "*.vrb", "*.pre",

        # Lists, Indexing & Glossary
        "*.lof", "*.lot", "*.idx", "*.ind", "*.ilg", "*.maf", "*.mtc*", "*.nlo", "*.nls",

        # Advanced Package Artifacts (minted, tcolorbox, etc.)
        "*.pyg", "*.thm", "*.atfi", "*.upa", "*.upb"
    )

    $targets = Get-ChildItem -Path "." -Include $exts -Recurse -File -ErrorAction SilentlyContinue

    if ($targets.Count -gt 0) {
        $targets | Remove-Item -Force
        Write-Host "Done! Purged $($targets.Count) auxiliary files across 25+ categories." -ForegroundColor Green
    } else {
        Write-Host "Workspace is already pristine. No debris found." -ForegroundColor Gray
    }
}

# ---------------------------------------------------------
# 4. Core compilation logic
# ---------------------------------------------------------
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($Template)
$targetDir = Split-Path -Path $Template -Parent
if ([string]::IsNullOrEmpty($targetDir)) { $targetDir = "." }
$pureName  = Split-Path -Path $Template -Leaf

function Invoke-Compile {
    param([string]$StepName)
    Write-Host "`n>>> $StepName" -ForegroundColor Cyan

    if (-not $targetDir) { $targetDir = "." }
    Push-Location $targetDir
    try{
        # Perform compilation (interaction=nonstopmode is critical for CI runs)
        & xelatex -interaction=nonstopmode -halt-on-error $pureName

        if ($LASTEXITCODE -ne 0) {
            Write-Host "`n[!] Compilation failed, exit code: $LASTEXITCODE" -ForegroundColor Red
            $log = "$baseName.log"
            if (Test-Path $log) {
                Write-Host "--- Error log summary ($log) ---" -ForegroundColor Red
                Get-Content $log | Select-String -Pattern "!\s+(LaTeX|Package|Class)" | Select-Object -Last 5
            }
            exit 1
        }
    }
    finally{
        Pop-Location
    }

}

Invoke-Compile -StepName "First pass (generate auxiliary indices)"
Invoke-Compile -StepName "Second pass (resolve cross-references/TOC)"


# ---------------------------------------------------------
# 5. Result validation
# ---------------------------------------------------------
$pdfPath = Join-Path $targetDir "$baseName.pdf"

if (Test-Path $pdfPath) {
    Write-Host "`n[✔] Success: $pdfPath has been generated!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n[✘] Failure: Could not generate PDF file." -ForegroundColor Red
    exit 1
}