Function Expand-Archive([string]$Path, [string]$Destination) {

    if ((test-path "${env:ProgramFiles(x86)}\7-Zip\7z.exe")) 
    {
        $7z_Application = "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
    } 
    else {
        if ((test-path "$env:ProgramW6432\7-Zip\7z.exe")) 
        {
            $7z_Application = "$env:ProgramW6432\7-Zip\7z.exe"
            
        } 
        else {
            throw "7Zip not found at ${env:ProgramFiles(x86)}\7-Zip\7z.exe or $env:ProgramW6432\7-Zip\7z.exe"
        }
    }

    $7z_Arguments = @(
        'x'                         ## eXtract files with full paths
        '-y'                        ## assume Yes on all queries
        "`"-o$($Destination)`""     ## set Output directory
        "`"$($Path)`""              ## <archive_name>
    )
    & $7z_Application $7z_Arguments 
}