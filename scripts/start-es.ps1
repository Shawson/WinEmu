$scriptPath = Split-Path -Path $MyInvocation.MyCommand.Path 
$retroWinRoot = (Get-Item $scriptPath).Parent.FullName


    Try {
        
        "$([DateTime]::Now.ToString()) Starting ES"

        "$([DateTime]::Now.ToString()) Registering es_input.cfg watcher"

        start-job -name "start-esinput-watcher" -filepath "$($retroWinRoot)\scripts\start-esinput-watcher.ps1"
        
        $env:HOME = "$($retroWinRoot)\"
               
        $process="$($retroWinRoot)\emulationstation\emulationstation.exe"
        #$process="notepad.exe"
        $processArgs="--windowed --resolution 1024 768"

        "$([DateTime]::Now.ToString()) Launching ES with command: $process $processArgs"

        Start-Process -filepath $process -ArgumentList $processArgs -Wait

        stop-job -name "start-esinput-watcher"

        "$([DateTime]::Now.ToString()) ES Closed"
    }
    Catch {
        $ErrorMessage = $_.Exception.Message
        "$([DateTime]::Now.ToString()) Error running script : $ErrorMessage"
        "$([DateTime]::Now.ToString()) Terminated abnormally"
    }
