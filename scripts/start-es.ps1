$scriptPath = Split-Path -Path $MyInvocation.MyCommand.Path 
$retroWinRoot = (Get-Item $scriptPath).Parent.FullName

$(
    Try {
        "Starting ES"

        "Registering es_input.cfg watcher"

        # https://stackoverflow.com/questions/31795933/powershell-and-system-io-filesystemwatcher
        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path = "$($retroWinRoot)\.emulationstation\"
        $watcher.Filter = "es_input.cfg"
        $watcher.IncludeSubdirectories = $false
        $watcher.EnableRaisingEvents = $true  

        $action = { 
                    $path = $Event.SourceEventArgs.FullPath
                    $changeType = $Event.SourceEventArgs.ChangeType
                    $logline = "$(Get-Date), $changeType, $path"
                    Write-Host "Change detected : $($logline)"

                    # grab the latest entry
                    $esInputXml = ( Select-Xml -Path "$($retroWinRoot)\.emulationstation\es_input.cfg" -XPath / ).Node
                    $lastInput = $esInputXml.inputList.inputConfig | Select-Object -Last 1

                    # call gpd to lookup the real ids
                    $xml= Invoke-Expression "$($retroWinRoot)\tools\GamePadDetect\GamePadDetect.exe -deviceName=""$($lastInput.deviceName)"" -deviceGUID=""$($lastInput.deviceGUID)""" | Out-String
                    $gpdOutput = (Select-Xml -Content $xml -XPath /).Node

                    # map emulation station to retrarch;
                    Try {
                        . ("$scriptPath\control-mapping-retroarch.ps1")
                    }
                    Catch {
                        "Could not find $scriptPath\control-mapping-retroarch.ps1"
                        Return
                    }

                    $(
                        Write-Output "input_driver = ""xinput"""
                        Write-Output "input_device = ""$($gpdOutput.GameControllerIdentifiers.DeviceName)"""
                        Write-Output "input_vendor_id = ""$($gpdOutput.GameControllerIdentifiers.VID)"""
                        Write-Output "input_product_id = ""$($gpdOutput.GameControllerIdentifiers.PID)"""

                        $lastInput.input | ForEach-Object { GetMappedControl -type $_.type -name $_.name -id $_.id -value $_.value }
                    ) | Tee-Object -FilePath "$retroWinRoot\autoconfigs\$($gpdOutput.GameControllerIdentifiers.DeviceName).cfg"
                }    

        $created = Register-ObjectEvent $watcher Changed -Action $action #-SourceIdentifier "ESINPUTCFG_WATCHER"

        $env:HOME = "$($retroWinRoot)\"
        $esCmd = "$($retroWinRoot)\emulationstation\emulationstation.exe --windowed | Out-Null"

        Invoke-Expression $esCmd
        
        "Unregistering es_input file watcher"
        Unregister-Event $created.Id
        $created.Dispose()
        $created = $null;

        "ES finished"
    }
    Catch {
        $ErrorMessage = $_.Exception.Message
        "Error running script : $ErrorMessage"
        "Terminated abnormally"
    }
) | Tee-Object -FilePath "$scriptPath\..\start-es.log"