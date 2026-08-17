#!/usr/bin/env bash

# Install the Debian/Ubuntu apt-based LaTeX environment used by both local
# machines and the Podman container.
set -euo pipefail

show_help() {
    printf 'Usage: %s [--mirror]\n' "$0"
    printf '  --mirror  Use the TUNA Ubuntu mirror.\n'
}

use_mirror=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mirror) use_mirror=true ;;
        -h|--help) show_help; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; show_help; exit 1 ;;
    esac
    shift
done

if ! command -v apt-get >/dev/null 2>&1; then
    printf 'Error: this installer only supports Debian/Ubuntu apt environments.\n' >&2
    exit 1
fi

apt_sudo=()
if [[ "$(id -u)" -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        printf 'Error: root privileges or sudo are required.\n' >&2
        exit 1
    fi
    apt_sudo=(sudo)
fi

apt_options=()
temporary_sources=''
if [[ "$use_mirror" == true ]]; then
    codename="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-}")"
    if [[ -z "$codename" ]]; then
        printf 'Error: VERSION_CODENAME is missing from /etc/os-release.\n' >&2
        exit 1
    fi

    temporary_sources="$(mktemp)"
    trap 'rm -f "$temporary_sources"' EXIT
    printf '%s\n' \
        "deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $codename main restricted universe multiverse" \
        "deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $codename-updates main restricted universe multiverse" \
        "deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $codename-security main restricted universe multiverse" \
        > "$temporary_sources"
    apt_options=(-o "Dir::Etc::SourceList=$temporary_sources" -o Dir::Etc::SourceParts=/dev/null)
fi

packages=(
    ca-certificates
    fonts-noto-cjk
    fonts-noto-cjk-extra
    fonts-lmodern
    fonts-texgyre
    hunspell
    latexmk
    poppler-utils
    texlive-fonts-extra
    texlive-fonts-recommended
    texlive-lang-chinese
    texlive-latex-extra
    texlive-latex-recommended
    texlive-science
    texlive-xetex
)

export DEBIAN_FRONTEND=noninteractive
"${apt_sudo[@]}" apt-get "${apt_options[@]}" update
"${apt_sudo[@]}" apt-get "${apt_options[@]}" install -y --no-install-recommends "${packages[@]}"

printf 'apt-based LaTeX environment is ready.\n'
