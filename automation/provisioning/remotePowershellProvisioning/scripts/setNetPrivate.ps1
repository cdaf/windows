$NLMType = [Type]::GetTypeFromCLSID('DCB00C01-570F-4A9B-8D69-199FDBA5723B')

$INetworkListManager = [Activator]::CreateInstance($NLMType)

$NLM_ENUM_NETWORK_CONNECTED  = 1

$NLM_NETWORK_CATEGORY_PUBLIC = 0x00

$NLM_NETWORK_CATEGORY_PRIVATE = 0x01

$UNIDENTIFIED = "NOKIA 909_8529"

$INetworks = $INetworkListManager.GetNetworks($NLM_ENUM_NETWORK_CONNECTED)

foreach ($INetwork in $INetworks)

{

    $Name = $INetwork.GetName()

    $Category = $INetwork.GetCategory()

    if ($INetwork.IsConnected -and ($Category -eq $NLM_NETWORK_CATEGORY_PUBLIC) -and ($Name -eq $UNIDENTIFIED))

    {

        $INetwork.SetCategory($NLM_NETWORK_CATEGORY_PRIVATE)

    }

}