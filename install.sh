#!/bin/bash
# This script installs NodeExporter for prometheus on various Linux distributions
#
# Original author: qeba-
# First script written on 1/6/2021
# Updated on 10/08/2024 - to download latest version instead of fixed version
# Updated on 11/01/2025 - added multi-distribution support
#
# Usage: bash install.sh

# Function to detect the Linux distribution
detect_distribution() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    else
        echo "Cannot detect Linux distribution. Exiting..."
        exit 1
    fi
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run this script as root or with sudo"
        exit 1
    fi
}

# Function to install required packages
install_prerequisites() {
    echo "Installing prerequisites..."
    case $DISTRO in
        "ubuntu"|"debian")
            apt-get update
            apt-get install -y wget curl
            ;;
        "centos"|"rhel"|"fedora"|"rocky"|"almalinux")
            yum install -y wget curl
            ;;
        *)
            echo "Unsupported distribution: $DISTRO"
            exit 1
            ;;
    esac
}

# Fetch the latest release version from the GitHub API
get_latest_version() {
    latest_version=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep "tag_name" | cut -d'"' -f4)
    # Remove the leading "v" from the version number
    latest_version=${latest_version:1}
    download_url="https://github.com/prometheus/node_exporter/releases/download/v${latest_version}/node_exporter-${latest_version}.linux-amd64.tar.gz"
}

# Function to create system user based on distribution
create_user() {
    echo "Creating node_exporter user..."
    case $DISTRO in
        "ubuntu"|"debian")
            useradd -rs /bin/false node_exporter 2>/dev/null || true
            ;;
        "centos"|"rhel"|"fedora"|"rocky"|"almalinux")
            useradd -rs /bin/false node_exporter 2>/dev/null || true
            ;;
    esac
}

# Main installation function
install_node_exporter() {
    local temp_dir="tempInstall"
    
    # Create and enter temp directory
    rm -rf ./$temp_dir 2>/dev/null
    mkdir $temp_dir
    cd $temp_dir

    echo "Downloading Node Exporter..."
    wget "$download_url"
    
    echo "Extracting files..."
    tar -xvf node_exporter-${latest_version}.linux-amd64.tar.gz
    
    echo "Installing Node Exporter..."
    mv ./node_exporter-${latest_version}.linux-amd64/node_exporter /usr/local/bin/
    
    cd ..
    rm -rf ./$temp_dir
}

# Function to create systemd service
create_service() {
    echo "Creating systemd service..."
    cat > /etc/systemd/system/node_exporter.service <<EOL
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOL

    systemctl daemon-reload
    systemctl start node_exporter
    systemctl enable node_exporter
}

# Main execution
echo "----------------------------------------------------------------------------------"
echo "Node Exporter Installation Script - Multi-Distribution Support"
echo "----------------------------------------------------------------------------------"

# Check if running as root
check_root

# Detect distribution
detect_distribution
echo "Detected Linux distribution: $DISTRO $VERSION"

# Confirm installation
read -p "Press Enter to continue with installation or Ctrl+C to cancel..."

# Install prerequisites
install_prerequisites

# Get latest version
get_latest_version

# Create user
create_user

# Install Node Exporter
install_node_exporter

# Create and start service
create_service

# Check service status
echo "Checking service status..."
systemctl status node_exporter

# Get public IP
ipAddress=$(curl -s https://api.ipify.org)

clear
echo "Installation completed successfully!"
echo "----------------------------------------------------------------------------------"
echo "Prometheus configuration:"
echo "- job_name: 'node_exporter_metrics'"
echo "  scrape_interval: 5s"
echo "  static_configs:"
echo "     - targets: ['$ipAddress:9100']"
echo "----------------------------------------------------------------------------------"
