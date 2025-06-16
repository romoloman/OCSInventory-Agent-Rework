#define AppName "OCSInventory Agent"
#define AppVersion "3.0.0"
#define AppPublisher "OCSInventory"
#define AppURL "https://www.ocsinventory.com/"
#define AppExeName "agent-windows.exe"
#define AppPath "Path_of_your_agent\OCSInventory-Agent"

[Setup]
AppId={{652EB54C-0A14-46AF-9F06-3BA7C294AFC9}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\{#AppName}
DisableProgramGroupPage=yes
LicenseFile={#AppPath}\setup\windows\media\license.txt
OutputDir=OCSInventory-Agent-Setup
OutputBaseFilename=OCSInventory-Agent-Setup-{#AppVersion}
SetupIconFile={#AppPath}\setup\windows\media\icone_ocs.ico
SolidCompression=yes
UninstallDisplayIcon={#AppPath}\setup\windows\media\icone_ocs.ico
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Files]
Source: "JSONConfig.dll"; Flags: dontcopy
Source: "{#AppPath}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#AppPath}\setup\windows\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"

[Code]
var
  CONFIG_PATH: String;
  InputPage: TInputQueryWizardPage;
  URL, USERNAME, PASSWORD, LOG_LEVEL, CERTIFICATE: String;
  ResultCode: Integer;

procedure InitializeWizard;
begin
  CONFIG_PATH := ExpandConstant('{commonappdata}\OCSInventory-Agent\config.json');
  InputPage := CreateInputQueryPage(wpInstalling, 'Agent configuration', 'Please specify your own agent settings.', '');
  
  InputPage.Add('*URL:', False);
  InputPage.Add('*Username:', False);
  InputPage.Add('*Password:', False);
  InputPage.Add('LogLevel:', False);
  InputPage.Add('Certificate:', False);
  
  InputPage.Values[0] := 'https://ocsinventory.example.com/ocsinventory';
  InputPage.Values[1] := 'ocsuser';
  InputPage.Values[2] := 'ocspassword';
  InputPage.Values[3] := '2';
  InputPage.Values[4] := '';
end;

function JSONWriteInteger(FileName, Section, Key: String; Value: Int64): Boolean;
external 'JSONWriteInteger@files:jsonconfig.dll stdcall';

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  
  if CurPageID = InputPage.ID then
  begin    
    if InputPage.Values[0] = '' then
    begin
      MsgBox('Error: No value on collect period input', mbError, MB_OK);
      Result := False;
    end
    else if InputPage.Values[1] = '' then
    begin
      MsgBox('Error: No value on writing period input', mbError, MB_OK);
      Result := False;
    end
    else if InputPage.Values[2] = '' then
    begin
      MsgBox('Error: No value on backup period input', mbError, MB_OK);
      Result := False;
    end;
    
    CollectPeriod := StrToInt64Def(InputPage.Values[0], 1);
    WritingPeriod := StrToInt64Def(InputPage.Values[1], 0);
    BackupPeriod := StrToInt64Def(InputPage.Values[2], 1);
    
    JSONWriteInteger(CONFIG_PATH, 'collect', 'period', CollectPeriod);
    JSONWriteInteger(CONFIG_PATH, 'writing', 'period', WritingPeriod);
    JSONWriteInteger(CONFIG_PATH, 'backup', 'period', BackupPeriod);
  end;
  
  if CurPageID = RunNowPage.ID then
  begin
    if RunNowCheckBox.Checked = True then
    begin
      Exec('sc.exe', 'create "GreenIT Service" binpath= "C:\Program Files\GreenIT Service\Service.exe" start= "auto"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Exec('sc.exe', 'description "GreenIT Service" "Collect consumption information for OCSInventory GreenIT plugin."', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Exec('sc.exe', 'start "GreenIT Service"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    end
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    Exec('sc.exe', 'stop "GreenIT Service"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Sleep(2000);
    Exec('sc.exe', 'delete "GreenIT Service"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;