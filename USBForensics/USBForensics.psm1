Function Get-RegistryKeyTimestamp {
    <#
        .SYNOPSIS
            Retrieves the registry key timestamp from a local or remote system.
 
        .DESCRIPTION
            Retrieves the registry key timestamp from a local or remote system.
 
        .PARAMETER RegistryKey
            Registry key object that can be passed into function.
 
        .PARAMETER SubKey
            The subkey path to view timestamp.
 
        .PARAMETER RegistryHive
            The registry hive that you will connect to.
 
            Accepted Values:
            ClassesRoot
            CurrentUser
            LocalMachine
            Users
            PerformanceData
            CurrentConfig
            DynData
 
        .NOTES
            Name: Get-RegistryKeyTimestamp
            Author: Boe Prox
            Version History:
                1.0 -- Boe Prox 17 Dec 2014
                    -Initial Build
 
        .EXAMPLE
            $RegistryKey = Get-Item "HKLM:\System\CurrentControlSet\Control\Lsa"
            $RegistryKey | Get-RegistryKeyTimestamp | Format-List
 
            FullName      : HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Lsa
            Name          : Lsa
            LastWriteTime : 12/16/2014 10:16:35 PM
 
            Description
            -----------
            Displays the lastwritetime timestamp for the Lsa registry key.
 
        .EXAMPLE
            Get-RegistryKeyTimestamp -Computername Server1 -RegistryHive LocalMachine -SubKey 'System\CurrentControlSet\Control\Lsa' |
            Format-List
 
            FullName      : HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Lsa
            Name          : Lsa
            LastWriteTime : 12/17/2014 6:46:08 AM
 
            Description
            -----------
            Displays the lastwritetime timestamp for the Lsa registry key of the remote system.
 
        .INPUTS
            System.String
            Microsoft.Win32.RegistryKey
 
        .OUTPUTS
            Microsoft.Registry.Timestamp
    #>
    [OutputType('Microsoft.Registry.Timestamp')]
    [cmdletbinding(
        DefaultParameterSetName = 'ByValue'
    )]
    Param (
        [parameter(ValueFromPipeline=$True, ParameterSetName='ByValue')]
        [Microsoft.Win32.RegistryKey]$RegistryKey,
        [parameter(ParameterSetName='ByPath')]
        [string]$SubKey,
        [parameter(ParameterSetName='ByPath')]
        [Microsoft.Win32.RegistryHive]$RegistryHive,
        [parameter(ParameterSetName='ByPath')]
        [string]$Computername
    )
    Begin {
        #region Create Win32 API Object
        Try {
            [void][advapi32]
        } Catch {
            #region Module Builder
            $Domain = [AppDomain]::CurrentDomain
            $DynAssembly = New-Object System.Reflection.AssemblyName('RegAssembly')
            $AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run) # Only run in memory
            $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('RegistryTimeStampModule', $False)
            #endregion Module Builder
 
            #region DllImport
            $TypeBuilder = $ModuleBuilder.DefineType('advapi32', 'Public, Class')
 
            #region RegQueryInfoKey Method
            $PInvokeMethod = $TypeBuilder.DefineMethod(
                'RegQueryInfoKey', #Method Name
                [Reflection.MethodAttributes] 'PrivateScope, Public, Static, HideBySig, PinvokeImpl', #Method Attributes
                [IntPtr], #Method Return Type
                [Type[]] @(
                    [Microsoft.Win32.SafeHandles.SafeRegistryHandle], #Registry Handle
                    [System.Text.StringBuilder], #Class Name
                    [UInt32 ].MakeByRefType(),  #Class Length
                    [UInt32], #Reserved
                    [UInt32 ].MakeByRefType(), #Subkey Count
                    [UInt32 ].MakeByRefType(), #Max Subkey Name Length
                    [UInt32 ].MakeByRefType(), #Max Class Length
                    [UInt32 ].MakeByRefType(), #Value Count
                    [UInt32 ].MakeByRefType(), #Max Value Name Length
                    [UInt32 ].MakeByRefType(), #Max Value Name Length
                    [UInt32 ].MakeByRefType(), #Security Descriptor Size           
                    [long].MakeByRefType() #LastWriteTime
                ) #Method Parameters
            )
 
            $DllImportConstructor = [Runtime.InteropServices.DllImportAttribute].GetConstructor(@([String]))
            $FieldArray = [Reflection.FieldInfo[]] @(       
                [Runtime.InteropServices.DllImportAttribute].GetField('EntryPoint'),
                [Runtime.InteropServices.DllImportAttribute].GetField('SetLastError')
            )
 
            $FieldValueArray = [Object[]] @(
                'RegQueryInfoKey', #CASE SENSITIVE!!
                $True
            )
 
            $SetLastErrorCustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder(
                $DllImportConstructor,
                @('advapi32.dll'),
                $FieldArray,
                $FieldValueArray
            )
 
            $PInvokeMethod.SetCustomAttribute($SetLastErrorCustomAttribute)
            #endregion RegQueryInfoKey Method
 
            [void]$TypeBuilder.CreateType()
            #endregion DllImport
        }
        #endregion Create Win32 API object
    }
    Process {
        #region Constant Variables
        $ClassLength = 255
        [long]$TimeStamp = $null
        #endregion Constant Variables
 
        #region Registry Key Data
        If ($PSCmdlet.ParameterSetName -eq 'ByPath') {
            #Get registry key data
            $RegistryKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($RegistryHive, $Computername).OpenSubKey($SubKey)
            If ($RegistryKey -isnot [Microsoft.Win32.RegistryKey]) {
                Throw "Cannot open or locate $SubKey on $Computername"
            }
        }
 
        $ClassName = New-Object System.Text.StringBuilder $RegistryKey.Name
        $RegistryHandle = $RegistryKey.Handle
        #endregion Registry Key Data
 
        #region Retrieve timestamp
        $Return = [advapi32]::RegQueryInfoKey(
            $RegistryHandle,
            $ClassName,
            [ref]$ClassLength,
            $Null,
            [ref]$Null,
            [ref]$Null,
            [ref]$Null,
            [ref]$Null,
            [ref]$Null,
            [ref]$Null,
            [ref]$Null,
            [ref]$TimeStamp
        )
        Switch ($Return) {
            0 {
               #Convert High/Low date to DateTime Object
                $LastWriteTime = [datetime]::FromFileTime($TimeStamp)
 
                #Return object
                $Object = [pscustomobject]@{
                    FullName = $RegistryKey.Name
                    Name = $RegistryKey.Name -replace '.*\\(.*)','$1'
                    LastWriteTime = $LastWriteTime
                }
                $Object.pstypenames.insert(0,'Microsoft.Registry.Timestamp')
                $Object
            }
            122 {
                Throw "ERROR_INSUFFICIENT_BUFFER (0x7a)"
            }
            Default {
                Throw "Error ($return) occurred"
            }
        }
        #endregion Retrieve timestamp
    }
}

