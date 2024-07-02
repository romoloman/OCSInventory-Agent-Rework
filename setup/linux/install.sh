#!/bin/bash

# Constants
WORKING_DIRECTORY=$(dirname "$(realpath "$0")")
WORKING_DIRECTORY_EXEC_PATH="/setup/linux"
EXEC_AGENT="/AGENT-LINUX"
CONFIG_PATH="/etc/ocsinventory-agent"
LOG_PATH="/var/log/ocsinventory-agent/ocsinventory-agent.log"
STRORE_DATA_PATH="/var/lib/ocsinventory-data"
SERVICE_NAME="ocsinventory-agent"
SERVICE_DESCRIPTION="OCS Inventory Agent"
SERVICE_EXEC="/DAEMON-LINUX"
AGENT_INSTALLATION_DIR="/usr/share/ocsinventory-agent"
SYMBOLIC_LINK="/usr/bin/ocsinventory-agent-ng"

# Function to display usage information
usage() {
	echo "Usage: $0 [-h URL] [-u USERNAME] [-p PASSWORD] [-v LOG_LEVEL ] [-l] [-s] [-n] [-h]"
	echo "  -h HOST       host URL of the OCS Inventory NG server"
	echo "  -u USERNAME   Username"
	echo "  -p PASSWORD   Password"
	echo "  -v LOG_LEVEL  Log level"
	echo "  -l            Local mode (do not register service)"
	echo "  -s            Service mode (register service)"
	echo "  -n            Run the agent now"
	exit 1
}

# Default values
SILENT=false
LOCAL=false
SERVICE=false
NOW=false # if true, we run the agent now with mode 2

# Parse command-line arguments
while getopts "h:u:p:v:lsnih" opt; do
	case ${opt} in
	h) URL=$OPTARG ;;
	u) USERNAME=$OPTARG ;;
	p) PASSWORD=$OPTARG ;;
	v) LOG_LEVEL=$OPTARG ;;
	l) LOCAL=true ;;
	s) SERVICE=true ;;
	n) NOW=true ;;
	*) usage ;;
	esac
done

# Function to check if the parameters are provided
check_parameters() {
	local url="$1"
	local username="$2"
	local password="$3"

	if [ -z "$url" ]; then
		echo "Server URL is required"
		usage
	fi
	if [ -z "$username" ]; then
		echo "Username is required"
		usage
	fi
	if [ -z "$password" ]; then
		echo "Password is required"
		usage
	fi
}
# Function to check if the agent is alread -ry installed
check_installed_agent() {
	if [ -d "$AGENT_INSTALLATION_DIR" ] || [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ] || [ -d "$CONFIG_PATH" ] || [ -f "$LOG_PATH" ]; then
		echo -n "The agent is alread -ry installed, do you want to remove it first ? (y/n) "
		read -r remove_choice
		if [ "$remove_choice" = "y" ] || [ "$remove_choice" = "Y" ]; then
			echo "Uninstalling the existing agent..."
			sudo sh "${WORKING_DIRECTORY}/uninstall.sh" -y
		fi
	fi
}

# Check if the agent is alread -ry installed
check_installed_agent

