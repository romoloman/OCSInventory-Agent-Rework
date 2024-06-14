#!/bin/sh

# Constants
WORKING_DIRECTORY=$(dirname "$(readlink -f "$0")")
WORKING_DIRECTORY_EXEC_PATH="/lib/app"
EXEC_AGENT="/agent_unix_ocs"
CONFIG_PATH="/etc/Ocsinventory-agent"
LOG_PATH="/var/log/ocsinventory-agent.log"
STRORE_DATA_PATH="/var/lib/Ocsinventory-data"
SERVICE_NAME="OCS-Inventory-Agent"
SERVICE_DESCRIPTION="OCS Inventory Agent"
SERVICE_EXEC="/daemon_agent"


# Function to display usage information
usage() {
    echo "Usage: $0 [-u URL] [-n USERNAME] [-p PASSWORD] [-l] [-s] [-h]"
    echo "  -u URL        Server URL"
    echo "  -n USERNAME   Username"
    echo "  -p PASSWORD   Password"
    echo "  -l            Local mode (do not register service)"
    echo "  -s            Service mode (register service)"
    echo "  -w            Working directory"
    echo "  -h            Display this help message"
    exit 1
}

# Default values
SILENT=false
LOCAL=false
SERVICE=false

# Parse command-line arguments
while getopts "u:n:p:lsih" opt; do
    case ${opt} in
        u ) URL=$OPTARG ;;
        n ) USERNAME=$OPTARG ;;
        p ) PASSWORD=$OPTARG ;;
        l ) LOCAL=true ;;
        s ) SERVICE=true ;;
        h ) usage ;;
        * ) usage ;;
    esac
done

# Function to read password securely but not yet used
secure_read_password() {
    # Save current terminal settings
    old_stty_settings=$(stty -g)
    # Turn off echo
    stty -echo
    printf "Enter password: "
    # Read password
    read PASSWORD
    # Turn echo back on
    stty "$old_stty_settings"
    printf "\n"
}

# Function to run the executable with provided params
run_executable() {
    local url="$1"
    local username="$2"
    local password="$3"

    # Construct command for running executable
    command=".$WORKING_DIRECTORY_EXEC_PATH$EXEC_AGENT -f true -m 0 -p $password -u $username -s $url -l $LOG_PATH -d $STRORE_DATA_PATH"

    # echo "Executing command: $command"
   
    $command
}

# Function to register service
register_service() {
    # create service file
    echo "Creating $SERVICE_NAME service file..."
    sudo cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=$SERVICE_DESCRIPTION
After=network.target

[Service]
ExecStart=$WORKING_DIRECTORY$WORKING_DIRECTORY_EXEC_PATH$SERVICE_EXEC -d $WORKING_DIRECTORY$WORKING_DIRECTORY_EXEC_PATH
User=root
Group=root
RestartSec=60
StartLimitInterval=1800
StartLimitBurst=3
WorkingDirectory=$WORKING_DIRECTORY$WORKING_DIRECTORY_EXEC_PATH

# Ensure that PID file and logging directories are set if needed
PIDFile=/var/run/$SERVICE_NAME.pid
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target
EOF
    # restart daemon, enable and start service
    echo "Reloading daemon and enabling service"
    sudo systemctl daemon-reload 
    sudo systemctl enable ${SERVICE_NAME}.service
    sudo systemctl start ${SERVICE_NAME}.service
    echo "Service Started"
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

    run_executable "$URL" "$USERNAME" "$PASSWORD"
    if [ "$SERVICE" = "true" ]; then
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
    read URL
    echo -n "Enter username: "
    read USERNAME
    echo -n "Enter password: "
    read PASSWORD
    echo -n "Do you register the service - agent must be launched automatically (y/n)? "
    read service_choice
    if [ "$service_choice" = "y" ] || [ "$service_choice" = "Y" ]; then
        SERVICE=true
    else
        LOCAL=true
    fi
    run_executable "$URL" "$USERNAME" "$PASSWORD"
    if [ "$SERVICE" = "true" ]; then
        register_service
    fi
}

# Check if all required parameters are provided for silent mode
if [ ! -z "$URL" ] && [ ! -z "$USERNAME" ] && [ ! -z "$PASSWORD" ]; then
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
    echo "+----------------------------------------------------------------------+"
	echo "|   OK, OCS Inventory NG Agent for Unix/Linux has been successfully    |"
    echo "|                    installed and configured.                         |"
    echo "|                                                                      |"
    echo "|   Configuration files are located in /etc/Ocsinventory-agent         |"
    echo "|   Log file is located in /var/log/ocsinventory-agent.log             |"
    echo "|   Store Data Path is located in /var/lib/Ocsinventory-data           |"
    echo "|                                                                      |"
    echo "|                                                                      |"
    echo "|                                                                      |"
    echo "|   Enjoy OCS Inventory NG Agent ;-)                                   |"
	echo "+----------------------------------------------------------------------+"
	echo
	
else
    echo "The agent installation failed"
fi


exit 0