#!/bin/bash

if [ "$(id -u)" != "0" ]; then
	log "ERROR" "The installation script requires elevated privileges, please run as root" false
	exit 1
fi

# Constants
WORKING_DIRECTORY=$(dirname "$(realpath "$0")")
WORKING_DIRECTORY_EXEC_PATH="/setup/linux"
EXEC_AGENT="/AGENT-LINUX"
CONFIG_PATH="/etc/ocsinventory-agent"
LOG_PATH="/var/log/ocsinventory-agent/ocsinventory-agent.log"
STORE_DATA_PATH="/var/lib/ocsinventory-data"
SERVICE_NAME="ocsinventory-agent"
SERVICE_EXEC="/DAEMON-LINUX"
AGENT_INSTALLATION_DIR="/usr/share/ocsinventory-agent"
SYMBOLIC_LINK="/usr/bin/ocsinventory-agent"

# Function to display usage information
usage() {
	echo "Usage: $0 [OPTIONS]"
	echo "Options:"
	echo "  -S, --silent                Enable silent mode (requires --url, --username, --password)"
	echo "  -U, --url URL               URL of the OCSInventory server (required for silent mode)"
	echo "  -u, --username USERNAME     Username (required for silent mode)"
	echo "  -p, --password PASSWORD     Password (required for silent mode)"
	echo "  -m, --mode MODE             Inventory mode (default: 1 = Remote with template)"
	echo "  -l, --log-level LEVEL       Log level (default: 2 = Info)"
	echo "  -c, --certificate CERT      Path to the certificate file (default: null)"
	echo "  -s, --service               Register the agent as a systemd service"
	echo "  -n, --now                   Run the agent inventory immediately after installation"
	echo "  -h, --help                  Display this help message"
	exit 1
}

# Function to log formated messages
log() {
	local type="$1"
	local message="$2"
	local only_file="$3"

	if [ "$SILENT" = false ]; then
		if [ "$only_file" = false ]; then
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$type] $message" | tee -a ./install.log
		else
			echo "$(date +"%Y-%m-%d %H:%M:%S") [$type] $message" >>./install.log
		fi
	else
		echo "$(date +"%Y-%m-%d %H:%M:%S") [$type] $message" >>./install.log
	fi
}

# Default values
SILENT=false
URL=""
USERNAME=""
PASSWORD=""
INVENTORY_MODE=""
LOG_LEVEL=""
CERTIFICATE=""
SERVICE=false
NOW=false # if true, we run the agent now with mode 2

# options
SHORT_OPTS="hSnU:u:p:m:l:c:s"
LONG_OPTS="help,silent,now,url:,username:,password:,mode:,log-level:,certificate:,service"

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
	-U | --url)
		URL="$2"
		shift 2
		;;
	-u | --username)
		USERNAME="$2"
		shift 2
		;;
	-p | --password)
		PASSWORD="$2"
		shift 2
		;;
	-m | --mode)
		INVENTORY_MODE="$2"
		shift 2
		;;
	-l | --log-level)
		LOG_LEVEL="$2"
		shift 2
		;;
	-c | --certificate)
		CERTIFICATE="$2"
		shift 2
		;;
	-s | --service)
		SERVICE=true
		shift
		;;
	-n | --now)
		NOW=true
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

# Function to check if the mandatory parameters are provided correctly during silent mode
check_silent_parameters() {
	if [ -z "$URL" ]; then
		log "ERROR" "Server URL is required in silent mode (-U, --url)" false
		usage
	fi

	if [ -z "$USERNAME" ]; then
		log "ERROR" "Username is required in silent mode (-u, --username)" false
		usage
	fi

	if [ -z "$PASSWORD" ]; then
		log "ERROR" "Password is required in silent mode (-p, --password)" false
		usage
	fi

	if [ -z "$LOG_LEVEL" ]; then
		log "WARNING" "Log level not provided, using default value 2 (Info)" true
		LOG_LEVEL=2
	fi

	if [ -z "$INVENTORY_MODE" ]; then
		log "WARNING" "Inventory mode not provided, using default value 1 (Remote with template)" true
		INVENTORY_MODE=1
	fi

	if [ -z "$CERTIFICATE" ]; then
		log "WARNING" "Certificate not provided, using default value null"
	fi

	if [ "$NOW" = "false" ]; then
		log "WARNING" "Run now option not provided, using default value false (do not run immediately)" true
	fi

	if [ "$SERVICE" = "false" ]; then
		log "WARNING" "Service registration not provided, using default value false (do not register as service)" true
	fi
}

