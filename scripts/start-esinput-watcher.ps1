
[cmdletbinding()]

param (
    [Parameter()][string]$retroWinRoot = "E:\Emulation\RetroWinDev"
)

$env:HOME = "$($retroWinRoot)\"

Add-Content "$retroWinRoot\start-esinput-watcher.log" "$([DateTime]::Now.ToString()) Starting es_input.cfg listener"

$existingEvent = Get-EventSubscriber | Where { $_.SourceIdentifier -eq "ESINPUTCFG_WATCHER" } | Select -Last 1

if ($existingEvent -ne $null)
{
    Add-Content $retroWinRoot\start-esinput-watcher.log "$([DateTime]::Now.ToString()) Watcher already registered- removing and recreating"
    Unregister-Event -SourceIdentifier "ESINPUTCFG_WATCHER"
}

# https://stackoverflow.com/questions/31795933/powershell-and-system-io-filesystemwatcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = "$($retroWinRoot)\.emulationstation\"
$watcher.Filter = "es_input.cfg"
$watcher.IncludeSubdirectories = $false
$watcher.EnableRaisingEvents = $true

$action = { 
            # grab the latest entry
            $esInputXml = ( Select-Xml -Path "$($retroWinRoot)\.emulationstation\es_input.cfg" -XPath / ).Node
            $lastInput = $esInputXml.inputList.inputConfig | Select-Object -Last 1

            # call gpd to lookup the real ids
            $xml= Invoke-Expression "$($retroWinRoot)\tools\ESGamePadDetect\ESGamePadDetect.exe -deviceName=""$($lastInput.deviceName)"" -deviceGUID=""$($lastInput.deviceGUID)""" | Out-String
            $gpdOutput = (Select-Xml -Content $xml -XPath /).Node

            if ($gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.ResponseCode -ne 0)
            {
                Add-Content $retroWinRoot\start-esinput-watcher.log "$([DateTime]::Now.ToString()) Failed getting controller input"
                Return
            }

            # map emulation station to retrarch;
            Try {
                . ("$retroWinRoot\scripts\control-mapping-retroarch.ps1")
            }
            Catch {
                Add-Content $retroWinRoot\start-esinput-watcher.log "$([DateTime]::Now.ToString()) Could not find $retroWinRoot\scripts\control-mapping-retroarch.ps1"
                
                Return
            }

            $(
                Write-Output "input_driver = ""xinput"""
                Write-Output "input_device = ""$($gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.DeviceName)"""
                Write-Output "input_vendor_id = ""$($gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.VID)"""
                Write-Output "input_product_id = ""$($gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.PID)"""

                $lastInput.input | ForEach-Object { GetMappedControl -type $_.type -name $_.name -id $_.id -value $_.value }
            ) | Out-File "$retroWinRoot\autoconfigs\$($gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.DeviceName).cfg"

        }     

Add-Content $retroWinRoot\start-esinput-watcher.log "$([DateTime]::Now.ToString()) Registering file watcher"

try {
    Register-ObjectEvent $watcher Changed -Action $action -SourceIdentifier "ESINPUTCFG_WATCHER"
}
catch 
{
    Add-Content $retroWinRoot\start-esinput-watcher.log "$([DateTime]::Now.ToString()) Error $($_.Exception.Message)"
}

while ($true) { Start-Sleep 1 }