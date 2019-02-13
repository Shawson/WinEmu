[cmdletbinding()]
param (
    [Parameter(Mandatory=$true)][string]$romPath,
    [Parameter(Mandatory=$true)][string]$coreName
)

# get paths
$scriptPath = Split-Path -Path $MyInvocation.MyCommand.Path 
$retroWinRoot = (Get-Item $scriptPath).Parent.Parent.FullName

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
Try {
    . ("$retroWinRoot\scripts\ps-ini.ps1")
}
Catch {
    log("Could not find $retroWinRoot\scripts\ps-ini.ps1")
    Return
}

log("getting attached controllers")

$xml = Invoke-Expression "$($retroWinRoot)\tools\ESGamePadDetect\ESGamePadDetect.exe -list" | Out-String
$attachedControllers = (Select-Xml -Content $xml -XPath /).Node

if ($attachedControllers.BaseCommandLineResponseOfGameControllerIdentifiers.ResponseCode -ne 0) {
    log("Failed getting controller input")
    Return
}

log("successfully found controller ids- generating config")

$inputConfigs = ( Select-Xml -Path "$retroWinRoot\config\input.xml" -XPath / ).Node

Copy-Item "$retroWinRoot\emulators\retroarch\retroarch.cfg" "$retroWinRoot\emulators\retroarch\retroarch.cfgbak"
$retroArchCfg = Get-IniContent "$retroWinRoot\emulators\retroarch\retroarch.cfg"

$attachedControllers.data.controller | ForEach-Object {

    $thisAttachedController = $_

    $thisControllerInputConfig = $inputConfigs.inputList.inputConfig | Where-Object { 
        $_.pid -eq $thisAttachedController.PID -and
        $_.vid -eq $thisAttachedController.VID -and
        $_.deviceName -eq $thisAttachedController.DeviceName -and
        $_.controllerIndex -eq $thisAttachedController.ControllerIndex
    } | Select-Object -Last 1

    if ($null -eq $thisControllerInputConfig)
    {
        # try again but don't specify the controller index
        $thisControllerInputConfig = $inputConfigs.inputList.inputConfig | Where-Object { 
            $_.pid -eq $thisAttachedController.PID -and
            $_.vid -eq $thisAttachedController.VID -and
            $_.deviceName -eq $thisAttachedController.DeviceName
        } | Select-Object -Last 1
    }

    if ($null -ne $thisControllerInputConfig)
    {
        # we have a match, so lets do the mapping
        
        # Out-IniFile
    }

}

Out-IniFile $retroArchCfg "$retroWinRoot\emulators\retroarch\retroarch.cfg"  


<#
$(
    Write-Output "input_driver = ""xinput"""
    Write-Output "input_device = ""$($gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.DeviceName)"""
    Write-Output "input_vendor_id = ""$($gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.VID)"""
    Write-Output "input_product_id = ""$($gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.PID)"""

    $lastInput.input | ForEach-Object { GetMappedControl -type $_.type -name $_.name -id $_.id -value $_.value }
) | Out-File "$retroWinRoot\emulators\retroarch\retroarch.cfg"
#>

log("config file written to $retroWinRoot\emulators\retroarch\retroarch.cfg")

$commandString = "emu -L 'Emulators\retroarch\cores\" + $($coreName) + " " + $($romPath)

$commandString += " | Out-Null"

$commandString

Invoke-Expression $commandString 

Delete-item "$retroWinRoot\emulators\retroarch\retroarch.cfg"
Rename-Item "$retroWinRoot\emulators\retroarch\retroarch.cfgbak" "$retroWinRoot\emulators\retroarch\retroarch.cfg"