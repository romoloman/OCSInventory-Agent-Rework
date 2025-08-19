# Getting started

## Table of Contents
- [Getting started](#getting-started)
  - [Table of Contents](#table-of-contents)
  - [Step 1: Flutter installation](#step-1-flutter-installation)
    - [Download Flutter packages](#download-flutter-packages)
    - [Add Flutter application to path](#add-flutter-application-to-path)
  - [Step 2: Clone of the project](#step-2-clone-of-the-project)
  - [Step 3: Getting dependencies](#step-3-getting-dependencies)
  - [Step 4: Installing the Agent](#step-4-installing-the-agent)
    - [Installing the agent on Linux](#installing-the-agent-on-linux)
      - [1. Compilation](#1-compilation)
      - [2. Installing the agent non-interactively](#2-installing-the-agent-non-interactively)
      - [3. Installing the agent interactively](#3-installing-the-agent-interactively)
      - [4. Additionnal information](#4-additionnal-information)
    - [Installing the agent on Windows](#installing-the-agent-on-windows)
      - [1. Compilation](#1-compilation-1)
      - [2. Create your own package](#2-create-your-own-package)
      - [3. Installing the agent non-interactively](#3-installing-the-agent-non-interactively)
      - [4. Installing the agent interactively](#4-installing-the-agent-interactively)
      - [5. Additionnal information](#5-additionnal-information)
    - [Installing the agent on MacOS](#installing-the-agent-on-macos)
      - [1. Compilation](#1-compilation-2)
      - [2. Create your own package](#2-create-your-own-package-1)
      - [3. Installing the agent non-interactively](#3-installing-the-agent-non-interactively-1)
      - [4. Installing the agent interactively](#4-installing-the-agent-interactively-1)
      - [5. Additionnal information](#5-additionnal-information-1)
  - [Step 5: Agent configuration](#step-5-agent-configuration)
    - [Linux and macos](#linux-and-macos)
    - [Windows](#windows)
    - [SSL](#ssl)
  - [Step 6: Uninstalling the agent](#step-6-uninstalling-the-agent)
  - [Step 7: Troubleshooting](#step-7-troubleshooting)

## Step 1: Flutter installation

### Download Flutter packages

Begin to download the Flutter package by clicking on the big blue button in `Manual install` section on these websites:

- [Linux Installation](https://docs.flutter.dev/get-started/install/linux/desktop#install-the-flutter-sdk)
- [MacOS Installation](https://docs.flutter.dev/get-started/install/macos/desktop#install-the-flutter-sdk)
- [Windows Installation](https://docs.flutter.dev/get-started/install/windows/desktop#install-the-flutter-sdk)

### Add Flutter application to path

To add flutter to path, click on this [flutter documentation link](https://docs.flutter.dev/install/add-to-path), choose your OS and follow the instructions.

## Step 2: Clone of the project

```
git clone https://github.com/OCSInventory-NG/OCSInventory-Agent-Rework.git
```

or with SSH

```
git clone git@github.com:OCSInventory-NG/OCSInventory-Agent-Rework.git
```

## Step 3: Getting dependencies

Go to the agent directory and run this command :

```
flutter pub get
```

## Step 4: Installing the Agent

### Installing the agent on Linux

#### 1. Compilation

Go to the linux setup directory: `/setup/linux/` from the repository cloned above.
You need to compile the entry point `/lib/app/app.dart` using the following command

```
dart compile exe /path of your project/OCSInventory-Agent-Rework/lib/app/app.dart -o ocsinventory-agent
```

Ensure that you have something like this in the linux setup directory:

```
├── ocsinventory-agent
├── ocsinventory-agent.service
├── install.sh
└── uninstall.sh
```

#### 2. Installing the agent non-interactively

To install the agent in non-interactive mode, you have to run the linux `install.sh` script with a set of launch arguments to allow to set all configuration options as you can do in interactive mode.
This is a list of all available `install.sh` script arguments:

```
-S, --silent                          Enable silent mode (requires --url --username, --password)
-U, --url URL                         URL of the OCSInventory server (required for silent mode)
-u, --username USERNAME               Username (required for silent mode)
-p, --password PASSWORD               Password (required for silent mode)
-m, --mode MODE                       Inventory mode (default: 1 = Remote with template)
-d, --data-path PATH                  Path to the data directory (default: /var/lib/ocsinventory-data)
-l, --log-level LEVEL                 Log level (default: 2 = Info)
    --log-file                        Enable log file (default: false)
    --log-file-path PATH              Path to the log file (default: /var/log/ocsinventory-agent/ocsinventory-agent.log)
-c, --certificate CERTIFICATE         Path to the certificate file (default: null)
    --bypass-certificate              Bypass certificate validation (default: false)
-s, --service                         Register the agent as a systemd service
-n, --now                             Run the agent inventory immediately after installation
-h, --help                            Display this help message
```

Here an example command to use the installation script in non-interactive mode (silent disabled):
```
sudo sh install.sh -U Server_ip_and_port -u username -p password -m 1 -l 4 -s -n -c -c /path of the certificate/cert.pem
```
> *NOTE: This command will install a new agent with inventory mode at "inventory with template", the default log level "INFO", install the service to run the agent periodicly and start automaticly an inventory after the installation.*

#### 3. Installing the agent interactively

To install the agent in interactive mode, you have to run the `install.sh` script with root privileges.
If the agent configuration is already exist, it will ask you to remove it before installing the agent.

For the server URL field, the expected URL is `http(s)://<Server ip:port>`

#### 4. Additionnal information

When the installation finished successfully, you can use the command ocsinventory-cli to run the agent as CLI. You can use this command with arguments above to run a single custom instance of the agent.

For example, if you want to run the agent and set log level to "ERROR" for a single instance, you have to run this command:

```
sudo ocsinventory-agent-ng -l 2
```

> *NOTE: If you set the service installation to true, it will be stored in `/etc/systemd/system/ocsinventory-agent.service`*

### Installing the agent on Windows

#### 1. Compilation

Go to the windows setup directory: `/setup/windows/` from the repository cloned above.
You need to compile the entry point `/lib/app/app.dart` using the following command

```
dart compile exe /path of your project/OCSInventory-Agent-Rework/lib/app/app.dart -o ocsinventory-agent.exe
```

Ensure that you have something like this in the windows setup directory:

```
├── OCSInventory-Service/
├── ocsinventory-agent.exe
└── Setup OCS Inventory Agent.iss
```

#### 2. Create your own package

You can create your package (if needed) with Inno setup by using `Setup OCS Inventory Agent.iss` script

- Download and install Inno Setup. You can download it from [here](https://jrsoftware.org/isdl.php).
- Run Inno Setup and open the `Setup OCS Inventory Agent.iss` script
- Set up the script, specifying the `AppPath` as your cloned repository path
- Build the package using Inno Setup's build feature
- The resulting installer will be created in `/setup/windows/` directory as ̀`OCSInventory-Agent-Setup/OCSInventory-Agent-Setup-{#AppVersion}`

> *NOTE: Even if you're not planing to use the service, you'll have to build the service with a C# compiler. Otherwise you can manually remove the service part in the inno setup install script.*

#### 3. Installing the agent non-interactively

To install the agent in non-interactive mode, you have to run the binary setup generated above with a set of launch arguments to allow to set all configuration options as you can do in interactive mode.
This is a list of all available arguments:
```
/VERYSILENT                 Enable silent mode (requires /URL /USERNAME, /PASSWORD)
/URL=url                    URL of the OCSInventory server
/USERNAME=username          Username (required for silent mode)
/PASSWORD=password          Password (required for silent mode)
/MODE=mode                  Inventory mode (default: 1 = Remote with template)
/LOG_LEVEL=level            Log level (default: 4 = Info)
/CERTIFICATE=path           Path to the certificate file (default: null)
/SERVICE=boolean            Register the agent as a windows service
/NOW=boolean                Run the agent inventory immediately after installation
```

Here an example command to use the installation script in non-interactive mode (silent enabled):

```
mysetup-agent.exe /VERYSILENT /URL=Server_ip_and_port /USERNAME=username /PASSWORD=password /MODE=1 /LOGLEVEL=4 /CERTIFICATE="\path of the certificate\cert.pem" /SERVICE=True /NOW=True 
```

#### 4. Installing the agent interactively

To install the agent in interactive mode, you have to run the binary setup generated above and set all configuration fields.

#### 5. Additionnal information

If you set service installation to true, it will be in service and named `OCSInventory-Service`. The location of this service is store at the same location as the agent installation directory.

### Installing the agent on MacOS

#### 1. Compilation

Go to the linux setup directory: `/setup/macos/`
You need to compile the entry point `app.dart` and the daemon `daemon.dart` using the following command

```
dart compile exe /path of your project/OCSInventory-Agent-Rework/lib/app/app.dart -o AGENT-MACOS
dart compile exe /path of your project/OCSInventory-Agent-Rework/lib/app/daemon.dart -o DAEMON-MACOS
```

#### 2. Create your own package

You can create your package (if needed) with Xcode and Package applications.

- Build `config-agent-ocs` and copy the bundle file into `OCS Inventory Agent setup` directory
- Build `ocsng_app-xcode` to create OCS-NG pkg and ocscontact. Ensure the Scheme is correct to build each of them
- Build `OCS Inventory Agent setup` to create installation package

Ensure that you have something like this:

```
├── AUTHORS
├── Changes
├── AGENT-MACOS
├── DAEMON-MACOS
├── LICENCE.txt
├── OCS Inventory Agent setup
│   ├── build
│   │   └── OCS Inventory Agent Setup.mpkg
│   ├── config-agent-ocs.bundle
│   ├── OCS Inventory Agent.pkgproj
│   └── scripts
├── ocsng_app-xcode
│   ├── build
│   │   └── build
│   │       └── ocscontact
│   │       └── OCS-NG
│   ├── en.lproj
│   ├── ...
├── README.md
├── scripts
├── setup plugins
│ └── config-agent-ocs
└── THANKS
```

#### 3. Installing the agent non-interactively

To install the agent in non-interactive mode, you have to run the MacOS `install.sh` script with a set of launch arguments to allow to set all configuration options as you can do in interactive mode.
This is a list of all available `install.sh` script arguments:

- -l : set link of the OCS Inventory NG server
- -u : set username
- -p : set password
- -v : set level of the log
- -s : set service mode (register service)
- -n : set to run the agent now
- -c : set certificate path

For example, if you want to install OCS Inventory Agent in non-interactive mode and set server adress, set password, set username, set log level, register the service and run the agent now, you have to run this command:

```
sudo sh install.sh -l Server_ip_and_port -u username -p password -v 3 -s -n -c -c /path of the certificate/cert.pem
```

#### 4. Installing the agent interactively

To install the agent in interactive mode, you have to run the `OCS Inventory Agent.mpkg` package and set all configuration fields.

#### 5. Additionnal information

- The is installed in `/Applications/OCS-NG`

- If you set up the service, it will be in `/Library/LaunchDaemons/org.ocsinventory.agent.plist`

## Step 5: Agent configuration

### Linux and macos

- Configuration directory : `/etc/ocsinventory-agent`
- Default log file in directory : `/var/log/ocsinventory-agent/ocsinventory-agent.log`
- Default Data inventories : `/var/lib/ocsinventory-data`

### Windows

- Configuration directory, log file and data inventories are in the same directory : `C:\ProgramData\OCSInventory-Agent\`

After installing the agent, there is a config forlder and the file `config.json` inside.

In this file, there are properties to configure the agent:

| Property           | Description                                                                                                                                                          |
|:-------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| url                | Backend server api url.                                                                                                                                              |
| username           | By default in remote inventory mode, set the username to connect to the backend server api.                                                                          |
| password           | By default in remote inventory mode, set the password to connect to the backend server api.                                                                          |
| mode               | This is the working mode property of the agent, there is 4 modes: 1-Remote with template 2- Remote without template 3- Local with template 4- Local without template |
| data_directory     | Folder where the agent will store inventory data.                                                                                                                    |
| log_level          | 0: Critical 1: Error 2: Warning 3: Info  4: Debug                                                                                                                    |
| log_file           | File where to logs will be written. Set to false, logs will be written in the terminal.                                                                              |
| log_file_path      | This property is to set the log file path. Only define it if you put log_file to true.<br>**Warning**: It will not create the file. You'll need to create it.        |
| certificate        | Specify the path to the certificate file (.pem)                                                                                                                      |
| bypass_certificate | Bypass certificate verification (false by default)                                                                                                                   |

```
{
    "url": "Server ip and port",
    "username": "username",
    "password": "password",
    "mode": 2,
    "log_level": 3,
    "log_file": true,
    "log_file_path": "/var/log/ocsinventory-agent/ocsinventory-agent.log",
    "data_directory": "/var/lib/ocsinventory-data",
    "certificate": "/certificate path/file_name.pem",
    "bypass_certificate": false
}
```

### SSL

- HTTP

If your OCS Inventory backend is running with the HTTP protocol, you do not need a certificate file to install the agent.

- HTTPS

If your OCS Inventory backend is running with the HTTPS protocol, you must have a certificate file, even if it is self-signed, to install the agent.

You can bypass SSL certificate verification (if the certificate is self-signed) by running the agent with the `-b true` option or by setting the `bypass_certificate` value to true in the configuration file.

## Step 6: Uninstalling the agent

- Linux Agent: To uninstall the Linux agent, navigate to `/usr/share/ocsinventory-agent/setup/linux/` and execute the `uninstall.sh` script with root privileges.
- Windows Agent: To uninstall the Windows agent, go to `C:\Program Files\OCSInventory-Agent\` and run the `uninstall application` executable.
- MacOS Agent: To uninstall the macOS agent, navigate to `/Applications/OCS-NG.app/Contents/Resources/` and execute the `uninstaller.sh` script with root privileges.

## Step 7: Troubleshooting

If you encounter any issues during the installation or usage of the OCS Inventory Agent, here are some troubleshooting steps you can follow:

1. Check the log files: The agent logs can provide valuable information about any errors or issues. You can find the log files in the `/var/log/ocsinventory-agent/` directory on Linux, `C:\Program Files\OCSInventory-Agent\` directory on Windows, and `/Applications/OCS-NG/logs` directory on macOS.

2. Verify the server URL: Make sure that the server URL you provided is correct and accessible. Double-check for any typos or network connectivity issues.

3. Check the credentials: Ensure that the username and password you provided are correct and have the necessary permissions to access the backend server API.

4. Verify the API URL: Double-check the API URL to ensure it is accurate and points to the correct backend server.

5. Restart the agent: Sometimes, restarting the agent can resolve certain issues. You can do this by running the appropriate command for your operating system:
- On linux: `sudo systemctl restart ocsinventory-service`
- On Windows: Go to windows services and click on restart the service
- On MacOS: `sudo launchctl unload /Library/LaunchDaemons/org.ocsinventory.agent.plist` followed by `sudo launchctl load /Library/LaunchDaemons/org.ocsinventory.agent.plist`
