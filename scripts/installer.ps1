
# Initial version based on the work of Chris Franco- check out this excellent automated emulation station install repository here; 
# https://github.com/Francommit/win10_emulation_station

# Configuring
Set-ExecutionPolicy -ExecutionPolicy Bypass -Force -Scope Process

Import-Module BitsTransfer
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls" # Convince Powershell to talk to sites with different versions of TLS

# Installing Chocolatey 
Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')) 

# Get script path
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path $scriptPath
$retroWinRoot = (Get-Item $scriptDir).Parent.FullName
Write-Host $scriptDir

Try {
    . ("$scriptDir\archives.ps1")
}
Catch {
    "Could not find $scriptDir\archives.ps1"
    Return
}

Try {
    . ("$scriptDir\ps-ini.ps1")
}
Catch {
    "Could not find $scriptDir\archives.ps1"
    Return
}

choco install directx -y
choco install 7zip -y
choco install dotnet4.6.1 -y
choco install vcredist2008 -y
choco install vcredist2010 -y
choco install vcredist2013 -y
choco install vcredist2015 -y

# download everything in the manifest

$installersFolder = "$retroWinRoot\installers\"
if(!(Test-Path -Path $installersFolder )){
    New-Item -ItemType Directory -Force -Path $installersFolder
}

$manifest = Get-Content "$scriptDir\manifest.json" | ConvertFrom-Json

$manifest | Select-Object -expand downloads | ForEach-Object {

    $url = $_.url
    $file = $_.file
    $output = $installersFolder + $file

    if(![System.IO.File]::Exists($output)){
        Write-Host $file " missing- attempting download"
        Start-BitsTransfer -Source $url -Destination $output
    } else {
        Write-Host $file " already exists"
    }
}

$manifest | Select-Object -expand releases | ForEach-Object {

    $repo = $_.repo
    $file = $_.file

    $releases = "https://api.github.com/repos/$repo/releases"
    $tag = (Invoke-WebRequest $releases -usebasicparsing| ConvertFrom-Json)[0].tag_name

    $url = "https://github.com/$repo/releases/download/$tag/$file"
    $name = $file.Split(".")[0]

    $zip = "$name-$tag.zip"
    $output = $installersFolder + $zip

    if(![System.IO.File]::Exists($output)) {
        Invoke-WebRequest $url -Out $output
        Write-Host $file " missing- attempting download"
    } else {
        Write-Host $file " already exists"
    }

}

# extract EmulationStation
$esPath = "$retroWinRoot\emulationstation\"

if(!(Test-Path -Path $esPath )){
    New-Item -ItemType Directory -Force -Path $esPath
}

$esArchive = "$($installersFolder)EmulationStation-Win32-continuous-master.zip"
Expand-Archive -Path $esArchive -Destination $esPath

# Rewrite the launch portable script to keep configs in retrowin folder
$esLocal = "set HOME=%~dp0..
emulationstation.exe"
Set-Content "$($esPath)launch_portable.bat" -Value $esLocal

# perform first run of emulation station to setup config data store

$env:Home=$retroWinRoot
& "$($esPath)emulationstation.exe"

$configPath = "$scriptDir\..\.emulationstation\es_systems.cfg"

Write-Host "Checking for config file..." -NoNewline
while (!(Test-Path $configPath)) { 
    Write-Host "." -NoNewline
    Start-Sleep 5
}

Stop-Process -Name "emulationstation"

"Stopped Emulation Station"

# Retroarch Setup
$retroArchPath = "$retroWinRoot\emulators\retroarch\"
if(!(Test-Path -Path $retroArchPath )){
    New-Item -ItemType Directory -Force -Path $retroArchPath
}

$autoconfigsFolder = "$retroWinRoot\autoconfigs\"
if(!(Test-Path -Path $autoconfigsFolder )){
    New-Item -ItemType Directory -Force -Path $autoconfigsFolder
}

if(!(Test-Path -Path "$retroWinRoot\savedata\retroarch\saves" )){
    New-Item -ItemType Directory -Force -Path "$retroWinRoot\savedata\retroarch\saves"
}
if(!(Test-Path -Path "$retroWinRoot\savedata\retroarch\saves\User\Wii" )){
    New-Item -ItemType Directory -Force -Path "$retroWinRoot\savedata\retroarch\saves\User\Wii"
}
if(!(Test-Path -Path "$retroWinRoot\savedata\retroarch\saves\User\GC" )){
    New-Item -ItemType Directory -Force -Path "$retroWinRoot\savedata\retroarch\saves\User\GC"
}
if(!(Test-Path -Path "$retroWinRoot\savedata\retroarch\saves\User\Config" )){
    New-Item -ItemType Directory -Force -Path "$retroWinRoot\savedata\retroarch\saves\User\Config"
}

