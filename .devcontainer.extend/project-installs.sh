#!/bin/bash
# File: .devcontainer.extend/project-installs.sh
# Purpose: Project-specific custom installations
# This script runs AFTER all standard tools from enabled-tools.conf are installed.
#
# Use this for:
#   - Project-specific npm/pip/cargo packages
#   - Database setup scripts
#   - Custom configuration

set -e

# ADD YOUR CUSTOM INSTALLATIONS BELOW

#------------------------------------------------------------------------------
# TEMPORARY: PowerShell 7 + PSScriptAnalyzer + SvRooij.ContentPrep.Cmdlet
# Needed for Intune script development, linting, and .intunewin packaging.
# Remove this when devcontainer-toolbox ships tool-powershell.
# See: docs/ai-developer/devcontainer-toolbox-issues/ISSUE-lightweight-powershell.md
#------------------------------------------------------------------------------

PWSH_VERSION="7.5.4"
PWSH_INSTALL_DIR="/opt/microsoft/powershell/7"

ARCH="$(uname -m)"
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    PWSH_ARCH="linux-arm64"
elif [ "$ARCH" = "x86_64" ]; then
    PWSH_ARCH="linux-x64"
else
    echo "ERROR: Unsupported architecture: $ARCH"
    exit 1
fi

echo "Installing PowerShell ${PWSH_VERSION} (${PWSH_ARCH})..."

# Download and extract from GitHub releases
# https://learn.microsoft.com/en-us/powershell/scripting/install/install-other-linux
curl -sSL "https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-${PWSH_ARCH}.tar.gz" -o /tmp/powershell.tar.gz
mkdir -p "$PWSH_INSTALL_DIR"
tar -xzf /tmp/powershell.tar.gz -C "$PWSH_INSTALL_DIR"
rm /tmp/powershell.tar.gz
chmod +x "${PWSH_INSTALL_DIR}/pwsh"
ln -sf "${PWSH_INSTALL_DIR}/pwsh" /usr/local/bin/pwsh

echo "Installing PowerShell modules..."
pwsh -NoProfile -Command 'Install-Module -Name PSScriptAnalyzer -Force -Scope AllUsers'
pwsh -NoProfile -Command 'Install-Module -Name SvRooij.ContentPrep.Cmdlet -Force -Scope AllUsers'

echo "PowerShell $(pwsh --version) installed with PSScriptAnalyzer and SvRooij.ContentPrep.Cmdlet."

#------------------------------------------------------------------------------
# Git hooks
# Version-controlled hooks in .githooks/ (auto-bump SCRIPT_VER on commit)
#------------------------------------------------------------------------------

git config core.hooksPath .githooks
echo "Git hooks configured (.githooks/pre-commit)."

exit 0