# Function to check if the agent is already installed
check_installed_agent() {
	# Check if any standard agent installation artifacts exist
	if [ -d "$AGENT_INSTALLATION_DIR" ] || [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ] || [ -d "$CONFIG_PATH" ] || [ -f "$LOG_PATH" ]; then
		# check if running in silent mode
		if [ "$SILENT" = "true" ]; then
			log "INFO" "Existing agent installation detected in silent mode. Automatically uninstalling..." false
			# automatically uninstall in silent mode
			sh "${WORKING_DIRECTORY}/uninstall.sh" -S -y
		else
			# prompt the user in interactive mode
			echo -n "The agent is already installed, do you want to remove it first? ([y]/n) "
			read -r remove_choice
			log "INFO" "The agent is already installed, do you want to remove it first? ([y]/n) $remove_choice" true
			if [[ "$remove_choice" =~ ^[yY]?$  ]]; then
				log "INFO" "Uninstalling the existing agent..." false
				sh "${WORKING_DIRECTORY}/uninstall.sh" -y
			# if the user chose, we inform them the script will likely overwrite files
			else
				log "INFO" "Proceeding with installation without removing the existing one. Files may be overwritten." false
			fi
		fi
	fi
}

# Function to copy agent contents to /usr/share/ocsinventory-agent
copy_agent_contents() {
	check_installed_agent
	
	# Define the source directory by navigating three levels up from the script directory
	SOURCE_DIR="$WORKING_DIRECTORY/../../"

	# Create the target directory if it does not exist
	mkdir -p "$AGENT_INSTALLATION_DIR"

	# Copy all the contents from the source directory to the target directory
	cp -r "$SOURCE_DIR"/* "$AGENT_INSTALLATION_DIR"

	chmod +x "$AGENT_INSTALLATION_DIR$WORKING_DIRECTORY_EXEC_PATH$EXEC_AGENT"
	chmod +x "$AGENT_INSTALLATION_DIR$WORKING_DIRECTORY_EXEC_PATH$SERVICE_EXEC"

	# Link the exec agent to /usr/bin
	if ln -s "$AGENT_INSTALLATION_DIR$WORKING_DIRECTORY_EXEC_PATH$EXEC_AGENT" "$SYMBOLIC_LINK" >/dev/null 2>/dev/null; then
		log "INFO" "Symbolic link created successfully at $SYMBOLIC_LINK" false
	else
		log "ERROR" "Failed to create symbolic link at $SYMBOLIC_LINK. Exiting script." false
		exit 1
	fi
}

# Function to create the config file with provided params
create_config_file() {
	# Construct config directory and file
	log "INFO" "Creating configuration file..." false
	mkdir -p "$CONFIG_PATH"
	touch "$CONFIG_PATH/config.json"
	echo "
	{
		\"log_file\": true,
		\"mode\": $INVENTORY_MODE,
		\"password\": \"$PASSWORD\",
		\"username\": \"$USERNAME\",
		\"url\": \"$URL\",
		\"data_directory\": \"$STORE_DATA_PATH\",
		\"log_file_path\": \"$LOG_PATH\",
		\"log_level\": $LOG_LEVEL,
		\"certificate\": \"$CERTIFICATE\"
		\"bypass_certificate\": false
	}" >"$CONFIG_PATH/config.json"
}

create_log_file() {
	log "INFO" "Creating log file..." false
	mkdir -p "$(dirname "$LOG_PATH")"
	touch "$LOG_PATH"
}

# Function to run the executable with provided params
run_executable() {
	if [ "$NOW" = "true" ]; then
		log "INFO" "Running the agent now..." false
		command="$WORKING_DIRECTORY$EXEC_AGENT -f true -m $INVENTORY_MODE -p $PASSWORD -u $USERNAME -s $URL -l $LOG_PATH -d $STORE_DATA_PATH -v $LOG_LEVEL -c $CERTIFICATE"
		$command
	fi
}

# Function to register service
register_service() {
	# create service file
	log "INFO" "Creating service file..." false
	cp "${WORKING_DIRECTORY}/ocsinventory-agent.service" "/etc/systemd/system/${SERVICE_NAME}.service"

	# restart daemon, enable and start service
	log "INFO" "Reloading daemon and enabling service" false
	systemctl daemon-reload
	systemctl enable ${SERVICE_NAME}.service
	systemctl start ${SERVICE_NAME}.service
	log "INFO" "Service Started" false
}

# Function to run in silent mode
run_silent() {
	log "INFO" "+---------------------------------------------------------+" false
	log "INFO" "|                                                         |" false
	log "INFO" "|     Installing OCSInventory Agent in silent mode...     |" false
	log "INFO" "|                                                         |" false
	log "INFO" "+---------------------------------------------------------+" false
	log "INFO" "" false

	check_silent_parameters
	copy_agent_contents
	create_config_file
	create_log_file
	run_executable
}

# Function to run in interactive mode
run_interactive() {
	log "INFO" "+--------------------------------------------------------------+" false
	log "INFO" "|                                                              |" false
	log "INFO" "|     Installing OCSInventory Agent in interactive mode...     |" false
	log "INFO" "|                                                              |" false
	log "INFO" "+--------------------------------------------------------------+" false
	log "INFO" "" false

	if [ -z "$URL" ]; then
		echo -n "Enter server URL: "
		read -r URL
		while [[ ! "$URL" =~ ^https?:// ]]; do
			echo -n "Invalid URL format. Please enter a valid URL (starting with http:// or https://): "
			read -r URL
		done
		log "INFO" "Server URL: $URL" true
	fi

	if [ -z "$USERNAME" ]; then
		echo -n "Enter username: "
		read -r USERNAME
		while [[ ! "$USERNAME" =~ ^[a-zA-Z0-9._-]+$ ]]; do
			echo -n "Invalid username format. Please enter a valid username (alphanumeric characters, dots, underscores, and hyphens allowed): "
			read -r USERNAME
		done
		log "INFO" "User has written a username." true
	fi

	if [ -z "$PASSWORD" ]; then
		echo -n "Enter password: "
		read -r PASSWORD
		while [ "$PASSWORD" = "" ]; do
			echo -n "Invalid password format. Please enter a valid password (alphanumeric and special characters allowed): "
			read -r PASSWORD
		done
		log "INFO" "User has written a password." true
	fi

	if [ -z "$INVENTORY_MODE" ]; then
		echo -n "Enter the inventory mode (leave empty if default, default is 1 = Remote with template): "
		read -r INVENTORY_MODE
		if [ "$INVENTORY_MODE" = "" ]; then
			INVENTORY_MODE=1
		else
			if [[ ! "$INVENTORY_MODE" =~ ^[0-9]+$ ]]; then
				log "INFO" "Inventory mode must be a number, using default value 1 (Remote with template)" true
				INVENTORY_MODE=1
			fi
		fi
		log "INFO" "Inventory mode: $INVENTORY_MODE" true
	fi

	if [ -z "$LOG_LEVEL" ]; then
		echo -n "Enter the log level (leave empty if default, default is 2 = Info): "
		read -r LOG_LEVEL
		if [ "$LOG_LEVEL" = "" ]; then
			LOG_LEVEL=2
		else 
			if [[ ! "$LOG_LEVEL" =~ ^[0-9]+$ ]]; then
				log "INFO" "Log level must be a number, using default value 2 (Info)" true
				LOG_LEVEL=2
			fi
		fi
		log "INFO" "Log level: $LOG_LEVEL" true
	fi

	if [ -z "$CERTIFICATE"]; then
		echo -n "Enter the certificate path (leave empty if none): "
		read -r CERTIFICATE
		if [ "$CERTIFICATE" = "" ]; then
			CERTIFICATE="none"
		fi
		log "INFO" "Certificate path: $CERTIFICATE" true
	fi

	if [ "$SERVICE" = "false" ]; then
		echo -n "Should the agent be registered as a systemd service? ([y]/n) "
		read -r service_choice
		log "INFO" "Should the agent be registered as a systemd service? ([y]/n) $service_choice" true
		if [[ "$service_choice" =~ ^[yY]?$ ]]; then
			SERVICE=true
		fi
	fi

	if [ "$NOW" = "false" ]; then
		echo -n "Do you want the agent to run immediately after installation? ([y]/n) "
		read -r now_choice
		log "INFO" "Do you want the agent to run immediately after installation? ([y]/n) $now_choice" true
		if [[ "$now_choice" =~ ^[yY]?$ ]]; then
			NOW=true
		fi
	fi

	copy_agent_contents
	create_config_file
	create_log_file
	run_executable
}

# Run in the appropriate mode
if [ "$SILENT" = "true" ]; then
	run_silent
else
	run_interactive
fi

# Check if all are created successfully
if [ -d "$CONFIG_PATH" ] && [ -f "$LOG_PATH" ] && [ -d "$AGENT_INSTALLATION_DIR" ] && [ -f "$SYMBOLIC_LINK" ]; then
	if [ "$SERVICE" = "true" ]; then
		register_service
	fi
	log "INFO" "" false
	log "INFO" "+------------------------------------------------------------------------------------------------+" false
	log "INFO" "|               OCSInventory Agent has been successfully installed and configured.               |" false
	log "INFO" "|                                                                                                |" false
	log "INFO" "|          Configuration files are located at $CONFIG_PATH" false
	log "INFO" "|          Log file is located at $LOG_PATH" false
	log "INFO" "|          Agent data storage is located at $STORE_DATA_PATH" false
	log "INFO" "|          Agent installation directory is located at $AGENT_INSTALLATION_DIR" false
	log "INFO" "|                                                                                                |" false
	log "INFO" "|               Please refer to the documentation for more information.                          |" false
	log "INFO" "+------------------------------------------------------------------------------------------------+" false

else
	log "INFO" "" false
	log "INFO" "*** ERROR: Installation failed, please check the logs for more information" false
	log "INFO" "" false
	log "INFO" "Installation aborted !" false
	exit 1
fi

exit 0
