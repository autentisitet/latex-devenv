#!/usr/bin/env bash

# ltx-build.sh - High-Performance LaTeX Build Engine (Linux/macOS)
# Optimized for LaTeX template repositories and CI/CD pipelines.

# Default values
TEMPLATE="main.tex"
CLEAN=0

# Usage information
show_help() {
    printf "Usage: %s [TEMPLATE_PATH] [-c|--clean]\n" "$0"
    printf "Example: %s lab-report/main.tex --clean\n" "$0"
    exit 0
}

# Parse Arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -c|--clean) CLEAN=1; shift ;;
        -h|--help)  show_help ;;
        -*)
            printf "\033[0;31m[!] Unknown option: %s\033[0m\n" "$1" >&2
            exit 1 ;;
        *)
            TEMPLATE="$1"; shift ;;
    esac
done

# 1. Environment & Path Audit
[ ! -f "$TEMPLATE" ] && printf "\033[0;31m[!] Error: Template [%s] not found\033[0m\n" "$TEMPLATE" >&2 && exit 1
command -v xelatex >/dev/null 2>&1 || { printf "\033[0;31m[!] Error: xelatex (XeTeX) not found in PATH\033[0m\n" >&2; exit 1; }

printf "\033[0;35m========================================\033[0m\n"
printf "\033[0;36m  LtxEngine: Linux Build Pipeline\033[0m\n"
printf "\033[0;33m  Target: %s\033[0m\n" "$TEMPLATE"
printf "\033[0;35m========================================\033[0m\n"

# 2. Dependency Audit (Scanning \usepackage and \RequirePackage)
if command -v kpsewhich >/dev/null 2>&1; then
    missing=$(grep -Eho '\\(usepackage|RequirePackage)(\[[^]]*\])?\{[^}]+\}' "$TEMPLATE" 2>/dev/null | \
              sed -E 's/\\(usepackage|RequirePackage)(\[[^]]*\])?\{([^}]+)\}/\3/' | \
              tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sort -u | \
              while read -r pkg; do
                  [ -z "$pkg" ] && continue
                  kpsewhich "${pkg}.sty" >/dev/null 2>&1 || kpsewhich "${pkg}.cls" >/dev/null 2>&1 || echo "$pkg"
              done | tr '\n' ' ')
    [ -n "$missing" ] && printf "\033[1;33m[?] Missing assets: %s (Will attempt JIT install)\033[0m\n" "$missing"
fi

# 3. Atomic Clean
if [ "$CLEAN" -eq 1 ]; then
    printf "\033[0;36m>>> Performing deep sanitization (25+ extensions)...\033[0m\n"

    # Define all extensions in a regex-friendly format
    # This covers: Core, Bib, Beamer, Indexing, and Package-specific debris
    EXT_PATTERN="aux|log|out|toc|fls|fdb_latexmk|synctex\.gz|bbl|blg|bcf|run\.xml|bib\.bak|sav|nav|snm|vrb|pre|lof|lot|idx|ind|ilg|maf|mtc.*|nlo|nls|pyg|thm|atfi|upa|upb"

    # Optimization: Use -E (Extended Regex) for cleaner syntax
    # -type f: Only files, avoid touching directories
    # -maxdepth 3: Balanced depth to clean sub-folders without scanning the entire disk
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS (BSD find)
        find -E . -maxdepth 3 -type f -regex ".*\.($EXT_PATTERN)" -exec rm -f {} +
    else
        # Linux (GNU find)
        find . -maxdepth 3 -type f -regextype posix-extended -regex ".*\.($EXT_PATTERN)" -delete
    fi

    printf "\033[0;32mCleanup completed successfully.\033[0m\n"
fi

# 4. Multi-Pass Compilation State Machine
# Interaction=nonstopmode is critical for CI to prevent hanging
for pass in 1 2; do
    printf "\n\033[0;36m>>> Pass %d: Compilation in progress...\033[0m\n" "$pass"

    # We allow xelatex to stream output to stdout for real-time CI monitoring
    # but use -halt-on-error for immediate failure
    if ! xelatex -interaction=nonstopmode -halt-on-error "$TEMPLATE"; then
        printf "\033[0;31m\n[!] Fatal: Compilation failed at Pass %d\033[0m\n" "$pass" >&2
        exit 1
    fi
done

# 5. Success Validation
base_name=$(basename "${TEMPLATE%.tex}")
pdf="${base_name}.pdf"

if [ -f "$pdf" ]; then
    printf "\n\033[0;32m[✔] Build Success: %s\033[0m\n" "$pdf"

    # Metadata Audit (if pdfinfo is available)
    if command -v pdfinfo >/dev/null 2>&1; then
        pages=$(pdfinfo "$pdf" | grep -i "Pages:" | awk '{print $2}')
        printf "\033[0;90m    -> Generated %s page(s)\033[0m\n" "$pages"
    fi
else
    printf "\033[0;31m\n[✘] Error: Build finished but %s was not found.\033[0m\n" "$pdf" >&2
    exit 1
fi

exit 0