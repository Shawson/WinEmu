function GetControllerName([string]$deviceName, [string]$driverName, [int]$controllerIndex)
{
    if ($driverName -eq "xinput")
    {
        if ($deviceName -like "*Xbox One For Windows*")
        {
            return "XBOX One Controller (User $($controllerIndex + 1))"
        }
        else {
            return "XInput Controller (User $($controllerIndex + 1))"
        }
    }

    return $deviceName
}

 function GetMappedControl([String]$type, [String]$name,[String]$id,[String]$value)
{
    switch ($type) 
    { 
        "button" { return GetButton -name $name -id $id } 
        "axis" { return GetAxis -name $name -id $id -value $value } 
        "hat" { return GetHat -name $name -id $id -value $value } 
    }
}

function GetButton([String]$name, [String]$id) {

    $mappedName = "unknown"

    switch($name){
        "a" { $mappedName = "input_a_btn" }
        "b" { $mappedName = "input_b_btn" }
        "x" { $mappedName = "input_x_btn" }
        "y" { $mappedName = "input_y_btn" }
        "leftshoulder" { $mappedName = "input_l_btn" }
        "rightshoulder" { $mappedName = "input_r_btn" }
        "leftthumb" { $mappedName = "input_l3_btn" }
        "rightthumb" { $mappedName = "input_r3_btn" }
        "select" { $mappedName = "input_select_btn" }
        "start" { $mappedName = "input_start_btn" }
        "hotkeyenable" { $mappedName = "input_menu_toggle_btn" }
    }

    return "$($mappedName) = ""$($id)"""
}

function GetHat([String]$name, [String]$id, [String]$value) {
    
    switch($name){
        "down" { $mappedName = "input_down_btn" }
        "up" { $mappedName = "input_up_btn" } 
        "left" { $mappedName = "input_left_btn" }
        "right" { $mappedName = "input_right_btn" }
    }

    switch($value) {
        "1" { $hatValue = "up" }
        "2" { $hatValue = "right" }
        "4" { $hatValue = "down" }
        "8" { $hatValue = "left" }
    }

    return "$($mappedName) = ""h$($id)$($hatValue)"""
}

function GetAxis([String]$name, [String]$id, [String]$value) {

    switch($name){
        "leftanalogdown" { $mappedName = "input_l_y_minus_axis" }
        "leftanalogleft" { $mappedName = "input_l_x_minus_axis" } 
        "leftanalogright" { $mappedName = "input_l_x_plus_axis" }
        "leftanalogup" { $mappedName = "input_l_y_plus_axis" }
        "rightanalogdown" { $mappedName = "input_r_y_minus_axis" }
        "rightanalogleft" { $mappedName = "input_r_x_minus_axis" } 
        "rightanalogright" { $mappedName = "input_r_x_plus_axis" }
        "rightanalogup" { $mappedName = "input_r_y_plus_axis" } 
        "up" { $mappedName = "input_up_axis" } 
        "down" { $mappedName = "input_down_axis" } 
        "left" { $mappedName = "input_left_axis" } 
        "right" { $mappedName = "input_right_axis" } 
        "lefttrigger" { $mappedName = "input_l2_axis" } 
        "righttrigger" { $mappedName = "input_r2_axis" } 
    }

    switch($value)
    {
        "+1" { $sign = "+" }
        "1" { $sign = "+" }
        "-1" { $sign = "-" }
    }

    return "$($mappedName) = ""$($sign)$($id)"""
}
