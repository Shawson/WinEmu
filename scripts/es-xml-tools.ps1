
function MakeInputNode([System.Xml.XmlDocument]$document, [System.Xml.XmlElement]$newControllerElement, [string] $type, [string] $name) {

    $newNode = $document.CreateElement("input")
    $newNode.SetAttribute("name",$name)
    $newNode.SetAttribute("type",$type)
    $newNode.SetAttribute("id","")
    $newNode.SetAttribute("value","")

    $newControllerElement.AppendChild($newNode)
}

function SetInputNodeFromSourceNode([System.Xml.XmlElement] $destInputConfigNode, [System.Xml.XmlElement] $sourceInputConfigNode) {

    $destInputConfigNode.input | ForEach-Object {

        $current = $_

        $source = $sourceInputConfigNode.input | Where-Object { $_.name -eq $current.name } | Select-Object -Last 1

        if ($source -ne $null) {
            $current.SetAttribute("id",$source.id)
            $current.SetAttribute("value",$source.value)
        }
        else {
            $current.SetAttribute("id","")
            $current.SetAttribute("value","")
        }

    }
}