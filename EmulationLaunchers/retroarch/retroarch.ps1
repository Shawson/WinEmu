[cmdletbinding()]
param (
    [Parameter(Mandatory=$true)][string]$romPath,
    [Parameter(Mandatory=$true)][string]$coreName
)

$scriptPath = Split-Path -Path $MyInvocation.MyCommand.Path 
$retroWinRoot = (Get-Item $scriptPath).Parent.Parent.FullName

function log([string]$text) {
    Add-Content "$retroWinRoot\last-run.log" "$([DateTime]::Now.ToString()) [retroarch] $($text)"
}

Try {
    # get paths
    

    if (-not (test-path "$($retroWinRoot)\emulators\retroarch\retroarch.exe")) {throw "$($retroWinRoot)\emulators\retroarch\retroarch.exe missing"} 
    set-alias emu "$($retroWinRoot)\emulators\retroarch\retroarch.exe"

    # update the retroarch config file with attached controls

    # map emulation station to retroarch;
    Try {
        . ("$scriptPath\control-mapping-retroarch.ps1")
    }
    Catch {
        log("Could not find $scriptPath\control-mapping-retroarch.ps1")
        Return
    }

    log("getting attached controllers")

    $xml = Invoke-Expression "$($retroWinRoot)\tools\ESGamePadDetect\ESGamePadDetect.exe -list" | Out-String
    $attachedControllers = (Select-Xml -Content $xml -XPath /).Node

    if ($attachedControllers.BaseCommandLineResponseOfGameControllerIdentifiers.ResponseCode -ne 0) {
        log("XML : $($xml)")
        log("XML : $($attachedControllers.BaseCommandLineResponseOfGameControllerIdentifiers)")
        log("Failed getting controller input - ResponseCode : $($attachedControllers.BaseCommandLineResponseOfGameControllerIdentifiers.ResponseCode)")
        Return
    }

    log("successfully found controller ids- generating config")

    $inputConfigs = ( Select-Xml -Path "$retroWinRoot\config\input.xml" -XPath / ).Node

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
            $(
                $driverName = "xinput";

                if ($gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.IsXInput)
                {
                    Write-Output "input_driver = ""xinput"""
                }
                else {
                    Write-Output "input_driver = ""dinput"""
                    $driverName = "dinput"
                }

                $controllerName = GetControllerName -deviceName $gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.DeviceName -driverName $driverName -controllerIndex $gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.ControllerIndex

                Write-Output "input_device = ""$($controllerName)"""
                Write-Output "input_vendor_id = ""$($gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.VID)"""
                Write-Output "input_product_id = ""$($gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.PID)"""

                $lastInput.input | ForEach-Object { GetMappedControl -type $_.type -name $_.name -id $_.id -value $_.value }
            ) | Out-File "$retroWinRoot\authconfigs\$($controllerName).cfg"

            log("config file written to $retroWinRoot\authconfigs\$($controllerName).cfg")
        }

    }

    $commandString = "emu -L 'Emulators\retroarch\cores\" + $($coreName) + " " + $($romPath)

    $commandString += " | Out-Null"

    $commandString

    Invoke-Expression $commandString 

}
Catch {
    $ErrorMessage = $_.Exception.Message
    log("Error in retroarch.ps1 : $ErrorMessage")
}