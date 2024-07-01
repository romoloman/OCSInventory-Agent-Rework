# Getting started

## Step 1: Flutter installation

### Download Flutter packages

Begin to download the Flutter package by clicking on the big blue button in `Manual install` section on these websites":

- [Linux Installation](https://docs.flutter.dev/get-started/install/linux)
- [MacOS Installation](https://docs.flutter.dev/get-started/install/macos/desktop?tab=download)
- [Windows Installation](https://docs.flutter.dev/get-started/install/windows/desktop?tab=download)

### Add Flutter application to path

- Linux:

```text
echo 'export PATH="$PATH:<path_to_flutter_directory>/flutter/bin"' >> $HOME/.bashrc
```

- MacOS:

```text
echo 'export PATH="$PATH:<path_to_flutter_directory>/flutter/bin"' >> ~/.zshenv
```

- Windows:

Change of OS...

Joking :) [Link here](https://docs.flutter.dev/get-started/install/windows/desktop?tab=download#update-your-windows-path-variable)

## Step 2: Clone of the project

```text
git clone https://github.com/OCSInventory-NG/OCSInventory-Agent-Rework.git
```

or with SSH

```text
git clone git@github.com:OCSInventory-NG/OCSInventory-Agent-Rework.git
```

If you did it since the begining without cheats... well done! You're a superhero.

## Step 3: Agent configuration

### Linux and macos

- Configuration directory : `/etc/ocsinventory-agent`
- Log file in directory : `/var/log/ocsinventory-agent/ocsinventory-agent.log`
- Data inventories : `/var/lib/ocsinventory-data`

### Windows

- Configuration directory, log file and data inventories are in the same directory : `C:\ProgramData\Agent-OCS`

After installing the agent, there is a config forlder, and the file `inventory.json` inside.

In this file, there is the properties to configure the agent:

|    Property    |                                                                                        Description                                                                                        |
| :------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
| data_directory |                                                                     Folder where the agent will store inventory data.                                                                     |
|   log_level    |                                                                      0: Error 1: Warning 2: Info (default) 3 Verbose                                                                      |
|    log_file    |                   Default to false, the logs will be written in the terminal you'r using. Set to true, you'll need to specify a log file where you want to write logs.                    |
| log_file_path  |               This property is to set the log file path. Only define it if you put log_file to true.<br>**Warning**: It will not create the file. You'll need to create it.               |
|      mode      | This is the working mode property of the agent, there is 5 modes: 0- Installation mode 1-Remote with template 2- Remote without template 3- Local with template 4- Local without template |
|   `password`   |                                                By default in remote inventory mode, set the password to connect to the backend server api.                                                |
|     token      |                                                   Will be automatically replace to store the retreived token from the backend server api.                                                   |
|   `username`   |                                                By default in remote inventory mode, set the username to connect to the backend server api.                                                |
|     `url`      |                                                                                  Backend server api url.                                                                                  |

> _**IMPORTANT NOTE**: `Special words` are mandatories properties to configure._
>
> There is an example of the inventory configuration file:

```text
{
    "log_file": "true",
    "mode": "2",
    "password": "password",
    "token": "token value",
    "username": "username",
    "url": "http://127.0.0.1:8000/",
    "data_directory": "/var/lib/ocsinventory-data",
    "log_file_path": "/var/log/ocsinventory-agent/ocsinventory-agent.log",
    "log_level": "3"
}
```

## Step 5: Installing the Agent

### Installing the agent on Linux

You will find below how to install OCS Inventory agent on linux

#### 1. Compilation

Go to the linux setup directory: `/setup/linux/`
You need to compile the entry point `app.dart` and the daemon `daemon.dart` using the following command

```text
dart compile exe /path of your project/OCSInventory-Agent-Rework/lib/app/app.dart -o AGENT-LINUX
dart compile exe /path of your project/OCSInventory-Agent-Rework/lib/app/daemon.dart -o DAEMON-LINUX
```

Ensure that you have something like this:

```text
├── AGENT-LINUX
├── DAEMON-LINUX
├── install.sh
└── uninstall.sh
```

#### 2. Installing the agent non-interactively

To install the agent in non-interactive mode, you have to run the `install.sh` script with a set of launch arguments to allow to set all configuration options as you can do in interactive mode.
This is a list of all available `install.sh` script arguments:

- -h : set host url of the OCS Inventory NG server
- -u : set username
- -p : set password
- -v : set level of the log
- -l : set local mode (do not register service)
- -s : set service mode (register service)
- -n : set to run the agent now

For example, if you want to install OCS Inventory Agent in non-interactive mode and set server adress, set password, set username, set log level, register the service and run the agent now, you have to run this command:

```text
sudo install.sh -h http://127.0.0.1:8000/ -u username -p password -v 3 -s -n
```

#### 3. Installing the agent interactively

To install the agent in non-interactive mode, you have to run the `install.sh` script with root privileges.
If the agent configuration is already exist, it will ask you to remove it before installing the agent.

```text
Enter server URL:

Enter username:

Enter password:

Enter the log level (default is 2 = Info):

Do you register the service - agent must be launched automatically (y/n)?

Do you want to run the agent now (y/n)?
```

#### 4. Additionnal information

- The content of the agent is stored in `/usr/share/ocsinventory-agent` and a symbolic link is created with `/usr/bin/ocsinventory-agent-ng`, so you can run with root privileges

For example, if you want to run the agent and set log level to verbose, you have to run this command:

```text
sudo ocsinventory-agent-ng -v 3
```

- If you set service, it will be `/etc/systemd/system/ocsinventory-agent.service`

- This is a list of all available agent arguments:
  - -f (--log_file) : Enable or disable the log file (if needed)
  - -m (--mode) : Agent execution mode (if needed)
  - -p (--password) : Password (if needed)
  - -t (--token) : Token (if needed)
  - -u (--username) : Username (if needed)
  - -s (--url) : URL to the OCS server (if needed)
  - -d (--data_directory) : Path to the inventory data (if needed)
  - -l (--log_file_path) : Path to the log file (if needed)
  - -v (--log_level) : Log level (if needed)

### Installing the agent on Windows

#### 1. Compilation

Go to the linux setup directory: `/setup/windows/`
You need to compile the entry point `app.dart` and the daemon `daemon.dart` using the following command

```text
dart compile exe /path of your project/OCSInventory-Agent-Rework/lib/app/app.dart -o AGENT-WINDOWS.exe
dart compile exe /path of your project/OCSInventory-Agent-Rework/lib/app/daemon.dart -o DAEMON-WINDOWS.exe
```

You need to download `NSSM - the Non-Sucking Service Manager` for handling services

- [NSSM Installation last release](https://nssm.cc/download)
  Extract the file, navigate until win64 folder and copy nssm.exe file into your windows setup folder `/setup/windows/`

Ensure that you have something like this:

```text
├── agent-windows.exe
├── daemon-windows.exe
├── Setup OCS Inventory Agent.iss
└── nssm.exe
```

Now you can create your package (if needed) with inno setup by using `Setup OCS Inventory Agent.iss` script

#### 2. Installing the agent non-interactively

To install the agent in non-interactive mode, you have to run the `OCS-NG setup` with a set of launch arguments to allow to set all configuration options as you can do in interactive mode.
This is a list of all available `OCS-NG setup` script arguments:

- /SILENT : run in silent mode
- LOG="\path to store\setup.log" : log file of the installation process
- /URL=http://127.0.0.1:8000/ : host url of the OCS Inventory NG server
- /USERNAME=username : set username
- /PASSWORD=password : set password
- /LOGLEVEL=3 : set level of the log
- /LOCAL=False : set local mode (do not register service)
- /SERVICE=True : set service mode (register service)
- /NOW=True : set to run the agent now

For example, if you want to install OCS Inventory Agent in non-interactive mode and run in silent mode, log installation process, set server adress, set password, set username, set log level to verbose, register the service and run the agent now, you have to run this command:

```text
mysetup-agent.exe /SILENT /LOG="C:\Users\Djily\Desktop\setup3.log" /URL=http://127.0.0.1:8000/ /USERNAME=username /PASSWORD=password /LOCAL=False /SERVICE=True /NOW=True /LOGLEVEL=3
```

#### 3. Installing the agent interactively

To install the agent in non-interactive mode, you have to run the `OCS-NG setup` and set all configuration fields.

#### 4. Additionnal information

- The is installed in `C:\Program Files\OCS Inventory AGENT`

For example, if you want to run the agent and set log level to verbose, you have to run this command:

- If you set service, it will be in service and named `OCSInventory-Agent`

- This is a list of all available agent arguments:
  - -f (--log_file) : Enable or disable the log file
  - -m (--mode) : Agent execution mode
  - -p (--password) : Password
  - -t (--token) : Token
  - -u (--username) : Username
  - -s (--url) : URL to the OCS server
  - -d (--data_directory) : Path to the inventory data
  - -l (--log_file_path) : Path to the log file
  - -v (--log_level) : Log level

### Installing the agent on MacOS

#### 1. Compilation

Go to the linux setup directory: `/setup/macos/`
You need to compile the entry point `app.dart` and the daemon `daemon.dart` using the following command

```text
dart compile exe /path of your project/OCSInventory-Agent-Rework/lib/app/app.dart -o AGENT-MACOS
dart compile exe /path of your project/OCSInventory-Agent-Rework/lib/app/daemon.dart -o DAEMON-MACOS
```

Now you can create your package (if needed) with Xcode and Package applications.

- Build `config-agent-ocs` and place the bundle file into `OCS Inventory Agent setup` directory
- Build `ocsng_app-xcode` to create OCS-NG pkg and ocscontact
- Build `OCS Inventory Agent setup` to create installation package

Ensure that you have something like this:

```text
├── AUTHORS
├── Changes
├── AGENT-MACOS
├── DAEMON-MACOS
├── LICENCE.txt
├── OCS Inventory Agent setup
│ ├── build
│ ├── OCS Inventory Agent.mpkg
│ ├── config-agent-ocs.bundle
│ ├── OCS Inventory Agent.pkgproj
│ └── scripts
├── ocsng_app-xcode
│ ├── build
│ ├── ocscontact
│ ├── OCS-NG
├── README.md
├── scripts
├── setup plugins
│ └── config-agent-ocs
└── THANKS
```

#### 2. Installing the agent interactively

To install the agent in non-interactive mode, you have to run the `OCS Inventory Agent.mpkg` package and set all configuration fields.

#### 4. Additionnal information

- The is installed in `/Applications/OCS-NG`

For example, if you want to run the agent and set log level to verbose, you have to run this command:

- If you set service will be in `/Library/LaunchDaemons/org.ocsinventory.agent.plist`
