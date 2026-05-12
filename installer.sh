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
    echo "  --mirror    Use TUNA (Tsinghua University) mirror for faster downloads in China."
    echo "  --h, --help      Show this help message."
    echo ""
    exit 0
}

USE_MIRROR=false
while [[ $# -gt 0 ]]; do
    case $arg in
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
    if [ "$USE_MIRROR" = true ] && [ "$GITHUB_ACTIONS" != "true" ]; then
        echo -e "${GREEN}Mirror flag detected. Switching apt to TUNA mirror...${NC}"
        sudo sed -i 's/archive.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list
        sudo sed -i 's/security.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list
    fi
    sudo apt-get update -qq
    # Install a balanced selection of packages:
    # - texlive-latex-recommended: Essential LaTeX kernels and base classes.
    # - texlive-latex-extra: Widely used packages for tables, figures, etc.
    # - texlive-xetex: Engine for modern font support (essential for CJK/Unicode).
    # - latexmk: Automation tool to handle multiple compilation passes.
    sudo apt-get install -y texlive-latex-recommended texlive-latex-extra texlive-xetex latexmk


elif command -v brew &> /dev/null; then
    echo "Processing for macOS..."
    # BasicTeX is the lightweight alternative to the 5GB MacTeX.
    brew install --cask basictex

    # Refresh PATH for the current session to locate tlmgr and latexmk
    export PATH="/Library/TeX/texbin:$PATH"
    if [ "$USE_MIRROR" = true ] && [ "$GITHUB_ACTIONS" != "true" ]; then
        echo -e "${GREEN}Mirror flag detected. Switching tlmgr to TUNA mirror...${NC}"
        sudo tlmgr option repository https://mirrors.tuna.tsinghua.edu.cn/CTAN/systems/texlive/tlmgr/
    fi
    # Update the TeX Live Manager and install latexmk (not included in BasicTeX)
    sudo tlmgr update --self
    sudo tlmgr install latexmk


elif command -v pacman &> /dev/null; then
    echo "Processing for Arch Linux..."
    # Arch packages are modular; these cover the vast majority of use cases.
    if [ "$USE_MIRROR" = true ] && [ "$GITHUB_ACTIONS" != "true" ]; then
        echo -e "${GREEN}Mirror flag detected. Updating pacman mirrorlist...${NC}"
        echo 'Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch' | sudo tee /etc/pacman.d/mirrorlist.tmp
        cat /etc/pacman.d/mirrorlist | sudo tee -a /etc/pacman.d/mirrorlist.tmp
        sudo mv /etc/pacman.d/mirrorlist.tmp /etc/pacman.d/mirrorlist
    fi
    sudo pacman -S --noconfirm texlive-bin texlive-core texlive-latexextra latexmk


else
    echo "Error: No supported package manager (apt, brew, pacman) found."
    echo "Please install TeX Live manually from: https://tug.org/texlive/"
    exit 1
fi

# Verification Phase
echo -e "${BLUE}==> Verifying Installation...${NC}"

# Check for latexmk (the primary build tool)
if command -v latexmk &> /dev/null; then
    echo -e "${GREEN}✅ latexmk is ready: $(latexmk -v | head -n1)${NC}"
else
    echo -e "\033[1;31m⚠️ latexmk not found. You might need to restart your shell or check PATH.\033[0m"
fi

# Check for xelatex (the primary engine for modern docs)
if command -v xelatex &> /dev/null; then
    echo -e "${GREEN}✅ xelatex is ready: $(xelatex --version | head -n1)${NC}"
fi

echo -e "\n${GREEN}Setup completed. The environment is optimized for stability and Docker/ROS compatibility.${NC}"