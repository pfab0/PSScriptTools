using namespace System.Collections.Generic;
using namespace Microsoft.PowerShell.PSResourceGet.UtilClasses;

Function Compare-Module {

    [cmdletbinding()]
    [OutputType('PSCustomObject')]
    [alias('cmo')]

    Param (
        [Parameter(
            Position = 0,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('modulename')]
        [string]$Name,
        [ValidateNotNullOrEmpty()]
        [string]$Gallery = 'PSGallery',

        [switch]$IncludePrerelease
    )

    Begin {

        Write-Verbose "[BEGIN  ] Starting: $($MyInvocation.MyCommand)"

        $progParam = @{
            Activity         = $MyInvocation.MyCommand
            Status           = 'Getting installed modules'
            CurrentOperation = 'Get-InstalledPSResource | Where-Object Type -eq Module' #'Get-InstalledPSResource -Type Module' doesn't exist yet....
            PercentComplete  = 25
        }

        Write-Progress @progParam

    } #begin

    Process {

        $gmoParams = @{}
        if ($Name) {
            $gmoParams.Add('Name', $Name)
        }

        $installed = Get-InstalledPSResource @gmoParams | Where-Object Type -EQ 'Module' #'Get-InstalledPSResource -Type Module' doesn't exist yet....

        # need only the most recent version for each module

        $installedMostRecentVersion = [List[PSResourceInfo]]::new()
        $installed | Group-Object -Property Name | ForEach-Object {
            $entry = $_.Group | Sort-Object -Property Version -Descending | Select-Object -First 1
            $installedMostRecentVersion.Add($entry)
        }

        $installed = $installedMostRecentVersion

        if ($installed) {

            $progParam.Status = 'Getting online modules'
            $progParam.CurrentOperation = "Find-PSResource -Type Module -Repository $Gallery"
            $progParam.PercentComplete = 50
            Write-Progress @progParam

            $fmoParams = @{
                Type       = 'Module'
                Repository = $Gallery
                #ErrorAction = 'Stop'
            }
            if ($Name) {
                $fmoParams.Add('Name', $Name)
            }
            else {
                $fmoParams.Add('Name', [string[]]$installed.Name)
            }
            if ($IncludePrerelease) {
                $fmoParams.Add('Prerelease', $True)
            }

            Try {
                $online = [List[PSResourceInfo]]::new()
                $online.AddRange([List[PSResourceInfo]] @(Find-PSResource @fmoParams))
            }
            Catch {
                Write-Warning "Failed to find online module(s). $($_.Exception.message)"
            }
            $progParam.status = "Comparing $($installed.count) installed modules to $($online.count) online modules."
            $progParam.percentComplete = 80
            Write-Progress @progParam

            $data = ($online).Where( { $installed.name -eq $_.name }) |
            Select-Object -Property Name,
            @{Name = 'OnlineVersion'; Expression = { $_.Version } },
            @{Name = 'InstalledVersion'; Expression = {
                    #save the name from the incoming online object
                    $name = $_.Name
                    $installed.Where( { $_.name -eq $name }).Version }
            },
            PublishedDate,
            @{Name = 'UpdateNeeded'; Expression = {
                    $name = $_.Name
                    $mostRecentVersion = $installed.Where( { $_.name -eq $name }).Version
                    
                    [version]$_.Version -gt [version]$mostRecentVersion
                }
            } | Sort-Object -Property Name

            $progParam.PercentComplete = 100
            $progParam.Completed = $True
            Write-Progress @progparam

            #write the results to the pipeline
            $data
        }
        else {
            Write-Warning 'No local module or modules found'
        }
    } #Progress

    End {
        Write-Verbose "[END    ] Ending: $($MyInvocation.MyCommand)"
    } #end

} #close function

