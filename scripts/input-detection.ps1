function GetAttachedControllersAndConfigs
{
    Param([System.Management.Automation.ScriptBlock]$processControllerDelegate)

    log("getting attached controllers")

    $xml = Invoke-Expression "$($retroWinRoot)\tools\ESGamePadDetect\ESGamePadDetect.exe -list" | Out-String
    $attachedControllers = (Select-Xml -Content $xml -XPath /).Node


    if ($attachedControllers.BaseCommandLineResponseOfListOfGameControllerIdentifiers.ResponseCode -ne 0) {
        log("attachedControllers XML : $($xml)")
        log("Failed getting controller input - ResponseCode : $($attachedControllers.BaseCommandLineResponseOfListOfGameControllerIdentifiers.ResponseCode)")
        Return
    }

    log("successfully found controller ids- generating config")

    $inputConfigs = ( Select-Xml -Path "$retroWinRoot\config\input.xml" -XPath / ).Node

    $attachedControllers.BaseCommandLineResponseOfListOfGameControllerIdentifiers.Data.GameControllerIdentifiers | ForEach-Object {

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
            $processControllerDelegate.Invoke($thisAttachedController, $thisControllerInputConfig) # call the delegate passing in the controller to map
        }
        else {
            log("didn't find a matching controller input.xml for controller - attached controllers are $xml")
        }

    }
}