[cmdletbinding()]
param (
    [Parameter(Mandatory=$true)][string]$romPath
)

# get paths
$scriptPath = Split-Path -Path $MyInvocation.MyCommand.Path 
$retroWinRoot = (Get-Item $scriptPath).Parent.Parent.FullName
$whdLoadDbXmlPath = "$($scriptPath)\whdload_db.xml"

function log([string]$text) {
    Add-Content "$retroWinRoot\last-run.log" "$([DateTime]::Now.ToString()) [fs-uae] $($text)"
}

Try {
    . ("$scriptPath\control-mapping-fs-uae.ps1")
}
Catch {
    log("Could not find $scriptPath\control-mapping-retroarch.ps1")
    Return
}

# check for dependencies and setup aliases
if ((test-path "${env:ProgramFiles(x86)}\7-Zip\7z.exe")) 
{
    set-alias sz "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
} 
else {
    if ((test-path "$env:ProgramW6432\7-Zip\7z.exe")) 
    {
        set-alias sz "$env:ProgramW6432\7-Zip\7z.exe"
        
    } 
    else {
        log("7Zip not found at ${env:ProgramFiles(x86)}\7-Zip\7z.exe or $env:ProgramW6432\7-Zip\7z.exe")
    }
}
 

if (-not (test-path "$($scriptPath)\..\..\emulators\fs-uae\fs-uae.exe")) {throw "$($scriptPath)\..\..\emulators\fs-uae\ fs-uae.exe missing"} 
set-alias emu "$($scriptPath)\..\..\emulators\fs-uae\fs-uae.exe"

function CheckRequiredFolders {

    param (
        [Parameter(Mandatory=$true)][String]$basePath
    )

    New-Item -ItemType Directory -Force -Path "$($basePath)\game-data"
    New-Item -ItemType Directory -Force -Path "$($basePath)\boot-data"
    New-Item -ItemType Directory -Force -Path "$($basePath)\save-data\Autoboots"
    New-Item -ItemType Directory -Force -Path "$($basePath)\save-data\Debugs"
    New-Item -ItemType Directory -Force -Path "$($basePath)\save-data\Kickstarts"
    New-Item -ItemType Directory -Force -Path "$($basePath)\save-data\Savegames"

}

function CopyKickstartsFromBiosFolder {

    param (
        [Parameter(Mandatory=$true)][String]$basePath
    )

    $source = "$($basePath)\..\..\bios\amiga\*"
    $destination = "$($basePath)\save-data\Kickstarts\"
    Copy-item -Force -Recurse -Verbose $source -Destination $destination
}

function CheckForKickstarts {

    param (
        [Parameter(Mandatory=$true)][String]$basePath
    )

    if(![System.IO.File]::Exists("$($basePath)\save-data\Kickstarts\kick40063.A600")) { throw "Missing Kickstart $($basePath)\save-data\Kickstarts\kick40063.A600" }
    if(![System.IO.File]::Exists("$($basePath)\save-data\Kickstarts\kick39106.A1200")) { throw "Missing Kickstart $($basePath)\save-data\Kickstarts\kick39106.A1200" }
}

function CleanEnvironment {

    param (
        [Parameter(Mandatory=$true)][String]$basePath
    )

    Remove-Item -Path "$($basePath)\game-data\*" -Recurse
    Remove-Item -Path "$($basePath)\boot-data\*" -Recurse
}

function SetupBootData {

    param (
        [Parameter(Mandatory=$true)][String]$basePath
    )

    if(![System.IO.File]::Exists("$($basePath)\boot-data")) {

        # download the latest whdload_db file

        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile("https://raw.githubusercontent.com/midwan/amiberry/master/whdboot/boot-data.zip", "$($basePath)\boot-data.zip")

    }

    sz x "$($basePath)\boot-data.zip" -o"$($basePath)\boot-data\" * -r -y
}

function GetWHDLoadSettings {

    param (
        [Parameter(Mandatory=$true)][String]$whdLoadDbXmlPath,
        [Parameter(Mandatory=$true)][String]$romPath
    )

    if(![System.IO.File]::Exists($whdLoadDbXmlPath)) {

        # download the latest whdload_db file

        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile("https://raw.githubusercontent.com/midwan/amiberry/master/whdboot/game-data/whdload_db.xml", $whdLoadDbXmlPath)

    }

    # find the game in whdload_db
    $whdLoadDbXml = ( Select-Xml -Path $whdLoadDbXmlPath -XPath / ).Node
    $romName = [io.path]::GetFileNameWithoutExtension($romPath)

    $whdSettings = $whdLoadDbXml.whdbooter.game | Where { $_.filename -eq $romName }

    return $whdSettings
}

