#!/bin/bash

# Constants
SERVICE_NAME="ocsinventory-agent"
CONFIG_PATH="/etc/ocsinventory-agent"
LOG_PATH="/var/log/ocsinventory-agent"
STRORE_DATA_PATH="/var/lib/ocsinventory-data"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
AGENT_INSTALLATION_DIR="/usr/share/ocsinventory-agent"
SYMBOLIC_LINK="/usr/bin/ocsinventory-agent-ng"

# Function to display usage information
usage() {
	echo "Usage: $0 [-y]"
	echo "  -y  Automatically confirm uninstallation without prompting"
	exit 1
}

# Default values
AUTO_CONFIRM=false

# Parse command-line arguments
while getopts "y" opt; do
	case ${opt} in
	y) AUTO_CONFIRM=true ;;
	*) usage ;;
	esac
done

# Function to uninstall the agent
uninstall_agent() {
	echo "Stopping and disabling the service..."
	sudo systemctl stop ${SERVICE_NAME}
	sudo systemctl disable ${SERVICE_NAME}

	echo "Removing service file..."
	sudo rm -f ${SERVICE_FILE}

	echo "Reloading systemd daemon..."
	sudo systemctl daemon-reload

	echo "Removing configuration directory..."
	sudo rm -rf ${CONFIG_PATH}

	echo "Removing log file..."
	sudo rm -rf ${LOG_PATH}

	echo "Removing store data directory..."
	sudo rm -rf ${STRORE_DATA_PATH}

	echo "Removing agent installation directory..."
	sudo rm -rf ${AGENT_INSTALLATION_DIR}

	echo "Removing symbolic link..."
	sudo rm -f ${SYMBOLIC_LINK}

	echo "+----------------------------------------------------------------------+"
	echo "|   OK, OCS Inventory NG Agent for Unix/Linux has been successfully    |"
	echo "|                          uninstalled.                                |"
	echo "|                                                                      |"
	echo "+----------------------------------------------------------------------+"
}

# Function to prompt for confirmation
prompt_confirmation() {
	echo -n "Are you sure you want to uninstall OCS Inventory NG Agent ([y]/n)? "
	read -r confirm
	if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || [ -z "$confirm" ]; then
		uninstall_agent
	else
		echo "Uninstallation cancelled."
	fi
}

# Check for automatic confirmation or prompt the user
if [ "$AUTO_CONFIRM" = "true" ]; then
	uninstall_agent
else
	prompt_confirmation
fi
