param (
    [Parameter()][string]$systemName,
    [Parameter()][string]$romPath
)

$scriptPath = Split-Path -Path $MyInvocation.MyCommand.Path 
$retroWinRoot = (Get-Item $scriptPath).Parent.FullName

#$(
    Try {
        function log([string]$text) {
            Add-Content "$retroWinRoot\last-run.log" "$([DateTime]::Now.ToString()) [rom-launcher] $($text)"
        }

        log("Running rom-launcher")

        Try {
            . ("$scriptPath\drawmenu.ps1")
        }
        Catch {
            log "Could not find $scriptPath\drawmenu.ps1"
            Return
        }

        $romFile = Split-Path -Path $romPath -Leaf
        $romName = [io.path]::GetFileNameWithoutExtension($romPath)
        $romExtension = [io.path]::GetExtension($romPath).Replace(".","").Replace("'","")

        log("System Name : $systemName")
        log("Rom Path : $romPath")
        log("Rom Name : $romName")
        log("Rom Extension : $romExtension")

        Write-Host "Rom Launcher starting $romName"

        $systemsXml = ( Select-Xml -Path "$($scriptPath)\..\config\systems.xml" -XPath / ).Node
        $systemSettings = $systemsXml.systems.system  | where { $_.name -eq $systemName.ToLower() }

        # grab the system default emulator
        $emulator = $systemSettings.emulator | where { $_.name -eq $systemSettings.defaultEmulator }

        if ($emulator -eq $null) 
        {
            $emulator = $systemSettings.emulator | Select-Object -first 1
        }

        log("Selected default emulator for system : $($emulator.name)")

        # check for any file extension overrides

        $extensionOverride = $systemSettings.emulator | where { $_.extensionOverrides | where { $_.extension -eq $romExtension.ToString() }  }

        if ($null -ne $extensionOverride) {
            $emulator = $extensionOverride
            log  "Selected emulator override based on file extension : " + $emulator.name
        }

        $showMenu = $false
        #$showMenu = TimedPrompt "Launching $($romName) with $($emulator.displayname) - Press any key to change" 1

        if ($showMenu -eq $true)
        {
            log ("Opening selection menu")
        }

        $commandLine = "& $($scriptPath)\..\$($emulator.path.replace("%ROM%", $romPath)) | Out-Null"

        log ("Executing: $commandLine")

        cd "$scriptPath\.."
        Invoke-Expression $commandLine

        log ("Emulator has finished")
    }
    Catch {
        $ErrorMessage = $_.Exception.Message
        log ("Error running script : $ErrorMessage")
        log ("Terminated abnormally")
    }
#) | Tee-Object -FilePath "$scriptPath\..\last-run.log"