#!/bin/bash

if [ "$(id -u)" != "0" ]; then
	echo "The uninstallation script requires elevated privileges, please run as root" >&2
	exit 1
fi

# Constants
SERVICE_NAME="ocsinventory-agent"
CONFIG_PATH="/etc/ocsinventory-agent"
LOG_PATH="/var/log/ocsinventory-agent"
STRORE_DATA_PATH="/var/lib/ocsinventory-data"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
AGENT_INSTALLATION_DIR="/usr/share/ocsinventory-agent"
SYMBOLIC_LINK="/usr/bin/ocsinventory-agent"

# Function to display usage information
usage() {
	echo "Usage: $0 [OPTIONS]"
	echo "Options:"
	echo "  -S, --silent          Enable silent mode"
	echo "  -D, --hard-delete     Remove configs, log files and store data directory"
	echo "  -y                    Automatically confirm uninstallation without prompting"
	echo "  -h, --help            Display this help message"
	exit 1
}

# Default values
SILENT=false
HARD_DELETE=false
AUTO_CONFIRM=false

# options
SHORT_OPTS="hSDy"
LONG_OPTS="help,silent,hard-delete,yes"

# parse options
if ! PARSED_OPTIONS=$(getopt --options $SHORT_OPTS --longoptions $LONG_OPTS --name "$0" -- "$@"); then
	usage
fi

eval set -- "$PARSED_OPTIONS"
unset PARSED_OPTIONS

# process options
while true; do
	case "$1" in
	-S | --silent)
		SILENT=true
		shift
		;;
	-D | --hard_delete)
		HARD_DELETE=true
		shift
		;;
	-y | --yes)
		AUTO_CONFIRM=true
		shift
		;;
	-h | --help)
		usage
		;;
	--)
		shift
		break
		;;
	*)
		echo "Internal error!" >&2
		exit 1
		;;
	esac
done

# Function to uninstall the agent
uninstall_agent() {
	local is_silent=$1
	local is_hard_delete=$2

	if [ "$is_silent" = true ]; then
		echo
		echo "+-----------------------------------------------------------+"
		echo "|                                                           |"
		echo "|     Uninstalling OCSInventory Agent in silent mode...     |"
		echo "|                                                           |"
		echo "+-----------------------------------------------------------+"
		echo
	else
		echo
		echo "+----------------------------------------------------------------+"
		echo "|                                                                |"
		echo "|     Uninstalling OCSInventory Agent in interactive mode...     |"
		echo "|                                                                |"
		echo "+----------------------------------------------------------------+"
		echo
	fi

	if [ "$is_silent" = false ]; then
		echo "Stopping and disabling the service..."
	fi
	sudo systemctl stop ${SERVICE_NAME}
	sudo systemctl disable ${SERVICE_NAME}

	if [ "$is_silent" = false ]; then
		echo "Removing service file..."
	fi
	sudo rm -f ${SERVICE_FILE}

	if [ "$is_silent" = false ]; then
		echo "Reloading systemd daemon..."
	fi
	sudo systemctl daemon-reload

	if [ "$is_hard_delete" = true ]; then
		if [ "$is_silent" = false ]; then
			echo "Removing configuration directory..."
		fi
		sudo rm -rf ${CONFIG_PATH}

		if [ "$is_silent" = false ]; then
			echo "Removing log file..."
		fi
		sudo rm -rf ${LOG_PATH}

		if [ "$is_silent" = false ]; then
			echo "Removing store data directory..."
		fi
		sudo rm -rf ${STRORE_DATA_PATH}
	fi

	if [ "$is_silent" = false ]; then
		echo "Removing agent installation directory..."
	fi
	sudo rm -rf ${AGENT_INSTALLATION_DIR}

	if [ "$is_silent" = false ]; then
		echo "Removing symbolic link..."
	fi
	sudo rm -f ${SYMBOLIC_LINK}

	echo "+---------------------------------------------------------------+"
	echo "|                                                               |"
	echo "|     OCSInventory Agent has been successfully uninstalled.     |"
	echo "|                                                               |"
	echo "+---------------------------------------------------------------+"
}

# Function to prompt for confirmation
prompt_confirmation() {
	echo -n "Are you sure you want to uninstall OCS Inventory NG Agent ([y]/n)? "
	read -r confirm
	if [[ "$confirm" =~ ^[yY]?$ ]]; then
		uninstall_agent "$SILENT" "$HARD_DELETE"
	else
		echo "Uninstallation cancelled."
	fi
}

# Check for automatic confirmation or prompt the user
if [ "$AUTO_CONFIRM" = "true" ]; then
	uninstall_agent "$SILENT" "$HARD_DELETE"
else
	prompt_confirmation
fi
