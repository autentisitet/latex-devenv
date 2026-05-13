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

# Output styling
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==> Starting LaTeX Core Setup (TeX Live Based)${NC}"

if command -v apt-get &> /dev/null; then
    echo "Processing for Debian/Ubuntu/WSL..."

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
        sudo apt-get update $APT_OPT -qq
        sudo apt-get install -y $APT_OPT texlive-latex-recommended texlive-latex-extra texlive-xetex latexmk
        rm -f "$TEMP_SOURCES"
    else
        sudo apt-get update -qq
        sudo apt-get install -y texlive-latex-recommended texlive-latex-extra texlive-xetex latexmk
    fi

elif command -v brew &> /dev/null; then
    echo "Processing for macOS..."
    if ! brew list --cask basictex &>/dev/null; then
        brew install --cask basictex
    fi

    # Vital for GitHub Actions: Persist PATH for subsequent steps
    TEX_PATH="/Library/TeX/texbin"
    export PATH="$TEX_PATH:$PATH"
    if [ -n "$GITHUB_PATH" ]; then
        echo "$TEX_PATH" >> "$GITHUB_PATH"
    fi

    if [ "$USE_MIRROR" = true ] && [ "$GITHUB_ACTIONS" != "true" ]; then
        echo -e "${GREEN}Using temporary TUNA repository for tlmgr...${NC}"
        MIRROR_URL="https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlmgr/"
        sudo tlmgr update --self --repository "$MIRROR_URL" || sudo tlmgr update --self --repository "$MIRROR_URL" --force
        sudo tlmgr install latexmk --repository "$MIRROR_URL"
    else
        # Handle tlmgr version mismatch with a fallback force update
        sudo tlmgr update --self || sudo tlmgr update --self --force
        sudo tlmgr install latexmk
    fi

elif command -v pacman &> /dev/null; then
    echo "Processing for Arch Linux..."
    TEMP_PACMAN_CONF="/tmp/pacman_tuna.conf"
    sudo cp /etc/pacman.conf "$TEMP_PACMAN_CONF"
    sudo chmod 644 "$TEMP_PACMAN_CONF"

    if [ "$USE_MIRROR" = true ] && [ "$GITHUB_ACTIONS" != "true" ]; then
        echo -e "${GREEN}Injecting TUNA mirror into temporary config...${NC}"
        sudo sed -i "/\[core\]/i Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/\$repo/os/\$arch\n" "$TEMP_PACMAN_CONF"
    fi

    sudo pacman -S --noconfirm --config "$TEMP_PACMAN_CONF" texlive-bin texlive-core texlive-latexextra latexmk
    sudo rm -f "$TEMP_PACMAN_CONF"

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