function Get-DriveLetter {

<#
.SYNOPSIS
Retrieves the \DosDevices\ registry information on a local computer from 
HKEY_LOCAL_MACHINE\SYSTEM\MountedDevices
.DESCRIPTION
Get-DriveLetter parses the mounted devices registry (HKEY_LOCAL_MACHINE\SYSTEM\MountedDevices) on the 
local computer for every \DosDevices\ entry.
Retrieves the data for each entry and translates the data into Ascii text.
.EXAMPLE
Get-DriveLetter

VolumeName     VolumeLetter AsciiData                                                      
----------     ------------ ---------                                                      
\DosDevices\C: C:           DMIO:ID:ªÄîmóK¤O@5yä                                       
\DosDevices\D: D:           DMIO:ID:¬?iBôGè_87                                       
\DosDevices\E: E:           Ö`é                                                          
\DosDevices\F: F:           :0ð                                                         
\DosDevices\G: G:           \??\SCSI#CdRom&Ven_DVD+R#RW&Prod_DX042D#4&17780f2c&0&050000#...
\DosDevices\H: H:           _??_USBSTOR#Disk&Ven_SanDisk&Prod_Cruzer_Glide&Rev_1.00#4C53...
\DosDevices\I: I:           DMIO:ID:5ÜmæBÎD®¡izm'                           
\DosDevices\J: J:           _??_USBSTOR#Disk&Ven_&Prod_USB_DISK_2.0&Rev_PMAP#C70049CB085...
#>

    $mountedDevicesPath = "HKLM:\SYSTEM\MountedDevices"
    $mountedDevices = Get-ItemProperty $mountedDevicesPath

    $drives = $mountedDevices | Get-Member | Select-Object -Property Name | 
              Where-Object -Property Name -Match "\\DosDevices\\\w:"

    foreach ($drive in $drives) {
        
        $driveName = $drive.Name
        $driveLetter = $driveName.Split('\')

        $decimalData = $mountedDevices."$driveName"
        
        #convert decimal data to Hexadecimal
        $hexadecimalData = $decimalData | foreach {"{0:x}" -f $_}
        $formatHex = ""
        foreach ($hexData in $hexadecimalData) {
            if ($hexData -ne 0) {
                $formatHex = $formatHex + " " + $hexData
            }
        }
        $hexTrim = $formatHex.Trim()
        $hexArraySplit = $hexTrim.Split(' ')
        
        #convert Hexadecimal data to Ascii
        $hexToAscii = $hexArraySplit | ForEach-Object {[char][byte]"0x$_"}
        $asciiString = $hexToAscii -join ""
        
        #create object properties
        $props = @{'VolumeName'=$driveName;
                   'DecimalData'=($decimalData -join '' + ' ');
                   'HexadecimalData'=($hexadecimalData -join '' + ' ');
                   'VolumeLetter'=$driveLetter[2];
                   'AsciiData'=$asciiString;
                   'RegistryPath'=$mountedDevicesPath;}

        #add properties to object
        $obj = New-Object -TypeName PSObject -Property $props
        $obj.PSObject.TypeNames.Insert(0,'AdamInfoSec.RegistryInfo')
        Write-Output $obj
    }
}

function Get-USB {
    
<#
.SYNOPSIS
Retrieves a history of USB devices on the local computer from 
default registry path HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\USBSTOR. 
.DESCRIPTION
Get-USB parses the USBSTOR registry to retrieve a list of USBs on the local computer.
By default the registry path used is "HKLM:\SYSTEM\ControlSet001\Enum\USBSTOR"
.PARAMETER Path
The registry path to USBSTOR. 
If not specified, the default value is "HKLM:\SYSTEM\ControlSet001\Enum\USBSTOR"
.EXAMPLE
Get-USB
.EXAMPLE
Get-USB -Path "HKLM:\SYSTEM\ControlSet001\Enum\USBSTOR"
.EXAMPLE
"HKLM:\SYSTEM\ControlSet001\Enum\USBSTOR" | Get-USB
#>
    Param(
        [Parameter(ValueFromPipeline=$True)]
        [string]$Path ='HKLM:\SYSTEM\ControlSet001\Enum\USBSTOR'
    )

    $deviceIDs = Get-ChildItem -Path $Path
    
    foreach ($deviceID in $deviceIDs) {
        
        $usbPath = Join-Path -Path $Path -ChildPath $deviceID.PSChildName
        $uniqueIDobj = Get-ChildItem -Path $usbPath
       
        $usbProperties = $uniqueIDobj | Get-ItemProperty
        
        $deviceIDtime = $deviceID | Get-RegistryKeyTimestamp
        $uniqueIDtime = $uniqueIDobj | Get-RegistryKeyTimestamp

        $props = @{'USBName'= $usbProperties.FriendlyName;
                   'DeviceID'= $deviceID.PSChildName;
                   'UniqueID'= $uniqueIDobj.PSChildName;
                   'FirstConnected'=$deviceIDtime.LastWriteTime
                   'LastConnected'=$uniqueIDtime.LastWriteTime}
        
        $obj = New-Object -TypeName PSObject -Property $props
        $obj.PSObject.TypeNames.Insert(0,'AdamInfoSec.USB.RegistryInfo')
        Write-Output $obj
    }
}