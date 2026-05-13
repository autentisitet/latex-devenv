#!/usr/bin/env bash
# LaTeX Core Setup (Linux / macOS / WSL)
#
# RATIONALE: Why TeX Live instead of MiKTeX for Linux/WSL?
# 1. SYSTEM INTEGRATION: TeX Live is the "native" distribution for Linux. It integrates
#    seamlessly with system package managers (apt/pacman), preventing permission conflicts.
# 2. STABILITY: Unlike MiKTeX's "install-on-the-fly" approach, TeX Live pre-installs
#    packages. This is critical for Docker, ROS 2, and CI/CD, where network-dependent
#    downloads during compilation can cause random build failures.
# 3. ENVIRONMENT ISOLATION: TeX Live avoids cluttering the $HOME directory with
#    configuration files, making it easier to manage alongside complex tools like ROS.

set -e

show_help() {
    echo "Usage: ./installer.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --mirror     Use TUNA (Tsinghua University) mirror for faster downloads in China."
    echo "  --h, --help      Show this help message."
    echo ""
    exit 0
}

USE_MIRROR=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mirror)
            USE_MIRROR=true
            shift ;;
        --help|-h)
            show_help ;;
        *)
            echo -e "\033[1;31mUnknown option: $1\033[0m"
            show_help ;;
    esac
done


if [ "$(id -u)" -eq 0 ]; then
    export LTX_SUDO=""
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS does not require sudo except for writing to /Library and modifying system configuration.
    export LTX_SUDO=""
elif command -v sudo &> /dev/null; then
    export LTX_SUDO="sudo"
else
    echo -e "\033[1;33mWarning: Not root and 'sudo' not found. Trying without it...\033[0m"
    export LTX_SUDO=""
fi


# Output styling
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==> Starting LaTeX Core Setup (TeX Live Based)${NC}"

if command -v apt-get &> /dev/null; then
    echo "Processing for Debian/Ubuntu/WSL..."
    UBUNTU_LATEX_PACKAGES=(
        texlive-latex-recommended
        texlive-latex-extra
        texlive-xetex
        texlive-lang-chinese
        texlive-fonts-recommended
        texlive-fonts-extra
        texlive-science
        fonts-noto-cjk
        fonts-noto-cjk-extra
        latexmk
        hunspell
    )

    # Fallback for lsb_release missing in slim images
    if command -v lsb_release &> /dev/null; then
        CODENAME=$(lsb_release -cs)
    else
        CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2 || echo "focal")
    fi

    if [ "$USE_MIRROR" = true ] && [ "$GITHUB_ACTIONS" != "true" ]; then
        echo -e "${GREEN}Using temporary TUNA mirror config...${NC}"
        TEMP_SOURCES="/tmp/tuna_sources.list"
        cat > "$TEMP_SOURCES" <<EOF
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $CODENAME main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $CODENAME-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $CODENAME-security main restricted universe multiverse
EOF
        APT_OPT="-o Dir::Etc::SourceList=$TEMP_SOURCES -o Dir::Etc::SourceParts=/dev/null"
        ${LTX_SUDO} apt-get update $APT_OPT -qq
        ${LTX_SUDO} apt-get install -y $APT_OPT "${UBUNTU_LATEX_PACKAGES[@]}"
        rm -f "$TEMP_SOURCES"
    else
        ${LTX_SUDO} apt-get update -qq
        ${LTX_SUDO} apt-get install -y "${UBUNTU_LATEX_PACKAGES[@]}"
    fi



