#!/bin/bash
set -e

# --- Variables ---
REPO_BASE="https://raw.githubusercontent.com/iamaryav/config-files/refs/heads/main"
USER_NAME=$(whoami)

# --- 1. Detect Package Manager ---
if command -v apt-get &> /dev/null; then
    PKG_MGR="apt-get install -y"
    UPDATE="apt-get update"
elif command -v dnf &> /dev/null; then
    PKG_MGR="dnf install -y"
    UPDATE="dnf check-update"
elif command -v pacman &> /dev/null; then
    PKG_MGR="pacman -S --noconfirm"
    UPDATE="pacman -Sy"
else
    echo "Error: Could not detect apt, dnf, or pacman."
    exit 1
fi

echo "--- Updating Repositories ---"
sudo $UPDATE || true

# --- 2. Install Sudo (if missing) ---
if ! command -v sudo &> /dev/null; then
    echo "Sudo not found. Installing sudo..."
    # We must be root to install sudo without sudo
    if [ "$EUID" -ne 0 ]; then
        echo "Error: 'sudo' is missing and you are not root. Cannot install it."
        exit 1
    fi
    $PKG_MGR sudo
    echo "✓ sudo installed."
fi

# --- 3. Set Sudo Variable ---
# Now we know sudo exists (or we are root)
if [ "$EUID" -eq 0 ]; then
  SUDO="" 
else
  SUDO="sudo"
fi

# --- 2. Install Software ---
echo "--- Installing Software ---"

# Install Wget, curl, unzip, Tmux, Zsh
# In future oh-my-zsh
for pkg in unzip wget curl tmux zsh; do
    if ! command -v $pkg &> /dev/null; then
        echo "Installing $pkg..."
        sudo $PKG_MGR $pkg
    else
        echo "✓ $pkg is already installed."
    fi
done
# Install Latest Neovim (Binary)
if ! command -v nvim &> /dev/null; then
    echo "Installing latest Neovim..."
    wget https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
    sudo rm -rf /opt/nvim-linux-x86_64
    sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
    sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
    rm nvim-linux-x86_64.tar.gz
    echo "✓ Neovim (Latest) installed."
else
    echo "✓ nvim is already installed."
fi

# --- 3. Configuration Management ---
echo "--- Downloading Configurations ---"

# Function to backup and download
install_config() {
    local url=$1
    local dest=$2
    
    # Backup if exists
    if [ -f "$dest" ]; then
        echo "Backing up existing $dest to $dest.bak"
        mv "$dest" "$dest.bak"
    fi
    
    # Download
    echo "Downloading to $dest..."
    wget -qO "$dest" "$url"
}

# Ensure nvim config directory exists
mkdir -p ~/.config/nvim

install_config "$REPO_BASE/init.lua"    "$HOME/.config/nvim/init.lua"
install_config "$REPO_BASE/.bashrc"     "$HOME/.bashrc"
install_config "$REPO_BASE/.tmux.conf"  "$HOME/.tmux.conf"
install_config "$REPO_BASE/.vimrc"      "$HOME/.vimrc"
install_config "$REPO_BASE/.zshrc"      "$HOME/.zshrc"

# --- 4. Set Zsh as Default Shell ---
echo "--- Configuring Shell ---"

ZSH_PATH=$(which zsh)
CURRENT_SHELL=$(getent passwd $USER_NAME | cut -d: -f7)

if [ "$CURRENT_SHELL" != "$ZSH_PATH" ]; then
    echo "Changing default shell to zsh..."
    # Using usermod is easier in scripts as it utilizes the existing sudo session
    sudo usermod -s "$ZSH_PATH" "$USER_NAME"
    echo "✓ Default shell changed to zsh."
else
    echo "✓ zsh is already the default shell."
fi

echo "--- Setup Complete! ---"
echo "Please log out and log back in for the shell change to take effect."
