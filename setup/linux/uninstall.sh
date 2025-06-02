#!/bin/bash

if [ "$(id -u)" != "0" ]; then
	log "ERROR" "The uninstallation script requires elevated privileges, please run as root" false
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
		log "ERROR" "Internal error!" false
		exit 1
		;;
	esac
done

# Log formatting function
log() {
	local type="$1"
	local message="$2"
	local only_file="$3"
	
	if [ "$SILENT" = false ]; then
		if [ "$only_file" = false ]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$type] $message" | tee -a ./uninstall.log
		else
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$type] $message" >> ./uninstall.log
		fi
	else
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$type] $message" >> ./uninstall.log
	fi
}

# Function to uninstall the agent
uninstall_agent() {
	local is_silent=$1
	local is_hard_delete=$2

	if [ "$is_silent" = true ]; then
		log "INFO" "" false
		log "INFO" "+-----------------------------------------------------------+" false
		log "INFO" "|                                                           |" false
		log "INFO" "|     Uninstalling OCSInventory Agent in silent mode...     |" false
		log "INFO" "|                                                           |" false
		log "INFO" "+-----------------------------------------------------------+" false
		log "INFO" "" false
	else
		log "INFO" "" false
		log "INFO" "+----------------------------------------------------------------+" false
		log "INFO" "|                                                                |" false
		log "INFO" "|     Uninstalling OCSInventory Agent in interactive mode...     |" false
		log "INFO" "|                                                                |" false
		log "INFO" "+----------------------------------------------------------------+" false
		log "INFO" "" false
	fi

	if [ "$is_silent" = false ]; then
		log "INFO" "Stopping and disabling the service..." false
	fi
	if sudo systemctl stop ${SERVICE_NAME} > /dev/null 2> /dev/null; then
		log "INFO" "Service ${SERVICE_NAME} stopped successfully." false
		if sudo systemctl disable ${SERVICE_NAME} > /dev/null 2> /dev/null; then
			log "INFO" "Service ${SERVICE_NAME} disabled successfully." false
		else
			log "ERROR" "Failed to disable service ${SERVICE_NAME}. Exiting script." false
			exit 1;
		fi
	else
		log "ERROR" "Failed to stop service ${SERVICE_NAME}. It may not be running. Exiting script." false
		exit 1;
	fi	

	if [ "$is_silent" = false ]; then
		log "INFO" "Removing service file..." false
	fi
	sudo rm -f ${SERVICE_FILE}

	if [ "$is_silent" = false ]; then
		log "INFO" "Reloading systemd daemon..." false
	fi
	sudo systemctl daemon-reload

	if [ "$is_hard_delete" = true ]; then
		if [ "$is_silent" = false ]; then
			log "INFO" "Removing configuration directory..." false
		fi
		sudo rm -rf ${CONFIG_PATH}

		if [ "$is_silent" = false ]; then
			log "INFO" "Removing log file..." false
		fi
		sudo rm -rf ${LOG_PATH}

		if [ "$is_silent" = false ]; then
			log "INFO" "Removing store data directory..." false
		fi
		sudo rm -rf ${STRORE_DATA_PATH}
	fi

	if [ "$is_silent" = false ]; then
		log "INFO" "Removing agent installation directory..." false
	fi
	sudo rm -rf ${AGENT_INSTALLATION_DIR}

	if [ "$is_silent" = false ]; then
		log "INFO" "Removing symbolic link..." false
	fi
	sudo rm -f ${SYMBOLIC_LINK}

	log "INFO" "" false
	log "INFO" "+---------------------------------------------------------------+" false
	log "INFO" "|                                                               |" false
	log "INFO" "|     OCSInventory Agent has been successfully uninstalled.     |" false
	log "INFO" "|                                                               |" false
	log "INFO" "+---------------------------------------------------------------+" false
}

# Function to prompt for confirmation
prompt_confirmation() {
	echo -n "Are you sure you want to uninstall OCS Inventory NG Agent ([y]/n)? "
	read -r confirm
	log "INFO" "Are you sure you want to uninstall OCS Inventory NG Agent ([y]/n)? $confirm" true
	if [[ "$confirm" =~ ^[yY]?$ ]]; then
		uninstall_agent "$SILENT" "$HARD_DELETE"
	else
		log "INFO" "Uninstallation cancelled." false
	fi
}

# Check for automatic confirmation or prompt the user
if [ "$AUTO_CONFIRM" = "true" ]; then
	uninstall_agent "$SILENT" "$HARD_DELETE"
else
	prompt_confirmation
fi