elif command -v brew &> /dev/null; then
    echo "Processing for macOS..."
    TLMGR_LATEX_PACKAGES=(
        latexmk
        ctex
        breqn
        unicode-math
        adjustbox
        xparse
    )
    BREW_LATEX_PACKAGES=(
        basictex
        font-noto-sans-cjk
        font-noto-serif-cjk
    )


    # --------------- BREW -------------------
    if [ "$USE_MIRROR" = true ] && [ "$GITHUB_ACTIONS" != "true" ]; then
        echo -e "${GREEN}Using TUNA mirror for Homebrew...${NC}"
        export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
        export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
        export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
    fi

    for pkg in "${BREW_LATEX_PACKAGES[@]}"; do
        if ! brew list --cask "$pkg" &>/dev/null; then
            brew install --cask "$pkg"
        else
            echo "[✓] $pkg already installed"
        fi
    done


    # Vital for GitHub Actions: Persist PATH for subsequent steps
    # --------------- TLMGR -------------------
    TEX_PATH="/Library/TeX/texbin"
    if [ -d "$TEX_PATH" ]; then
        export PATH="$TEX_PATH:$PATH"
        [ -n "$GITHUB_PATH" ] && echo "$TEX_PATH" >> "$GITHUB_PATH"
    fi
    TLMGR_BIN="$TEX_PATH/tlmgr"

    if [ "$USE_MIRROR" = true ] && [ "$GITHUB_ACTIONS" != "true" ]; then
        echo -e "${GREEN}Using temporary TUNA repository for tlmgr...${NC}"
        MIRROR_URL="https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlmgr/"
        ${LTX_SUDO} "$TLMGR_BIN" update --self --repository "$MIRROR_URL" \
            || ${LTX_SUDO} "$TLMGR_BIN" update --self --repository "$MIRROR_URL" --force
        ${LTX_SUDO} "$TLMGR_BIN" update --all --repository "$MIRROR_URL"
        ${LTX_SUDO} "$TLMGR_BIN" install "${TLMGR_LATEX_PACKAGES[@]}" --repository "$MIRROR_URL"
    else
        # Handle tlmgr version mismatch with a fallback force update
        ${LTX_SUDO} "$TLMGR_BIN" update --self \
            || ${LTX_SUDO} "$TLMGR_BIN" update --self --force
        ${LTX_SUDO} "$TLMGR_BIN" update --all
        ${LTX_SUDO} "$TLMGR_BIN" install "${TLMGR_LATEX_PACKAGES[@]}"
    fi

    echo "Generating LaTeX formats..."
    ${LTX_SUDO} fmtutil-sys --all || true

    ${LTX_SUDO} "${TLMGR_BIN}" path add
    if command -v fc-cache &> /dev/null; then
        echo "Refreshing font cache..."
        ${LTX_SUDO} fc-cache -fv
    fi



elif command -v pacman &> /dev/null; then
    echo "Processing for Arch Linux..."
    PACMAN_LATEX_PACKAGES=(
        texlive-bin
        texlive-basic
        texlive-latexextra
        texlive-langchinese
        texlive-fontsextra
        noto-fonts
        noto-fonts-cjk
        hunspell
    )

    TEMP_PACMAN_CONF="/tmp/pacman_tuna.conf"
    ${LTX_SUDO} cp /etc/pacman.conf "$TEMP_PACMAN_CONF"
    ${LTX_SUDO} chmod 644 "$TEMP_PACMAN_CONF"

    if [ "$USE_MIRROR" = true ] && [ "$GITHUB_ACTIONS" != "true" ]; then
        echo -e "${GREEN}Injecting TUNA mirror into temporary config...${NC}"
        ${LTX_SUDO} sed -i "/\[core\]/i Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/\$repo/os/\$arch\n" "$TEMP_PACMAN_CONF"
    fi

    ${LTX_SUDO} pacman -S --noconfirm --config "$TEMP_PACMAN_CONF" "${PACMAN_LATEX_PACKAGES[@]}"
    ${LTX_SUDO} rm -f "$TEMP_PACMAN_CONF"
    ${LTX_SUDO} fc-cache -fv


else
    echo -e "\033[1;31mError: No supported package manager found.\033[0m"
    exit 1
fi



# Verification Phase
echo -e "${BLUE}==> Verifying Installation...${NC}"
if command -v latexmk &> /dev/null; then
    echo -e "${GREEN}✅ latexmk is ready: $(latexmk -v | head -n1)${NC}"
else
    echo -e "\033[1;31m⚠️ latexmk not found. Path issues may persist.${NC}"
fi

echo -e "\n${GREEN}Setup completed successfully.${NC}"