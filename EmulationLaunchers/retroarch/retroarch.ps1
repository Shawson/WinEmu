[cmdletbinding()]
param (
    [Parameter(Mandatory=$true)][string]$romPath,
    [Parameter(Mandatory=$true)][string]$coreName
)

# get paths
$scriptPath = Split-Path -Path $MyInvocation.MyCommand.Path 
$retroWinRoot = "$($scriptPath)\..\..\"

if (-not (test-path "$($scriptPath)\..\..\emulators\retroarch\retroarch.exe")) {throw "$($scriptPath)\..\..\emulators\retroarch\retroarch.exe missing"} 
set-alias emu "$($scriptPath)\..\..\emulators\retroarch\retroarch.exe"

# update the retroarch config file with attached controls

# map emulation station to retrarch;
Try {
    . ("$retroWinRoot\scripts\control-mapping-retroarch.ps1")
}
Catch {
    log("Could not find $retroWinRoot\scripts\control-mapping-retroarch.ps1")
    Return
}

log("successfully found controller ids- generating config")

$(
    # not everything should be xinput- check flag in windows device name
    Write-Output "input_driver = ""xinput"""
    Write-Output "input_device = ""$(GetControllerName $gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.DeviceName)"""
    Write-Output "input_vendor_id = ""$($gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.VID)"""
    Write-Output "input_product_id = ""$($gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.PID)"""

    $lastInput.input | ForEach-Object { GetMappedControl -type $_.type -name $_.name -id $_.id -value $_.value }
) | Out-File "$retroWinRoot\emulators\retroarch\retroarch.cfg"


log("config file written to $retroWinRoot\emulators\retroarch\retroarch.cfg")

$commandString = "emu -L 'Emulators\retroarch\cores\" + $($coreName) + " " + $($romPath)

$commandString += " | Out-Null"

$commandString

Invoke-Expression $commandString 