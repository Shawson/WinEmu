param (
    [Parameter()][string]$systemName,
    [Parameter()][string]$romPath
)

$scriptPath = Split-Path -Path $MyInvocation.MyCommand.Path 

$(
    Try {
        "Running rom-launcher"

        Try {
            . ("$scriptPath\drawmenu.ps1")
        }
        Catch {
            "Could not find $scriptPath\drawmenu.ps1"
            Return
        }

        $romFile = Split-Path -Path $romPath -Leaf
        $romName = [io.path]::GetFileNameWithoutExtension($romPath)
        $romExtension = [io.path]::GetExtension($romPath).Replace(".","").Replace("'","")

        "System Name : " + $systemName
        "Rom Path : " + $romPath
        "Rom Name : " + $romName
        "Rom Extension : " + $romExtension

        Write-Host "Rom Launcher starting $romName"

        $systemsXml = ( Select-Xml -Path "$($scriptPath)\..\config\systems.xml" -XPath / ).Node
        $systemSettings = $systemsXml.systems.system  | where { $_.name -eq $systemName.ToLower() }

        # grab the system default emulator
        $emulator = $systemSettings.emulator | where { $_.name -eq $systemSettings.defaultEmulator }

        if ($emulator -eq $null) 
        {
            $emulator = $systemSettings.emulator | Select-Object -first 1
        }

        "Selected default emulator for system : " + $emulator.name

        # check for any file extension overrides

        $extensionOverride = $systemSettings.emulator | where { $_.extensionOverrides | where { $_.extension -eq $romExtension.ToString() }  }

        if ($null -ne $extensionOverride) {
            $emulator = $extensionOverride
            "Selected emulator override based on file extension : " + $emulator.name
        }

        $showMenu = $false
        $showMenu = TimedPrompt "Launching $($romName) with $($emulator.displayname) - Press any key to change" 3

        if ($showMenu -eq $true)
        {
            "Opening selection menu"
        }

        $commandLine = "& $($scriptPath)\..\$($emulator.path.replace("%ROM%", $romPath)) | Out-Null"

        "Executing: " + $commandLine

        cd "$scriptPath\.."
        Invoke-Expression $commandLine

        "Emulator has finished"
    }
    Catch {
        $ErrorMessage = $_.Exception.Message
        "Error running script : $ErrorMessage"
        "Terminated abnormally"
    }
) | Tee-Object -FilePath "$scriptPath\..\last-run.log"