function GetWHDLoadHardwareConfig {

    param (
        #[Parameter(Mandatory=$true)][string]$romPath
        [Parameter(Mandatory=$true)][String]$whdLoadHardwareBlock
    )

    $hardwareSettings = New-Object -TypeName psobject 
    
    $hardwareSettings | Add-Member -MemberType NoteProperty -Name port0 -Value "$(FindWHDLoadGameOption -optionName "PORT0" -keyValuePairs $whdLoadHardwareBlock)"
    $hardwareSettings | Add-Member -MemberType NoteProperty -Name port1 -Value "$(FindWHDLoadGameOption -optionName "PORT1" -keyValuePairs $whdLoadHardwareBlock)"
    $hardwareSettings | Add-Member -MemberType NoteProperty -Name control -Value "$(FindWHDLoadGameOption -optionName "PRIMARY_CONTROL" -keyValuePairs $whdLoadHardwareBlock)"
    $hardwareSettings | Add-Member -MemberType NoteProperty -Name control2 -Value "$(FindWHDLoadGameOption -optionName "SECONDARY_CONTROL" -keyValuePairs $whdLoadHardwareBlock)"
    $hardwareSettings | Add-Member -MemberType NoteProperty -Name fastcopper -Value "$(FindWHDLoadGameOption -optionName "FAST_COPPER" -keyValuePairs $whdLoadHardwareBlock)"
    $hardwareSettings | Add-Member -MemberType NoteProperty -Name cpu -Value "$(FindWHDLoadGameOption -optionName "CPU" -keyValuePairs $whdLoadHardwareBlock)"
    $hardwareSettings | Add-Member -MemberType NoteProperty -Name blitter -Value "$(FindWHDLoadGameOption -optionName "BLITTER" -keyValuePairs $whdLoadHardwareBlock)"
    $hardwareSettings | Add-Member -MemberType NoteProperty -Name clock -Value "$(FindWHDLoadGameOption -optionName "CLOCK" -keyValuePairs $whdLoadHardwareBlock)"
    $hardwareSettings | Add-Member -MemberType NoteProperty -Name chipset -Value "$(FindWHDLoadGameOption -optionName "CHIPSET" -keyValuePairs $whdLoadHardwareBlock)"
    $hardwareSettings | Add-Member -MemberType NoteProperty -Name jit -Value "$(FindWHDLoadGameOption -optionName "JIT" -keyValuePairs $whdLoadHardwareBlock)"
    $hardwareSettings | Add-Member -MemberType NoteProperty -Name cpu_24bit -Value "$(FindWHDLoadGameOption -optionName "CPU_24BITADDRESSING" -keyValuePairs $whdLoadHardwareBlock)"
    $hardwareSettings | Add-Member -MemberType NoteProperty -Name cpu_comp -Value "$(FindWHDLoadGameOption -optionName "CPU_COMPATIBLE" -keyValuePairs $whdLoadHardwareBlock)"
    $hardwareSettings | Add-Member -MemberType NoteProperty -Name sprites -Value "$(FindWHDLoadGameOption -optionName "SPRITES" -keyValuePairs $whdLoadHardwareBlock)"
    $hardwareSettings | Add-Member -MemberType NoteProperty -Name scr_height -Value "$(FindWHDLoadGameOption -optionName "SCREEN_HEIGHT" -keyValuePairs $whdLoadHardwareBlock)"
    $hardwareSettings | Add-Member -MemberType NoteProperty -Name y_offset -Value "$(FindWHDLoadGameOption -optionName "SCREEN_Y_OFFSET" -keyValuePairs $whdLoadHardwareBlock)"
    $hardwareSettings | Add-Member -MemberType NoteProperty -Name ntsc -Value "$(FindWHDLoadGameOption -optionName "NTSC" -keyValuePairs $whdLoadHardwareBlock)"
    $hardwareSettings | Add-Member -MemberType NoteProperty -Name fast -Value "$(FindWHDLoadGameOption -optionName "FAST_RAM" -keyValuePairs $whdLoadHardwareBlock)"
    $hardwareSettings | Add-Member -MemberType NoteProperty -Name z3 -Value "$(FindWHDLoadGameOption -optionName "Z3_RAM" -keyValuePairs $whdLoadHardwareBlock)"

    return $hardwareSettings
}

function FindWHDLoadGameOption {

    param (
        #[Parameter(Mandatory=$true)][string]$romPath
        [Parameter(Mandatory=$true)][String]$optionName,
        [Parameter(Mandatory=$true)][String]$keyValuePairs
    )

    return $keyValuePairs.Split([Environment]::NewLine) | Where { ![String]::IsNullOrWhiteSpace($_) } | ForEach { $_.Trim() } | Where { $_.StartsWith($optionName)} | ForEach { $_.Split("=")[1] } | Select-Object -first 1
}

CheckRequiredFolders -basePath $scriptPath

CopyKickstartsFromBiosFolder -basePath $scriptPath

CheckForKickstarts -basePath $scriptPath

# ensure we're starting in a good state
CleanEnvironment -basePath $scriptPath

SetupBootData -basePath $scriptPath

#extract lha to game-data folder
sz x $romPath -o"$($scriptPath)\game-data\" * -r -y | Out-Null

# decide upon uae settings from whdload_db, if possible
# https://github.com/midwan/amiberry/blob/af55b20adcced826d54865bc7bdcc7de2b8ff07b/src/osdep/amiberry_whdbooter.cpp

