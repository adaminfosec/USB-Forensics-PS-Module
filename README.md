# USB-Forensics-PS-Module
USB Forensics PS Module combines [Get-USB](https://github.com/adaminfosec/Get-USB), [Get-DriveLetter](https://github.com/adaminfosec/Get-DriveLetter), and [Get-RegistryKeyTimestamp](https://github.com/proxb/PInvoke/blob/master/Get-RegistryKeyTimestamp.ps1) into one module for a complete USB forensics retrieval from a local Windows machine.

# Registry keys used
Get-USB parses the HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\USBSTOR registry.  
Get-DriveLetter parses the HKEY_LOCAL_MACHINE\SYSTEM\MountedDevices registry, but only grabs the \DosDevices\ entries.

# Dependencies
Get-USB requires the [Get-RegistryKeyTimestamp](https://github.com/proxb/PInvoke/blob/master/Get-RegistryKeyTimestamp.ps1) function to retrieve the first connected and last connected timestamps.  If you already have Get-RegistryKeyTimestamp installed, feel free to remove the function from the module.
