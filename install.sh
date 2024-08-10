#!/bin/bash
# This script intended to be use to install NodeExporter for prometheus
#
# Wrote by qeba-
#
# First script is written on 1/6/2021
# update script on 10/08/2024 - to download latest version instead of fix version
#
# Usage: bash install.sh

# Fetch the latest release version from the GitHub API
latest_version=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep "tag_name" | cut -d'"' -f4)

# Construct the download URL for the Node Exporter binary
download_url="https://github.com/prometheus/node_exporter/releases/download/${latest_version}/node_exporter-${latest_version}.linux-amd64.tar.gz"

# Remove the leading "v" from the version number
latest_version=${latest_version:1}

# Reconstruct the download URL without the leading "v"
download_url="https://github.com/prometheus/node_exporter/releases/download/v${latest_version}/node_exporter-${latest_version}.linux-amd64.tar.gz"

echo "----------------------------------------------------------------------------------"
echo "This script is used to setup NodeExporter Automatically on Linux OS"
echo "----------------------------------------------------------------------------------"
read -p "Press Enter key when you ready!/  "


checkFolder() {
    if [ -d "./tempInstall" ] 
        then
            printf  "\nDirectory Alerady exists, will delete the directory first." 
            printf  "\nMake sure you backup if there related data in ./tempInstall folder," 
            printf  "\n"
            read -p "Press Enter to continue delete or ctrl + c to cancel!.   "
            rm -rf ./tempInstall
            sleep 1
            mkdir tempInstall
            cd ./tempInstall
        else 
            mkdir tempInstall 
            cd ./tempInstall
    fi
}

#make folder to downlaod
checkFolder

#begin to install. 
echo  "Download the NodeExporter...." 
wget ${download_url}
sleep 1
echo  "Extract the files..." 
printf  "\n"
tar -xvf node_exporter-${latest_version}.linux-amd64.tar.gz
sleep 2
sudo mv ./node_exporter-${latest_version}.linux-amd64/node_exporter /usr/local/bin/
sleep 2
echo  "Create user for Node Exporter......"
printf  "\n"
sudo useradd -rs /bin/false node_exporter
echo  "Clear installation files...."
printf  "\n"
cd ..
rm -rf ./tempInstall
sleep 2
echo  "Waiting for something....."
printf  "\n"
echo  "Begin to setup services...."
sleep 1
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

sleep 2
printf  "\n"
echo  "Configuration files added.. setup completed!...."
clear
echo "----------------------------------------------------------------------------------"
echo " Configure service to run and test the services.... "
echo "----------------------------------------------------------------------------------"
sudo systemctl daemon-reload
sleep 2
printf  "\n"
echo  "Try to start node_exporter services..."
sudo systemctl start node_exporter
sleep 2
sudo systemctl status node_exporter
sleep 1
printf  "\n"
printf  "\n"
echo -e "\e[1;32m √ Please ensure the status is active before continue.... \e[0m"
sleep 1
read -p "Do you see the service status is active?. if Yes enter to continue..  "
printf  "\n"
echo  "Enable the exporter running automatically after reboot...."
sudo systemctl enable node_exporter
clear

ipAddress=$(hostname -i)

echo " Everthing complete!.. Time to configure prometheus with the node details..."
echo "----------------------------------------------------------------------------------"
echo "- job_name: 'node_exporter_metrics'"
echo "  scrape_interval: 5s"
echo "  static_configs:"
echo "     - targets: ['$ipAddress:9100'] "
echo "----------------------------------------------------------------------------------"