$whdSettings = GetWhdLoadSettings -whdLoadDbXmlPath $whdLoadDbXmlPath -romPath $romPath

# Set A1200 Default
$amiga_model = "A1200/020"
$kickFile = "kick40068.A1200"
$chipmem_size = $null
$cpu_speed= $null
$cpu_multiplier= $null
$fastmem_size= "8192"
$z3mem_size= $null
$ntsc= $null

$isAga = $false
$isCD32 = $false

if ($null -ne $whdSettings) {

    $hardwareSettings = GetWHDLoadHardwareConfig -whdLoadHardwareBlock $whdSettings.hardware

    $subPath = $whdSettings.subpath
    $slaveName = $whdSettings.slave_default
    $slaveCustom = $whdSettings.slave.custom

    $slaveCustom | Out-File -filepath "$($scriptPath)\boot-data\WHDBooter\WSConfigs\$($subPath).ws"

    $isAga = $whdSettings.filename.Contains("_AGA") -or $hardwareSettings.chipset -eq "AGA"
    $isCD32 = $whdSettings.filename.Contains("_CD32") -or $hardwareSettings.chipset -eq "CD32"

    if ($isAga -eq $false -and ($hardwareSettings.cpu -eq "68000" -or $hardwareSettings.cpu -eq "68010"))
    {
        $amiga_model = "A600"
        $kickFile = "kick40063.A600"
    }

    if ($isCD32)
    {
        $amiga_model = "CD32"
    }

    # SCREEN HEIGHT, BLITTER, SPRITES, MEMORY, JIT, BIG CPU ETC 

    # CPU 68020/040
    if ($hardwareSettings.cpu -eq "68040")
    {
        $amiga_model = "A4000"
        $kickFile = "kick40068.A4000"
    }

    switch ($hardwareSettings.clock) 
    {
        "3" { 
            $cpu_speed = "real" 
            $cpu_multiplier = "1"
        }
        "7" { 
            $cpu_speed = "real" 
            $cpu_multiplier = "2"
        }
        "14" {
            $cpu_speed = "real" 
            $cpu_multiplier = "4"
        }
        "28" {
            $cpu_speed = "real" 
            $cpu_multiplier = "8"
        }
        "max" { $cpu_speed = "max" }
        "turbo" { $cpu_speed = "max" }
    }

    if (![String]::IsNullOrWhiteSpace($hardwareSettings.fast))
    {
        $fastmem_size = $hardwareSettings.fast.ToString()
    }

    if ($null -ne $hardwareSettings.z3) 
    {
        $amiga_model = "A1200/020"
        $z3mem_size = $hardwareSettings.z3.ToString()
    }


    # Fast Copper?

    # CHIPSET OVERWRITE
    switch($hardwareSettings.chipset)
    {
        "ocs" {
            $amiga_model = "A500"
            $kickFile = "kick37175.A500"
        }
        "ecs" {
            $amiga_model = "A600"
            $kickFile = "kick40063.A600"
        }
        "aga" {
            $amiga_model = "A1200/020"
            $kickFile = "kick40068.A1200"
        }
    }

    # JIT
    if ($hardwareSettings.jit -eq "true") 
    {
        $jit="1"
    }


    if (![String]::IsNullOrWhiteSpace($hardwareSettings.ntsc)) 
    {
        $ntsc = "1"
    }

}

# launch winuae and wait for it to finish (https://www.vware.at/winuaehelp/CommandLineParameters.html)

log($hardwareSettings)

$commandString = "emu -f --amiga_model=" + $($amiga_model) + " --kickstart_file=""$($scriptPath)\save-data\Kickstarts\"+$($kickFile)+""" --hard_drive_0=""$($scriptPath)\boot-data"" --hard_drive_1=""$($scriptPath)\game-data"" --hard_drive_2=""$($scriptPath)\save-data"" "

# --joystick_0_button_0 = action_quit

if (![String]::IsNullOrWhiteSpace($cpu_speed)) { $commandString += " --use_cpu_speed="+$($cpu_speed) }
if (![String]::IsNullOrWhiteSpace($chipmem_size)) { $commandString += " --chip_memory="+$($chipmem_size) }
if (![String]::IsNullOrWhiteSpace($cpu_multiplier)) { $commandString += " --uae_cpu_multiplier="+$($cpu_multiplier) }
if (![String]::IsNullOrWhiteSpace($fastmem_size)) { $commandString += " --fast_memory="+$($fastmem_size) }
if (![String]::IsNullOrWhiteSpace($z3mem_size)) { $commandString += " --zorro_iii_memory="+$($z3mem_size) }
if (![String]::IsNullOrWhiteSpace($jit)) { $commandString += " --jit_compiler="+$($jit) }
if (![String]::IsNullOrWhiteSpace($ntsc)) { $commandString += " --ntsc_mode="+$($ntsc) }



$commandString += " --floppy_drive_volume=0 >> $retroWinRoot\last-run.log 2>&1 | Out-String" #--fullscreen=1 | Out-Null"

log($commandString)

$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

Invoke-Expression $commandString 

# try and clean up
CleanEnvironment -basePath $scriptPath
