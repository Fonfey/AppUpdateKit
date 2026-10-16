#Start Omnissa Horizon

$vmwareviewx86 = 'C:\Program Files (x86)\Omnissa\Omnissa Horizon Client\horizon-client.exe'
$vmwareviewx64 = 'C:\Program Files\Omnissa\Omnissa Horizon Client\horizon-client.exe'
$horizonclientx64 = '"C:\Program Files\Omnissa\Omnissa Horizon Client\horizon-client.exe"'

if (test-path $vmwareviewx86){
	$client = $vmwareviewx86
}elseif (test-path $vmwareviewx64){
	$client = $vmwareviewx64
}elseif (test-path $horizonclientx64){
	$client = $horizonclientx64
}

start-process -filepath $client -argumentlist "-serverURL werkplek.cctg.nl -hideClientAfterLaunchSession true -connectUSBOnStartup false -connectUSBOnInsert false"