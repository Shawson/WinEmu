
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

        Try {
            . ("$retroWinRoot\scripts\es-xml-tools.ps1")
        }
        Catch {
            log("Could not find $retroWinRoot\scripts\es-xml-tools.ps1")
            Return
        }

        $configFilePath = "$retroWinRoot\config\input.xml"
        
        if (![System.IO.File]::Exists($configFilePath)) {
            log("input.xml file doesnt exist: creating")
            [xml]$configFile = New-Object System.Xml.XmlDocument
            $root = $configFile.CreateElement("inputList")
            $configFile.AppendChild($root)
            $configFile.save($configFilePath)
        }
        
        $configFile = ( Select-Xml -Path "$retroWinRoot\config\input.xml" -XPath / ).Node
        
        $existingControllerDef = $configFile.inputList.inputConfig | Where-Object { 
            $_.deviceName -eq $gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.DeviceName -and
            $_.pid -eq $gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.PID -and
            $_.vid -eq $gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.VID -and
            $_.controllerIndex -eq $gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.ControllerIndex
        } | Select-Object -Last 1

        if ($existingControllerDef -eq $null) {

            log("did not find an entry for this controller: creating one")

            $existingControllerDef = $configFile.CreateElement("inputConfig")
            $existingControllerDef.SetAttribute("type",$lastInput.type)
            $existingControllerDef.SetAttribute("deviceName",$gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.DeviceName)
            $existingControllerDef.SetAttribute("deviceGUID",$lastInput.deviceGUID)
            $existingControllerDef.SetAttribute("pid",$gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.PID)
            $existingControllerDef.SetAttribute("vid",$gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.VID)
            $existingControllerDef.SetAttribute("controllerIndex",$gpdOutput.BaseCommandLineResponseOfGameControllerIdentifiers.Data.ControllerIndex)
            
            MakeInputNode $configFile $existingControllerDef "button" "a" 
            MakeInputNode $configFile $existingControllerDef "button" "b"
            MakeInputNode $configFile $existingControllerDef "button" "x"
            MakeInputNode $configFile $existingControllerDef "button" "y"
            MakeInputNode $configFile $existingControllerDef "button" "start"
            MakeInputNode $configFile $existingControllerDef "button" "select"
            MakeInputNode $configFile $existingControllerDef "button" "leftthumb"
            MakeInputNode $configFile $existingControllerDef "button" "rightthumb"
            MakeInputNode $configFile $existingControllerDef "button" "hotkeyenable"
            MakeInputNode $configFile $existingControllerDef "hat" "up"
            MakeInputNode $configFile $existingControllerDef "hat" "down"
            MakeInputNode $configFile $existingControllerDef "hat" "left"
            MakeInputNode $configFile $existingControllerDef "hat" "right"
            MakeInputNode $configFile $existingControllerDef "axis" "leftanalogup"
            MakeInputNode $configFile $existingControllerDef "axis" "leftanalogdown"
            MakeInputNode $configFile $existingControllerDef "axis" "leftanalogleft"
            MakeInputNode $configFile $existingControllerDef "axis" "leftanalogright"
            MakeInputNode $configFile $existingControllerDef "axis" "rightanalogup"
            MakeInputNode $configFile $existingControllerDef "axis" "rightanalogdown"
            MakeInputNode $configFile $existingControllerDef "axis" "rightanalogleft"
            MakeInputNode $configFile $existingControllerDef "axis" "rightanalogright"
            MakeInputNode $configFile $existingControllerDef "axis" "lefttrigger"
            MakeInputNode $configFile $existingControllerDef "axis" "righttrigger"

            SetInputNodeFromSourceNode $existingControllerDef $lastInput

            $configFile.SelectSingleNode('inputList').AppendChild($existingControllerDef)
        }
        else {
            log("found an entry for this controller: updating")
            SetInputNodeFromSourceNode $existingControllerDef $lastInput
        }

        $configFile.save($configFilePath)

        log("input.xml file saved")
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