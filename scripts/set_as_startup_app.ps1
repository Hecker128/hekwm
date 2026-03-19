# Script to add the daemon as a startup program for the current user.


$HEKWM = ".\bin\hekwm.exe"


$exe_path_abs = $executioncontext.sessionstate.path.GetUnresolvedProviderPathFromPSPath($HEKWM)

$reg_name = "HEKWM"
$reg_key_path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$reg_key = get-item -literalpath $reg_key_path

# Remove the old registry entry if it already exists.
if ($reg_key.getvalue($reg_name, $null) -ne $null) {
    remove-itemproperty -path $reg_key_path -name $reg_name
}

#Create the new registry entry.
new-itemproperty -path $reg_key_path -name $reg_name -value $exe_path_abs
