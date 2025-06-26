#!/bin/bash

log() {
	local message="$1"
	local only_file="$2"

	if [ "$SILENT" = false ]; then
		if [ "$only_file" = false ]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") $message" | tee -a "${WORKING_DIRECTORY}/uninstall.log"
		else
			echo "$(date +"%Y-%m-%d %H:%M:%S") $message" >>"${WORKING_DIRECTORY}/uninstall.log"
		fi
	else
		echo "$(date +"%Y-%m-%d %H:%M:%S") $message" >>"${WORKING_DIRECTORY}/uninstall.log"
	fi
}

usage() {
	echo "Usage: $0 [OPTIONS]"
	echo "Options:"
	echo "  -S, --silent          Enable silent mode"
	echo "  -D, --hard-delete     Remove configs, log files and data directory"
	echo "  -y, --yes             Automatically confirm uninstallation without prompting"
	echo "  -h, --help            Display this help message"
	exit 1
}

execCommand() {
	local command="$1"
	local successMessage="$2"
	local errorMessage="$3"

	if $command >/dev/null 2>/dev/null; then
		log "$successMessage" false
	else
		log "$errorMessage" false
	fi
}

get_path() {
	DATA_PATH=$(grep -oP '"data_directory": "\K[^"]+' "${CONFIG_PATH}/config.json" 2>/dev/null)
	log "Data directory path: ${DATA_PATH}" false
	LOG_FILE_PATH=$(dirname $(grep -oP '"log_file_path": "\K[^"]+' "${CONFIG_PATH}/config.json" 2>/dev/null))
	log "Log file path: ${LOG_FILE_PATH}" false
}

uninstall_agent() {
	if [ "$SILENT" = true ]; then
		log "+-----------------------------------------------------------+" false
		log "|                                                           |" false
		log "|     Uninstalling OCSInventory Agent in silent mode...     |" false
		log "|                                                           |" false
		log "+-----------------------------------------------------------+" false
		log "" false
	else
		log "+----------------------------------------------------------------+" false
		log "|                                                                |" false
		log "|     Uninstalling OCSInventory Agent in interactive mode...     |" false
		log "|                                                                |" false
		log "+----------------------------------------------------------------+" false
		log "" false
	fi

	get_path

	if systemctl -q list-units --full -all | grep -q ${SERVICE_NAME}.service; then
		log "Service ${SERVICE_NAME} exists, proceeding with uninstallation." false

		execCommand "systemctl -q stop ${SERVICE_NAME}" "Service ${SERVICE_NAME} stopped successfully." "Failed to stop service ${SERVICE_NAME}. It may not be running."

		execCommand "systemctl -q disable ${SERVICE_NAME}" "Service ${SERVICE_NAME} disabled successfully." "Failed to disable service ${SERVICE_NAME}."

		execCommand "rm ${SERVICE_FILE}" "Service file ${SERVICE_FILE} removed successfully." "Failed to remove service file ${SERVICE_FILE}."

		execCommand "systemctl -q daemon-reload" "Systemd daemon reloaded successfully." "Failed to reload systemd daemon."
	else
		log "Service ${SERVICE_NAME} does not exist." false
	fi

	if [ "$HARD_DELETE" = true ]; then
		execCommand "rm -r ${CONFIG_PATH}" "Configuration directory ${CONFIG_PATH} removed successfully." "Failed to remove configuration directory ${CONFIG_PATH}."

		execCommand "rm -r ${LOG_FILE_PATH}" "Log directory ${LOG_FILE_PATH} removed successfully." "Failed to remove log directory ${LOG_FILE_PATH}."

		execCommand "rm -r ${DATA_PATH}" "Store data directory ${DATA_PATH} removed successfully." "Failed to remove store data directory ${DATA_PATH}."
	fi

	execCommand "rm -r ${AGENT_INSTALLATION_DIR}" "Agent installation directory ${AGENT_INSTALLATION_DIR} removed successfully." "Failed to remove agent installation directory ${AGENT_INSTALLATION_DIR}."

	execCommand "rm ${SYMBOLIC_LINK}" "Symbolic link ${SYMBOLIC_LINK} removed successfully." "Failed to remove symbolic link ${SYMBOLIC_LINK}."

	log "" false
	log "+---------------------------------------------------------------+" false
	log "|                                                               |" false
	log "|     OCSInventory Agent has been successfully uninstalled.     |" false
	log "|                                                               |" false
	log "+---------------------------------------------------------------+" false
}

prompt_confirmation() {
	echo -n "Are you sure you want to uninstall OCS Inventory NG Agent ([y]/n)? "
	read -r confirm
	log "Are you sure you want to uninstall OCS Inventory NG Agent ([y]/n)? $confirm" true
	if [[ "$confirm" =~ ^[yY]?$ ]]; then
		uninstall_agent
	else
		log "Uninstallation cancelled." false
	fi
}

if [ "$(id -u)" != "0" ]; then
	log "The uninstallation script requires elevated privileges, please run as root" false
	exit 1
fi

WORKING_DIRECTORY=$(dirname "$(realpath "$0")")
CONFIG_PATH="/etc/ocsinventory-agent"
AGENT_INSTALLATION_DIR="/usr/local/bin/ocsinventory-agent"
SYMBOLIC_LINK="/usr/bin/ocsinventory-cli"
DATA_PATH=""
LOG_FILE_PATH=""
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SERVICE_NAME="ocsinventory-service"

SILENT=false
HARD_DELETE=false
AUTO_CONFIRM=false

SHORT_OPTS="SDyh"
LONG_OPTS="silent,hard-delete,yes,help"

if ! PARSED_OPTIONS=$(getopt --options $SHORT_OPTS --longoptions $LONG_OPTS --name "$0" -- "$@"); then
	usage
fi

eval set -- "$PARSED_OPTIONS"
unset PARSED_OPTIONS

while true; do
	case "$1" in
	-S | --silent)
		AUTO_CONFIRM=true
		SILENT=true
		shift
		;;
	-D | --hard-delete)
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
		log "Internal error!" false
		exit 1
		;;
	esac
done

if [ "$AUTO_CONFIRM" = "true" ]; then
	uninstall_agent
else
	prompt_confirmation
fi