$retroArchBinary = "$($installersFolder)RetroArch.7z"
Expand-Archive -Path $retroArchBinary -Destination $retroArchPath

# extract and copy cores
$coresPath = "$($retroArchPath)cores"

Get-ChildItem $installersFolder | where { $_.Name.EndsWith("_libretro.dll.zip") } | ForEach-Object {

    Expand-Archive -Path $_.FullName -Destination $coresPath
}

# fs-uae Setup
if(!(Test-Path -Path "$retroWinRoot\savedata\fs-uae\" )){
    New-Item -ItemType Directory -Force -Path "$retroWinRoot\savedata\fs-uae\"
}

$fsuaeEmulator = "$($installersFolder)fs-uae_2.8.3_windows_x86.zip"
$fsuaeEmulatorPath = "$retroWinRoot\emulators\fs-uae\"
Expand-Archive -Path $fsuaeEmulator -Destination $fsuaeEmulatorPath

# game pad detect
if(!(Test-Path -Path "$retroWinRoot\tools\ESGamePadDetect" )){
    New-Item -ItemType Directory -Force -Path "$retroWinRoot\tools\ESGamePadDetect"
}
$esGamePadDetect = "$($installersFolder)ESGamePadDetect.7z"
$esGamePadDetecPath = "$retroWinRoot\tools\ESGamePadDetect"
Expand-Archive -Path $esGamePadDetect -Destination $esGamePadDetecPath

# PSX Setup
if(!(Test-Path -Path "$retroWinRoot\savedata\epsxe\" )){
    New-Item -ItemType Directory -Force -Path "$retroWinRoot\savedata\epsxe\"
}
$psxEmulator = "$($installersFolder)ePSXe205.zip"
$psxEmulatorPath = "$retroWinRoot\emulators\epsxe\"

if(!(Test-Path -Path $psxEmulatorPath )){
    New-Item -ItemType Directory -Force -Path $psxEmulatorPath
}
Expand-Archive -Path $psxEmulator -Destination $psxEmulatorPath

# PS2 Setup
if(!(Test-Path -Path "$retroWinRoot\savedata\pcsx2\" )){
    New-Item -ItemType Directory -Force -Path "$retroWinRoot\savedata\pcsx2\"
}
$ps2Emulator = "$($installersFolder)pcsx2-1.4.0-binaries.7z"
$ps2ExtractionPath = "$retroWinRoot\emulators\"

Expand-Archive -Path $ps2Emulator -Destination $ps2ExtractionPath
Rename-Item -Path "$($retroWinRoot)\emulators\PCSX2 1.4.0" -NewName "$retroWinRoot\emulators\pcsx2"

# Start Retroarch and generate a config
$retroarchExecutable = "$($retroArchPath)retroarch.exe"
$retroarchConfigPath = "$($retroArchPath)retroarch.cfg"

& $retroarchExecutable

Write-Host "Checking for config file" -NoNewline

while (!(Test-Path $retroarchConfigPath)) { 
    Write-Host "." -NoNewline
    Start-Sleep 5
}

Stop-Process -Name "retroarch"

# 
# Let's hack that config!
# 

$retroarchCfg = Get-IniContent -FilePath $retroarchConfigPath

$retroarchCfg["No-Section"]["video_fullscreen"] = """true"""
$retroarchCfg["No-Section"]["savestate_auto_load"] = """true"""
$retroarchCfg["No-Section"]["input_player1_analog_dpad_mode"] = """1"""
$retroarchCfg["No-Section"]["input_player2_analog_dpad_mode"] = """1"""
$retroarchCfg["No-Section"]["joypad_autoconfig_dir"] = """$retroWinRoot\autoconfigs"""
$retroarchCfg["No-Section"]["savefile_directory"] = """$retroWinRoot\savedata\retroarch\saves"""
$retroarchCfg["No-Section"]["system_directory"] = """$retroWinRoot\bios"""

Out-IniFile $retroarchCfg["No-Section"] -FilePath $retroarchConfigPath -Encoding "UTF8" -Force -SpacesAroundEquals
$utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False) 
[System.IO.File]::WriteAllLines( $retroarchConfigPath, (Get-Content  $retroarchConfigPath), $utf8NoBomEncoding) 

# Setup Rom & BIOS Folders
$romPath =  "$retroWinRoot\roms"
$biosPath = "$retroWinRoot\bios"
$systemsXml = ( Select-Xml -Path "$($scriptDir)\..\config\systems.xml" -XPath / ).Node
$systemsXml.systems.system | ForEach-Object { 

    if(!(Test-Path -Path "$($romPath)\$($_.name)" )){
        New-Item -ItemType Directory -Force -Path "$($romPath)\$($_.name)"
    }
    if(!(Test-Path -Path "$($biosPath)\$($_.name)" )){
        New-Item -ItemType Directory -Force -Path "$($biosPath)\$($_.name)"
    }
}

# build a new es_systems file
 
$esConfigFile = "$retroWinRoot\.emulationstation\es_systems.cfg"

[xml]$newConfig = New-Object System.Xml.XmlDocument
$root = $newConfig.CreateNode("element","systemList",$null)
$systemsXml.systems.system | ForEach-Object { 

    $nSystem = $newConfig.CreateNode("element","system",$null)

    $nFullName = $newConfig.CreateNode("element","fullname",$null)
    $nFullName.InnerText = $_.displayName
    $nSystem.AppendChild($nFullName)
    $nName = $newConfig.CreateNode("element","name",$null)
    $nName.InnerText = $_.name
    $nSystem.AppendChild($nName)
    $nPath = $newConfig.CreateNode("element","path",$null)
    $nPath.InnerText = "~/roms/$($_.name)"
    $nSystem.AppendChild($nPath)
    $nExtension = $newConfig.CreateNode("element","extension",$null)
    $nExtension.InnerText = "." + [String]::Join(" .", $_.emulator.extensionOverrides.extension) + " ." + [String]::Join(" .", $_.emulator.extensionOverrides.extension.ToUpper())
    $nSystem.AppendChild($nExtension)
    $nCommand = $newConfig.CreateNode("element","command",$null)
    $nCommand.InnerText = "powershell -ExecutionPolicy ByPass -File %HOME%\scripts\.\rom-launcher.ps1 -systemName ""$($_.name)"" -romPath '%ROM%'"
    $nSystem.AppendChild($nCommand)
    $nPlatform = $newConfig.CreateNode("element","platform",$null)
    if ([String]::IsNullOrWhiteSpace($_.esPlatform)) {
        $nPlatform.InnerText = $_.name
    }
    else {
        $nPlatform.InnerText = $_.esPlatform
    }
    $nSystem.AppendChild($nPlatform)
    $nTheme = $newConfig.CreateNode("element","theme",$null)
    $nTheme.InnerText = $_.name
    $nSystem.AppendChild($nTheme)

    $root.AppendChild($nSystem)

}
$newConfig.AppendChild($root)
$newConfig.save($esConfigFile)

# Copy over default es settings file
$esConfigFile = "$retroWinRoot\.emulationstation\es_settings.cfg"
Copy-Item -Path "$retroWinRoot\scripts\es_settings.cfg" -Destination $esConfigFile

$requiredTmpFolder = "$retroWinRoot\.emulationstation\tmp\"
if(!(Test-Path -Path $requiredTmpFolder )){
    New-Item -ItemType Directory -Force -Path $requiredTmpFolder
}

# 
# 14. Generate ini file for Dolphin.
# 
$dolphinConfigFile = "$retroWinRoot\savedata\retroarch\saves\User\Config\Dolphin.ini"
$dolphinConfigFolder = "$retroWinRoot\savedata\retroarch\saves\User\Config\"
$dolphinConfigFileContent = "[General]
LastFilename = 
ShowLag = False
ShowFrameCount = False
ISOPaths = 0
RecursiveISOPaths = False
NANDRootPath = 
DumpPath = 
WirelessMac = 
WiiSDCardPath = $retroWinRoot\savedata\retroarch\saves\User\Wii\sd.raw
[Interface]
ConfirmStop = True
UsePanicHandlers = True
OnScreenDisplayMessages = True
HideCursor = False
AutoHideCursor = False
MainWindowPosX = -2147483648
MainWindowPosY = -2147483648
MainWindowWidth = -1
MainWindowHeight = -1
LanguageCode = 
ShowToolbar = True
ShowStatusbar = True
ShowLogWindow = False
ShowLogConfigWindow = False
ExtendedFPSInfo = False
ThemeName = Clean
PauseOnFocusLost = False
DisableTooltips = False
[Display]
FullscreenResolution = Auto
Fullscreen = False
RenderToMain = True
RenderWindowXPos = -1
RenderWindowYPos = -1
RenderWindowWidth = 640
RenderWindowHeight = 480
RenderWindowAutoSize = False
KeepWindowOnTop = False
ProgressiveScan = False
PAL60 = False
DisableScreenSaver = False
ForceNTSCJ = False
[GameList]
ListDrives = False
ListWad = True
ListElfDol = True
ListWii = True
ListGC = True
ListJap = True
ListPal = True
ListUsa = True
ListAustralia = True
ListFrance = True
ListGermany = True
ListItaly = True
ListKorea = True
ListNetherlands = True
ListRussia = True
ListSpain = True
ListTaiwan = True
ListWorld = True
ListUnknown = True
ListSort = 3
ListSortSecondary = 0
ColumnPlatform = True
ColumnBanner = True
ColumnNotes = True
ColumnFileName = False
ColumnID = False
ColumnRegion = True
ColumnSize = True
ColumnState = True
[Core]
HLE_BS2 = True
TimingVariance = 40
CPUCore = 1
Fastmem = True
CPUThread = True
DSPHLE = True
SyncOnSkipIdle = True
SyncGPU = True
SyncGpuMaxDistance = 200000
SyncGpuMinDistance = -200000
SyncGpuOverclock = 1.00000000
FPRF = False
AccurateNaNs = False
DefaultISO = 
DVDRoot = 
Apploader = 
EnableCheats = False
SelectedLanguage = 0
OverrideGCLang = False
DPL2Decoder = False
Latency = 2
AudioStretch = False
AudioStretchMaxLatency = 80
MemcardAPath = $retroWinRoot\savedata\retroarch\saves\User\GC\MemoryCardA.USA.raw
MemcardBPath = $retroWinRoot\savedata\retroarch\saves\User\GC\MemoryCardB.USA.raw
AgpCartAPath = 
AgpCartBPath = 
SlotA = 1
SlotB = 255
SerialPort1 = 255
BBA_MAC = 
SIDevice0 = 6
AdapterRumble0 = True
SimulateKonga0 = False
SIDevice1 = 0
AdapterRumble1 = True
SimulateKonga1 = False
SIDevice2 = 0
AdapterRumble2 = True
SimulateKonga2 = False
SIDevice3 = 0
AdapterRumble3 = True
SimulateKonga3 = False
WiiSDCard = False
WiiKeyboard = False
WiimoteContinuousScanning = False
WiimoteEnableSpeaker = False
RunCompareServer = False
RunCompareClient = False
EmulationSpeed = 1.00000000
FrameSkip = 0x00000000
Overclock = 1.00000000
OverclockEnable = False
GFXBackend = OGL
GPUDeterminismMode = auto
PerfMapDir = 
EnableCustomRTC = False
CustomRTCValue = 0x386d4380
[Movie]
PauseMovie = False
Author = 
DumpFrames = False
DumpFramesSilent = False
ShowInputDisplay = False
ShowRTC = False
[DSP]
EnableJIT = False
DumpAudio = False
DumpAudioSilent = False
DumpUCode = False
Backend = Libretro
Volume = 100
CaptureLog = False
[Input]
BackgroundInput = False
[FifoPlayer]
LoopReplay = False
[Analytics]
ID = 
Enabled = False
PermissionAsked = False
[Network]
SSLDumpRead = False
SSLDumpWrite = False
SSLVerifyCertificates = True
SSLDumpRootCA = False
SSLDumpPeerCert = False
[BluetoothPassthrough]
Enabled = False
VID = -1
PID = -1
LinkKeys = 
[USBPassthrough]
Devices = 
[Sysconf]
SensorBarPosition = 1
SensorBarSensitivity = 50331648
SpeakerVolume = 88
WiimoteMotor = True
WiiLanguage = 1
AspectRatio = 1
Screensaver = 0

"

if(!(Test-Path -Path $dolphinConfigFolder )){
    New-Item $dolphinConfigFolder -ItemType directory
}

Write-Output $dolphinConfigFileContent  > $dolphinConfigFile

# Fixing epsxe bug setting the registry
# https://www.ngemu.com/threads/epsxe-2-0-5-startup-crash-black-screen-fix-here.199169/
# https://www.youtube.com/watch?v=fY89H8fLFSc
$path = 'HKCU:\SOFTWARE\epsxe\config'

if(!(Test-Path -Path $path )){
    New-Item -Path $path -Force | Out-Null
}

Set-ItemProperty -Path $path -Name 'CPUOverclocking' -Value '10'

# Add in a game art scraper
$scraperZip = "$($installersFolder)scraper_windows_amd64*.zip"
Expand-Archive -Path $scraperZip -Destination $romPath

$wshshell = New-Object -ComObject WScript.Shell
$desktop = [System.Environment]::GetFolderPath('Desktop')
$lnk = $wshshell.CreateShortcut("$desktop\RetroWin.lnk")
$lnk.TargetPath = "powershell"
$lnk.Arguments = " -ExecutionPolicy ByPass -File ""$scriptDir\start-es.ps1"""
$lnk.WorkingDirectory = "$scriptDir\"
$lnk.Save() 

Write-Host "Install Completed"

Read-Host -Prompt "Press Enter to exit"
