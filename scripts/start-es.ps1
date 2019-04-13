$scriptPath = Split-Path -Path $MyInvocation.MyCommand.Path 
$retroWinRoot = (Get-Item $scriptPath).Parent.FullName

function log([string]$text) {
    Add-Content "$retroWinRoot\last-run.log" "$([DateTime]::Now.ToString()) [START-ES] $($text)"
}

Try {
    
    log("Starting esinput-watcher")

    start-job -name "eswatcherjob" -filepath "$($retroWinRoot)\scripts\start-esinput-watcher.ps1" -Arg $retroWinRoot

    log("Starting ES")
        
    $env:HOME = "$($retroWinRoot)\"
               
    $process = "$($retroWinRoot)\emulationstation\emulationstation.exe"
    $processArgs = "" #"--windowed --resolution 1024 768"

    log("Launching ES with command: $process $processArgs")

    #Start-Process -filepath $process -ArgumentList $processArgs -Wait
    Start-Process -filepath $process -Wait

    stop-job -name "eswatcherjob"
    remove-job -name "eswatcherjob"

    log("ES Closed")
}
Catch {
    $ErrorMessage = $_.Exception.Message
    log("Error running script : $ErrorMessage")
    log("Terminated abnormally")
}