# Function to copy agent contents to /usr/share/ocsinventory-agent
copy_agent_contents() {

	# Define the source directory by navigating three levels up from the script directory
	SOURCE_DIR="$WORKING_DIRECTORY/../../"

	# Create the target directory if it does not exist
	mkdir -p "$AGENT_INSTALLATION_DIR"

	# Copy all the contents from the source directory to the target directory
	cp -r "$SOURCE_DIR"/* "$AGENT_INSTALLATION_DIR"

	chmod +x "$AGENT_INSTALLATION_DIR$WORKING_DIRECTORY_EXEC_PATH$EXEC_AGENT"
	chmod +x "$AGENT_INSTALLATION_DIR$WORKING_DIRECTORY_EXEC_PATH$SERVICE_EXEC"

	# Link the exec agent to /usr/bin
	sudo ln -s "$AGENT_INSTALLATION_DIR$WORKING_DIRECTORY_EXEC_PATH$EXEC_AGENT" "$SYMBOLIC_LINK"

}

# Function to run the executable with provided params
run_executable() {
	local url="$1"
	local username="$2"
	local password="$3"
	local log_level="$4"
	local run_now="$5"

	# Construct command for running executable
	command_install="$WORKING_DIRECTORY$EXEC_AGENT -f true -m 0 -p $password -u $username -s $url -l $LOG_PATH -d $STRORE_DATA_PATH -v $log_level"
	# echo "Executing command: $command"
	$command_install

	if [ "$run_now" = "true" ]; then
		echo "Running the agent now..."
		command_run="$WORKING_DIRECTORY$EXEC_AGENT -f true -m 2 -p $password -u $username -s $url -l $LOG_PATH -d $STRORE_DATA_PATH -v $log_level"
		$command_run
	fi
}

# Function to register service
register_service() {
	# create service file
	echo "Creating ${SERVICE_NAME} service file..."
	sudo tee "/etc/systemd/system/${SERVICE_NAME}.service" >/dev/null <<EOF
[Unit]
Description=${SERVICE_DESCRIPTION}
After=network.target

[Service]
ExecStart=${AGENT_INSTALLATION_DIR}${WORKING_DIRECTORY_EXEC_PATH}${SERVICE_EXEC}
User=root
Group=root
RestartSec=60
StartLimitInterval=1800
StartLimitBurst=3
WorkingDirectory=${AGENT_INSTALLATION_DIR}${WORKING_DIRECTORY_EXEC_PATH}

# Ensure that PID file and logging directories are set if needed
PIDFile=/var/run/${SERVICE_NAME}.pid
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target
EOF
	# restart daemon, enable and start service
	echo "Reloading daemon and enabling service"
	sudo systemctl daemon-reload
	sudo systemctl enable ${SERVICE_NAME}.service
}

# Function to run in silent mode
run_silent() {
	echo
	echo "+----------------------------------------------------------+"
	echo "|                                                          |"
	echo "|  Welcome to OCS Inventory NG Agent in silent mode... !   |"
	echo "|                                                          |"
	echo "+----------------------------------------------------------+"
	echo

	check_parameters "$URL" "$USERNAME" "$PASSWORD"
	copy_agent_contents
	run_executable "$URL" "$USERNAME" "$PASSWORD" "$LOG_LEVEL" "$NOW"
	if [ "$SERVICE" = "true" ] && [ "$LOCAL" = "false" ]; then
		register_service
	fi
}

# Function to run in interactive mode
run_interactive() {
	echo
	echo "+---------------------------------------------------------------+"
	echo "|                                                               |"
	echo "|  Welcome to OCS Inventory NG Agent in interactive mode... !   |"
	echo "|                                                               |"
	echo "+---------------------------------------------------------------+"
	echo
	echo -n "Enter server URL: "
	read -r URL
	echo -n "Enter username: "
	read -r USERNAME
	echo -n "Enter password: "
	read -r PASSWORD
	echo -n "Enter the log level (default is 2 = Info): "
	read -r LOG_LEVEL
	echo -n "Do you register the service - agent must be launched automatically (y/n)? "
	read -r service_choice
	if [ "$service_choice" = "y" ] || [ "$service_choice" = "Y" ]; then
		SERVICE=true
	else
		LOCAL=true
	fi
	echo -n "Do you want to run the agent now (y/n)? "
	read -r now_choice
	if [ "$now_choice" = "y" ] || [ "$now_choice" = "Y" ]; then
		NOW=true
	fi

	check_parameters "$URL" "$USERNAME" "$PASSWORD"
	copy_agent_contents
	run_executable "$URL" "$USERNAME" "$PASSWORD" "$LOG_LEVEL" "$NOW"
	if [ "$SERVICE" = "true" ]; then
		register_service
	fi
}

# Check if all required parameters are provided for silent mode
if [ -n "$URL" ] && [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
	SILENT=true
fi

# Run in the appropriate mode
if [ "$SILENT" = "true" ]; then
	run_silent
else
	run_interactive
fi

# Check if all are created successfully
if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ] && [ -d "$CONFIG_PATH" ] && [ -f "$LOG_PATH" ]; then
	echo
	echo "+------------------------------------------------------------------------------+"
	echo "|   OK, OCS Inventory NG Agent for Unix/Linux has been successfully            |"
	echo "|                    installed and configured.                                 |"
	echo "|                                                                              |"
	echo "|   Configuration files are located in /etc/ocsinventory-agent                 |"
	echo "|   Log file is located in /var/log/ocsinventory-agent/ocsinventory-agent.log  |"
	echo "|   Store Data Path is located in /var/lib/ocsinventory-data                   |"
	echo "|   Agent Installation Directory is located in /usr/share/ocsinventory-agent   |"
	echo "|                                                                              |"
	echo "|                                                                              |"
	echo "|   Enjoy OCS Inventory NG Agent ;-)                                           |"
	echo "+------------------------------------------------------------------------------+"
	echo

else
	echo "The agent installation failed"
fi

exit 0
