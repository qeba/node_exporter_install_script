#!/bin/bash
# This script installs NodeExporter for prometheus on various Linux distributions
#
# Original author: qeba-
# First script written on 1/6/2021
# Updated on 10/08/2024 - to download latest version instead of fixed version
# Updated on 11/01/2025 - added multi-distribution support and color coding
#
# Usage: bash install.sh

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BLUE='\033[0;34m'

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✔ $1${NC}"
}

print_error() {
    echo -e "${RED}✘ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Function to detect the Linux distribution
detect_distribution() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    else
        print_error "Cannot detect Linux distribution. Exiting..."
        exit 1
    fi
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run this script as root or with sudo"
        exit 1
    fi
}

# Function to install required packages
install_prerequisites() {
    print_info "Installing prerequisites..."
    case $DISTRO in
        "ubuntu"|"debian")
            if apt-get update && apt-get install -y wget curl; then
                print_success "Prerequisites installed successfully"
            else
                print_error "Failed to install prerequisites"
                exit 1
            fi
            ;;
        "centos"|"rhel"|"fedora"|"rocky"|"almalinux")
            if yum install -y wget curl; then
                print_success "Prerequisites installed successfully"
            else
                print_error "Failed to install prerequisites"
                exit 1
            fi
            ;;
        *)
            print_error "Unsupported distribution: $DISTRO"
            exit 1
            ;;
    esac
}

# Fetch the latest release version from the GitHub API
get_latest_version() {
    print_info "Fetching latest version..."
    latest_version=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep "tag_name" | cut -d'"' -f4)
    if [ -z "$latest_version" ]; then
        print_error "Failed to fetch latest version"
        exit 1
    fi
    latest_version=${latest_version:1}
    download_url="https://github.com/prometheus/node_exporter/releases/download/v${latest_version}/node_exporter-${latest_version}.linux-amd64.tar.gz"
    print_success "Latest version: ${latest_version}"
}

# Function to create system user based on distribution
create_user() {
    print_info "Creating node_exporter user..."
    case $DISTRO in
        "ubuntu"|"debian"|"centos"|"rhel"|"fedora"|"rocky"|"almalinux")
            useradd -rs /bin/false node_exporter 2>/dev/null || true
            print_success "User created or already exists"
            ;;
    esac
}

# Main installation function
install_node_exporter() {
    local temp_dir="tempInstall"
    
    print_info "Preparing installation directory..."
    rm -rf ./$temp_dir 2>/dev/null
    mkdir $temp_dir
    cd $temp_dir

    print_info "Downloading Node Exporter..."
    if wget "$download_url"; then
        print_success "Download completed"
    else
        print_error "Download failed"
        exit 1
    fi
    
    print_info "Extracting files..."
    if tar -xvf node_exporter-${latest_version}.linux-amd64.tar.gz; then
        print_success "Extraction completed"
    else
        print_error "Extraction failed"
        exit 1
    fi
    
    print_info "Installing Node Exporter..."
    if mv ./node_exporter-${latest_version}.linux-amd64/node_exporter /usr/local/bin/; then
        print_success "Installation completed"
    else
        print_error "Installation failed"
        exit 1
    fi
    
    cd ..
    rm -rf ./$temp_dir
}

# Function to create systemd service
create_service() {
    print_info "Creating systemd service..."
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

# Function to check service status
check_service_status() {
    print_info "Checking Node Exporter service status..."
    
    # Check if service is enabled
    if systemctl is-enabled --quiet node_exporter; then
        print_success "Service is enabled at boot"
    else
        print_warning "Service is not enabled at boot"
    fi
    
    # Check if service is running
    if systemctl is-active --quiet node_exporter; then
        print_success "Service is running"
        
        # Check port
        if command -v netstat >/dev/null; then
            if netstat -tuln | grep -q ":9100 "; then
                print_success "Port 9100 is listening"
            else
                print_error "Port 9100 is not listening"
            fi
        fi
        
        # Test metrics endpoint
        if curl -s http://localhost:9100/metrics >/dev/null; then
            print_success "Metrics endpoint is accessible"
        else
            print_error "Metrics endpoint is not responding"
        fi
        
    else
        print_error "Service is not running"
        echo "Recent logs:"
        journalctl -u node_exporter --no-pager --lines=3
    fi
}

# Main execution
echo "----------------------------------------------------------------------------------"
print_info "Node Exporter Installation Script - Multi-Distribution Support"
echo "----------------------------------------------------------------------------------"

# Check if running as root
check_root

# Detect distribution
detect_distribution
print_info "Detected Linux distribution: $DISTRO $VERSION"

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
check_service_status

# Get public IP
ipAddress=$(curl -s https://api.ipify.org)

echo "----------------------------------------------------------------------------------"
print_success "Installation completed successfully!"
echo "----------------------------------------------------------------------------------"
print_info "Prometheus configuration:"
echo "- job_name: 'node_exporter_metrics'"
echo "  scrape_interval: 5s"
echo "  static_configs:"
echo "     - targets: ['$ipAddress:9100']"
echo "----------------------------------------------------------------------------------"
