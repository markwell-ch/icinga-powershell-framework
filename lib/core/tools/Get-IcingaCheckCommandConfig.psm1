<#
.SYNOPSIS
   Exports command as JSON for icinga director

.DESCRIPTION
   Get-IcingaCheckCommandConfig returns a JSON-file of one or all 'Invoke-IcingaCheck'-Commands, which can be imported via Icinga-Director
   When no single command is specified all commands will be exported, and vice versa.

   More Information on https://github.com/Icinga/icinga-powershell-framework

.FUNCTIONALITY
   This module is intended to be used to export one or all PowerShell-Modules with the namespace 'Invoke-IcingaCheck'.
   The JSON-Export, which will be egenerated through this module is structured like an Icinga-Director-JSON-Export, so it can be imported via the Icinga-Director the same way.

.EXAMPLE
   PS>Get-IcingaCheckCommandConfig
   Check Command JSON for the following commands:
   - 'Invoke-IcingaCheckBiosSerial'
   - 'Invoke-IcingaCheckCPU'
   - 'Invoke-IcingaCheckProcessCount'
   - 'Invoke-IcingaCheckService'
   - 'Invoke-IcingaCheckUpdates'
   - 'Invoke-IcingaCheckUptime'
   - 'Invoke-IcingaCheckUsedPartitionSpace'
   - 'Invoke-IcingaCheckUsers'
############################################################

.EXAMPLE
   Get-IcingaCheckCommandConfig -OutDirectory 'C:\Users\icinga\config-exports'
   The following commands have been exported:
   - 'Invoke-IcingaCheckBiosSerial'
   - 'Invoke-IcingaCheckCPU'
   - 'Invoke-IcingaCheckProcessCount'
   - 'Invoke-IcingaCheckService'
   - 'Invoke-IcingaCheckUpdates'
   - 'Invoke-IcingaCheckUptime'
   - 'Invoke-IcingaCheckUsedPartitionSpace'
   - 'Invoke-IcingaCheckUsers'
   JSON export created in 'C:\Users\icinga\config-exports\PowerShell_CheckCommands_09-13-2019-10-55-1989.json'

.EXAMPLE
   Get-IcingaCheckCommandConfig Invoke-IcingaCheckBiosSerial, Invoke-IcingaCheckCPU -OutDirectory 'C:\Users\icinga\config-exports'
   The following commands have been exported:
   - 'Invoke-IcingaCheckBiosSerial'
   - 'Invoke-IcingaCheckCPU'
   JSON export created in 'C:\Users\icinga\config-exports\PowerShell_CheckCommands_09-13-2019-10-58-5342.json'

.PARAMETER CheckName
   Used to specify an array of commands which should be exported.
   Seperated with ','

.INPUTS
   System.Array

.OUTPUTS
   System.String

.LINK
   https://github.com/Icinga/icinga-powershell-framework

.NOTES
#>

