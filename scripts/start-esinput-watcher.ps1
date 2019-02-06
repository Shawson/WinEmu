
[cmdletbinding()]

param (
    [Parameter()][string]$retroWinRoot
)

function log([string]$text) {
    Add-Content "$retroWinRoot\es-start.log" "$([DateTime]::Now.ToString()) [ESINPUT-WATCHER] $($text)"
}

$env:HOME = "$($retroWinRoot)\"

log("Starting es_input.cfg listener")

$existingEvent = Get-EventSubscriber | Where { $_.SourceIdentifier -eq "ESINPUTCFG_WATCHER" } | Select -Last 1

if ($existingEvent -ne $null) {
    log("Watcher already registered- removing and recreating")
    Unregister-Event -SourceIdentifier "ESINPUTCFG_WATCHER"
}

# https://stackoverflow.com/questions/31795933/powershell-and-system-io-filesystemwatcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = "$($retroWinRoot)\.emulationstation\"
$watcher.Filter = "es_input.cfg"
$watcher.IncludeSubdirectories = $false
$watcher.EnableRaisingEvents = $true

$action = { 
    Try {
        log("es_input.cfg file change detected")

        # grab the latest entry
        $esInputXml = ( Select-Xml -Path "$($retroWinRoot)\.emulationstation\es_input.cfg" -XPath / ).Node
        $lastInput = $esInputXml.inputList.inputConfig | Select-Object -Last 1

        log("grabbing controller ids for $($lastInput.deviceName) $($lastInput.deviceGUID)")

        # call gpd to lookup the real ids
        $xml = Invoke-Expression "$($retroWinRoot)\tools\ESGamePadDetect\ESGamePadDetect.exe -deviceName=""$($lastInput.deviceName)"" -deviceGUID=""$($lastInput.deviceGUID)""" | Out-String
        $gpdOutput = (Select-Xml -Content $xml -XPath /).Node

        if ($gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.ResponseCode -ne 0) {
            log("Failed getting controller input")
            Return
        }

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
            Write-Output "input_driver = ""xinput"""
            Write-Output "input_device = ""$($gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.DeviceName)"""
            Write-Output "input_vendor_id = ""$($gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.VID)"""
            Write-Output "input_product_id = ""$($gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.PID)"""

            $lastInput.input | ForEach-Object { GetMappedControl -type $_.type -name $_.name -id $_.id -value $_.value }
        ) | Out-File "$retroWinRoot\autoconfigs\$($gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.DeviceName).cfg"

        log("config file written to $retroWinRoot\autoconfigs\$($gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.DeviceName).cfg")
    }
    Catch {
        log("Error in file watcher handler : $($_.Exception.Message)")
    }
}     

log ("Registering file watcher")

try {
    Register-ObjectEvent $watcher Changed -Action $action -SourceIdentifier "ESINPUTCFG_WATCHER"
}
catch {
    log ("Error registering event for file system watcher $($_.Exception.Message)")
}

while ($true) { Start-Sleep 1 }