function Get-IcingaCheckCommandConfig()
{
    param(
        [Parameter(ValueFromPipeline)]
        [array]$CheckName,
        [string]$OutDirectory
    );

    # Check whether all Checks will be exported or just the ones specified
    if ([string]::IsNullOrEmpty($CheckName) -eq $true) {
        $CheckName = (Get-Command Invoke-IcingaCheck*).Name
    }

    [int]$FieldID = 2;              # Starts at '2', because '0' and '1' are reserved for 'Verbose' and 'NoPerfData'
    [hashtable]$Basket = @{};

    # Define basic hashtable structure by adding fields: "Datafield", "DataList", "Command"
    $Basket.Add('Datafield', @{});
    $Basket.Add('DataList', @{});
    $Basket.Add('Command', @{});

    # At first generate a base Check-Command we can use as import source for all other commands
    $Basket.Command.Add(
        'PowerShell Base',
        @{
            'arguments'       = @{};
            'command'         = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe';
            'disabled'        = $FALSE;
            'fields'          = @();
            'imports'         = @();
            'is_string'       = $NULL;
            'methods_execute' = 'PluginCheck';
            'object_name'     = 'PowerShell Base';
            'object_type'     = 'object';
            'timeout'         = '180';
            'vars'            = @{};
            'zone'            = $NULL;
        }
    );

    # Loop through ${CheckName}, to get information on every command specified/all commands.
    foreach ($check in $CheckName) {
    
        # Get necessary syntax-information and more through cmdlet "Get-Help"
        $Data            = (Get-Help $check);
        $ParameterList   = (Get-Command -Name $check).Parameters;
        $PluginNameSpace = $Data.Name.Replace('Invoke-', '');

        # Add command Structure
        $Basket.Command.Add(
            $Data.Name, @{
                'arguments'   = @{
                    # Set the Command handling for every check command
                    '-C' = @{
                        'value' = [string]::Format('Use-Icinga; exit {0}', $Data.Name);
                        'order' = '0';
                    }
                }
                'fields'      = @();
                'imports'     = @( 'PowerShell Base' );
                'object_name' = $Data.Name;
                'object_type' = 'object';
                'vars'        = @{};
            }
        );

        # Loop through parameters of a given command
        foreach ($parameter in $Data.parameters.parameter) {

            $IsDataList      = $FALSE;

            # IsNumeric-Check on position to determine the order-value
            If (Test-Numeric($parameter.position) -eq $TRUE) {
                [string]$Order = [int]$parameter.position + 1;
            } else {
                [string]$Order = 99
            }

            $IcingaCustomVariable = [string]::Format('${0}_{1}_{2}$', $PluginNameSpace, (Get-Culture).TextInfo.ToTitleCase($parameter.type.name), $parameter.Name);

            # Todo: Should we improve this? Actually the handling would be identical, we just need to assign
            #       the proper field for this
            if ($IcingaCustomVariable -like '*_Int32_Verbose$' -Or $IcingaCustomVariable -like '*_Int_Verbose$' -Or $IcingaCustomVariable -like '*_Object_Verbose$') {
                $IcingaCustomVariable = [string]::Format('${0}_Int_Verbose$', $PluginNameSpace);
            }

            # Add arguments to a given command
            if ($parameter.type.name -eq 'switch') {
                $Basket.Command[$Data.Name].arguments.Add(
                    [string]::Format('-{0}', $parameter.Name), @{
                        'set_if' = $IcingaCustomVariable;
                        'set_if_format' = 'string';
                        'order' = $Order;
                    }
                );

                $Basket.Command[$Data.Name].vars.Add($parameter.Name, $FALSE);

            # Conditional whether type of parameter is array
            } elseif ($parameter.type.name -eq 'array') {
                $Basket.Command[$Data.Name].arguments.Add(
                    [string]::Format('-{0}', $parameter.Name), @{
                        'value' = @{
                            'type' = 'Function';
                            'body' = [string]::Format(
                                'var arr = macro("{0}");{1}if (len(arr) == 0) {2}{1}return "$null";{1}{3}{1}return arr.join(",");',
                                $IcingaCustomVariable,
                                "`r`n",
                                '{',
                                '}'
                            );
                        }
                        'order' = $Order;
                    }
                );
            } else {
                # Default to Object
                $Basket.Command[$Data.Name].arguments.Add(
                    [string]::Format('-{0}', $parameter.Name), @{
                        'value' = $IcingaCustomVariable;
                        'order' = $Order;
                    }
                );
            }

            # Determine wether a parameter is required based on given syntax-information
            if ($parameter.required -eq $TRUE) {
                $Required = 'y';
            } else {
                $Required = 'n';
            }

            $IcingaCustomVariable = [string]::Format('{0}_{1}_{2}', $PluginNameSpace, (Get-Culture).TextInfo.ToTitleCase($parameter.type.name), $parameter.Name);

            # Todo: Should we improve this? Actually the handling would be identical, we just need to assign
            #       the proper field for this
            if ($IcingaCustomVariable -like '*_Int32_Verbose' -Or $IcingaCustomVariable -like '*_Int_Verbose' -Or $IcingaCustomVariable -like '*_Object_Verbose') {
                $IcingaCustomVariable = [string]::Format('{0}_Int_Verbose', $PluginNameSpace);
            }

            [bool]$ArgumentKnown = $FALSE;

            foreach ($argument in $Basket.Datafield.Keys) {
                if ($Basket.Datafield[$argument].varname -eq $IcingaCustomVariable) {
                    $ArgumentKnown = $TRUE;
                    break;
                }
            }

            if ($ArgumentKnown) {
                continue;
            }

            $DataListName = [string]::Format('{0} {1}', $PluginNameSpace, $parameter.Name);

            if ($null -ne $ParameterList[$parameter.Name].Attributes.ValidValues) {
                $IcingaDataType = 'Datalist';
                Add-PowerShellDataList -Name $DataListName -Basket $Basket -Arguments $ParameterList[$parameter.Name].Attributes.ValidValues;
                $IsDataList = $TRUE;
            } elseif ($parameter.type.name -eq 'SwitchParameter') {
                $IcingaDataType = 'Boolean';
            } elseif ($parameter.type.name -eq 'Object') {
                $IcingaDataType = 'String';
            } elseif ($parameter.type.name -eq 'Array') {
                $IcingaDataType = 'Array';
            } elseif ($parameter.type.name -eq 'Int' -Or $parameter.type.name -eq 'Int32') {
                $IcingaDataType = 'Number';
            } else {
                $IcingaDataType = 'String';
            }

            $IcingaDataType = [string]::Format('Icinga\Module\Director\DataType\DataType{0}', $IcingaDataType)

            if ($Basket.Datafield.Values.varname -ne $IcingaCustomVariable) {
                $Basket.Datafield.Add(
                    [string]$FieldID, @{
                        'varname' = $IcingaCustomVariable;
                        'caption' = $parameter.Name;
                        'description' = $parameter.Description.Text;
                        'datatype' = $IcingaDataType;
                        'format' = $NULL;
                        'originalId' = [string]$FieldID;
                    }
                );

                if ($IsDataList) {
                    $Basket.Datafield[[string]$FieldID].Add(
                        'settings', @{
                            'datalist' = $DataListName;
                            'datatype' = 'string';
                            'behavior' = 'strict';
                        }
                    );
                } else {
                    $Basket.Datafield[[string]$FieldID].Add(
                        'settings', @{
                            'visbility' = 'visible';
                        }
                    );
                }

                # Increment FieldID, so unique datafields are added.
                [int]$FieldID = [int]$FieldID + 1;
            }

            # Increment FieldNumeration, so unique fields for a given command are added.
            [int]$FieldNumeration = [int]$FieldNumeration + 1;
        }
    }

    foreach ($check in $CheckName) {
        [int]$FieldNumeration = 0;

        $Data            = (Get-Help $check)
        $PluginNameSpace = $Data.Name.Replace('Invoke-', '');

        foreach ($parameter in $Data.parameters.parameter) {
            $IcingaCustomVariable = [string]::Format('{0}_{1}_{2}', $PluginNameSpace, (Get-Culture).TextInfo.ToTitleCase($parameter.type.name), $parameter.Name);

            # Todo: Should we improve this? Actually the handling would be identical, we just need to assign
            #       the proper field for this
            if ($IcingaCustomVariable -like '*_Int32_Verbose' -Or $IcingaCustomVariable -like '*_Int_Verbose' -Or $IcingaCustomVariable -like '*_Object_Verbose') {
                $IcingaCustomVariable = [string]::Format('{0}_Int_Verbose', $PluginNameSpace);
            }

            foreach ($DataFieldID in $Basket.Datafield.Keys) {
                [string]$varname = $Basket.Datafield[$DataFieldID].varname;
                if ([string]$varname -eq [string]$IcingaCustomVariable) {
                    $Basket.Command[$Data.Name].fields +=  @{
                        'datafield_id' = [int]$DataFieldID;
                        'is_required'  = $Required;
                        'var_filter'   = $NULL;
                    };
                }
            }
        }
    }

    # Build Filename with given Timestamp
    $TimeStamp = (Get-Date -Format "MM-dd-yyyy-HH-mm-ffff");
    $FileName = "PowerShell_CheckCommands_$TimeStamp.json";

    # Generate JSON Output from Hashtable
    $output = ConvertTo-Json -Depth 100 $Basket -Compress;

    # Determine whether json output via powershell or in file (based on param -OutDirectory)
    if ([string]::IsNullOrEmpty($OutDirectory) -eq $false) {
        $OutDirectory = (Join-Path -Path $OutDirectory -ChildPath $FileName);
        if ((Test-Path($OutDirectory)) -eq $false) {
            New-Item -Path $OutDirectory -Force | Out-Null;
        }

        if ((Test-Path($OutDirectory)) -eq $false) {
            throw 'Failed to create specified directory. Please try again or use a different target location.';
        }
        
        Set-Content -Path $OutDirectory -Value $output;

        # Output-Text
        Write-Host "The following commands have been exported:"
        foreach ($check in $CheckName) {
            Write-Host "- '$check'";
        }
        Write-Host "JSON export created in '${OutDirectory}'"
        return;
    }

    Write-Host "Check Command JSON for the following commands:"
    foreach ($check in $CheckName) {
        Write-Host "- '$check'"
    }
    Write-Host '############################################################';

    return $output;
}

function Add-PowerShellDataList()
{
    param(
        $Name,
        $Basket,
        $Arguments
    );

    $Basket.DataList.Add(
        $Name, @{
            'list_name'  = $Name;
            'owner'      = $env:username;
            'originalId' = '2';
            'entries'    = @();
        }
    );

    foreach ($entry in $Arguments) {
        $Basket.DataList[$Name]['entries'] += @{
            'entry_name'    = $entry;
            'entry_value'   = $entry;
            'format'        = 'string';
            'allowed_roles' = $NULL;
        };
    }
}
