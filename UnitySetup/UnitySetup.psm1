﻿# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
Import-Module powershell-yaml -MinimumVersion '0.3' -ErrorAction Stop

[Flags()] 
enum UnitySetupComponent {
    Setup = (1 -shl 0)
    Documentation = (1 -shl 1)
    StandardAssets = (1 -shl 2)
    Windows_IL2CPP = (1 -shl 3)
    Metro = (1 -shl 4)
    UWP_IL2CPP = (1 -shl 5)
    Android = (1 -shl 6)
    iOS = (1 -shl 7)
    AppleTV = (1 -shl 8)
    Facebook = (1 -shl 9)
    Linux = (1 -shl 10)
    Mac = (1 -shl 11)
    Vuforia = (1 -shl 12)
    WebGL = (1 -shl 13)
    All = (1 -shl 14) - 1
}

class UnitySetupInstaller {
    [UnitySetupComponent] $ComponentType
    [UnityVersion] $Version
    [int64]$Length
    [DateTime]$LastModified
    [string]$DownloadUrl
}

class UnitySetupInstance {
    [UnityVersion]$Version
    [UnitySetupComponent]$Components
    [string]$Path

    UnitySetupInstance([UnityVersion]$version, [UnitySetupComponent]$components)
    {
        $this.Version = $version
        $this.Components = $components
    }
    
    UnitySetupInstance([string]$path) {
        
        $ivyPath = [io.path]::Combine("$path", 'Editor\Data\UnityExtensions\Unity\Networking\ivy.xml');
        if (!(Test-Path $ivyPath)) { throw "Path is not a Unity setup: $path"}
        [xml]$xmlDoc = Get-Content $ivyPath

        if ( !($xmlDoc.'ivy-module'.info.unityVersion)) {
            throw "Unity setup ivy is missing version: $ivyPath"
        }        

        $this.Path = $path
        $this.Version = $xmlDoc.'ivy-module'.info.unityVersion
        $this.Components = [UnitySetupComponent]::Setup

        $componentTests = @{
            [UnitySetupComponent]::Documentation = , "$Path\Editor\Data\Documentation";
            [UnitySetupComponent]::StandardAssets = , "$Path\Editor\Standard Assets";
            [UnitySetupComponent]::Windows_IL2CPP = , "$Path\Editor\Data\PlaybackEngines\windowsstandalonesupport\Variations\win32_development_il2cpp";
            [UnitySetupComponent]::Metro = "$Path\Editor\Data\PlaybackEngines\MetroSupport\Templates\UWP_.NET_D3D",
            "$Path\Editor\Data\PlaybackEngines\MetroSupport\Templates\UWP_D3D";
            [UnitySetupComponent]::UWP_IL2CPP = , "$Path\Editor\Data\PlaybackEngines\MetroSupport\Templates\UWP_IL2CPP_D3D";
            [UnitySetupComponent]::Android = , "$Path\Editor\Data\PlaybackEngines\AndroidPlayer";
            [UnitySetupComponent]::iOS = , "$Path\Editor\Data\PlaybackEngines\iOSSupport";
            [UnitySetupComponent]::AppleTV = , "$Path\Editor\Data\PlaybackEngines\AppleTVSupport";
            [UnitySetupComponent]::Facebook = , "$Path\Editor\Data\PlaybackEngines\Facebook";
            [UnitySetupComponent]::Linux = , "$Path\Editor\Data\PlaybackEngines\LinuxStandaloneSupport";
            [UnitySetupComponent]::Mac = , "$Path\Editor\Data\PlaybackEngines\MacStandaloneSupport";
            [UnitySetupComponent]::Vuforia = , "$Path\Editor\Data\PlaybackEngines\VuforiaSupport";
            [UnitySetupComponent]::WebGL = , "$Path\Editor\Data\PlaybackEngines\WebGLSupport";
        }

        $componentTests.Keys | ForEach-Object {
            foreach ( $test in $componentTests[$_] ) {
                if ( Test-Path -PathType Container -Path $test ) {
                    $this.Components += $_
                    break;
                }
            }
        }
    }
}

class UnityProjectInstance {
    [UnityVersion]$Version    
    [string]$Path
    
    UnityProjectInstance([string]$path) {
        $versionFile = [io.path]::Combine($path, "ProjectSettings\ProjectVersion.txt")
        if (!(Test-Path $versionFile)) { throw "Path is not a Unity project: $path"}

        $fileVersion = (Get-Content $versionFile -Raw | ConvertFrom-Yaml)['m_EditorVersion'];
        if (!$fileVersion) { throw "Project is missing a version in: $versionFile"}
        
        $this.Path = $path
        $this.Version = $fileVersion
    }
}

class UnityVersion : System.IComparable {
    [int] $Major;
    [int] $Minor;
    [int] $Revision;
    [char] $Release;
    [int] $Build;
    [string] $Suffix;

    [string] ToString() {
        $result = "$($this.Major).$($this.Minor).$($this.Revision)$($this.Release)$($this.Build)"
        if ( $this.Suffix ) { $result += "-$($this.Suffix)"}
        return $result
    }

    UnityVersion([string] $version) {
        $parts = $version.Split('-')

        $parts[0] -match "(\d+)\.(\d+)\.(\d+)([fpb])(\d+)" | Out-Null
        if ( $Matches.Count -ne 6 ) { throw "Invalid unity version: $version" } 
        $this.Major = [int]($Matches[1]);
        $this.Minor = [int]($Matches[2]);
        $this.Revision = [int]($Matches[3]);
        $this.Release = [char]($Matches[4]);
        $this.Build = [int]($Matches[5]);
        
        if ($parts.Length -gt 1) {
            $this.Suffix = $parts[1];
        }
    }

    [int] CompareTo([object]$obj) {
        if ($null -eq $obj) { return 1 }
        if ($obj -isnot [UnityVersion]) { throw "Object is not a UnityVersion"}
        
        return [UnityVersion]::Compare($this, $obj)
    }

    static [int] Compare([UnityVersion]$a, [UnityVersion]$b) {
        if ($a.Major -lt $b.Major) { return -1 }
        if ($a.Major -gt $b.Major) { return 1 }
        
        if ($a.Minor -lt $b.Minor) { return -1 }
        if ($a.Minor -gt $b.Minor) { return 1 }
        
        if ($a.Revision -lt $b.Revision) { return -1 }
        if ($a.Revision -gt $b.Revision) { return 1 }
        
        if ($a.Release -lt $b.Release) { return -1 }
        if ($a.Release -gt $b.Release) { return 1 }

        if ($a.Build -lt $b.Build) { return -1 }
        if ($a.Build -gt $b.Build) { return 1 }

        if ($a.Suffix -lt $b.Suffix) { return -1 }
        if ($a.Suffix -gt $b.Suffix) { return 1 }

        return 0
    }
}

<#
.Synopsis
   Help to create UnitySetupComponent   
.PARAMETER Components
   What components would you like included?
.EXAMPLE
   ConvertTo-UnitySetupComponent Setup,Metro
#>
function ConvertTo-UnitySetupComponent {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, Position = 0)]
        [UnitySetupComponent] $Component
    )

    $Component
}

<#
.Synopsis
   Finds UnitySetup installers for a specified version.
.DESCRIPTION
   Finds UnitySetup component installers for a specified version by querying Unity's website.
.PARAMETER Version
   What version of Unity are you looking for?
.PARAMETER Components
   What components would you like to search for? Defaults to All
.EXAMPLE
   Find-UnitySetupInstance -Version 2017.3.0f3
.EXAMPLE
   Find-UnitySetupInstance -Version 2017.3.0f3 -Components Setup,Documentation 
#>
function Find-UnitySetupInstance {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true)]
        [UnityVersion] $Version,

        [parameter(Mandatory = $false)]
        [UnitySetupComponent] $Components = [UnitySetupComponent]::All
    )

    $unitySetupRegEx = "^(.+)\/([a-z0-9]+)\/Windows64EditorInstaller\/UnitySetup64-(\d+)\.(\d+)\.(\d+)([fpb])(\d+).exe$"
    $knownBaseUrls = @(
        "https://download.unity3d.com/download_unity",
        "https://netstorage.unity3d.com/unity",
        "https://beta.unity3d.com/download"
    )

    $installerTemplates = @{
        [UnitySetupComponent]::Setup = , "Windows64EditorInstaller/UnitySetup64-$Version.exe";
        [UnitySetupComponent]::Documentation = , "WindowsDocumentationInstaller/UnityDocumentationSetup-$Version.exe";
        [UnitySetupComponent]::StandardAssets = , "WindowsStandardAssetsInstaller/UnityStandardAssetsSetup-$Version.exe";
        [UnitySetupComponent]::Metro = , "TargetSupportInstaller/UnitySetup-Metro-Support-for-Editor-$Version.exe";
        [UnitySetupComponent]::UWP_IL2CPP = , "TargetSupportInstaller/UnitySetup-UWP-IL2CPP-Support-for-Editor-$Version.exe";
        [UnitySetupComponent]::Android = , "TargetSupportInstaller/UnitySetup-Android-Support-for-Editor-$Version.exe";
        [UnitySetupComponent]::iOS = , "TargetSupportInstaller/UnitySetup-iOS-Support-for-Editor-$Version.exe";
        [UnitySetupComponent]::AppleTV = , "TargetSupportInstaller/UnitySetup-AppleTV-Support-for-Editor-$Version.exe";
        [UnitySetupComponent]::Facebook = , "TargetSupportInstaller/UnitySetup-Facebook-Games-Support-for-Editor-$Version.exe";
        [UnitySetupComponent]::Linux = , "TargetSupportInstaller/UnitySetup-Linux-Support-for-Editor-$Version.exe";
        [UnitySetupComponent]::Mac = "TargetSupportInstaller/UnitySetup-Mac-Support-for-Editor-$Version.exe",
        "TargetSupportInstaller/UnitySetup-Mac-Mono-Support-for-Editor-$Version.exe";
        [UnitySetupComponent]::Vuforia = , "TargetSupportInstaller/UnitySetup-Vuforia-AR-Support-for-Editor-$Version.exe";
        [UnitySetupComponent]::WebGL = , "TargetSupportInstaller/UnitySetup-WebGL-Support-for-Editor-$Version.exe";
        [UnitySetupComponent]::Windows_IL2CPP = , "TargetSupportInstaller/UnitySetup-Windows-IL2CPP-Support-for-Editor-$Version.exe";
    }

    # By default Tls12 protocol is not enabled, but is what backs Unity's website, so enable it
    $secProtocol = [System.Net.ServicePointManager]::SecurityProtocol
    if ( ($secProtocol -band [System.Net.SecurityProtocolType]::Tls12) -eq 0 ) {
        $secProtocol += [System.Net.SecurityProtocolType]::Tls12;
        [System.Net.ServicePointManager]::SecurityProtocol = $secProtocol
    }

    # Every release type has a different pattern for finding installers
    $searchPages = @()
    switch ($Version.Release) {
        'f' { $searchPages += "https://unity3d.com/get-unity/download/archive" }
        'b' { $searchPages += "https://unity3d.com/unity/beta/unity$Version" }
        'p' {
            $patchPage = "https://unity3d.com/unity/qa/patch-releases?version=$($Version.Major).$($Version.Minor)"
            $searchPages += $patchPage

            $webResult = Invoke-WebRequest $patchPage -UseBasicParsing 
            $searchPages += $webResult.Links | Where-Object { 
                $_.href -match "\/unity\/qa\/patch-releases\?version=$($Version.Major)\.$($Version.Minor)&amp;page=(\d+)" -and $Matches[1] -gt 1
            } | ForEach-Object {
                "https://unity3d.com/unity/qa/patch-releases?version=$($Version.Major).$($Version.Minor)&page=$($Matches[1])"
            }
        }
    }

    foreach ($page in $searchPages) {
        $webResult = Invoke-WebRequest $page -UseBasicParsing
        $prototypeLink = $webResult.Links | Select-Object -ExpandProperty href -ErrorAction SilentlyContinue | Where-Object { 
            $_ -match "$($installerTemplates[[UnitySetupComponent]::Setup])$" 
        }

        if ($null -ne $prototypeLink) { break }
    }
  
    if ($null -eq $prototypeLink) {
        throw "Could not find archives for Unity version $Version"
    }

    $linkComponents = $prototypeLink -split $unitySetupRegEx -ne ""

    if ($knownBaseUrls -notcontains $linkComponents[0]) {
        $knownBaseUrls = $linkComponents[0], $knownBaseUrls
    }
    else {
        $knownBaseUrls = $knownBaseUrls | Sort-Object -Property @{ Expression = {[math]::Abs(($_.CompareTo($linkComponents[0])))}; Ascending = $true}
    }
    
    $foundComponents = $installerTemplates.Keys |  Where-Object { $Components -band $_ } | ForEach-Object {
        $templates = $installerTemplates.Item($_);
        $found = $false
        for ($i = 0; -not $found -and $i -lt $templates.Length; ++$i ) {
            $template = $templates[$i]
            
            for( $j = 0; -not $found -and $j -lt $knownBaseUrls.Length; ++$j ) {
                $baseUrl = $knownBaseUrls[$j]
                $endpoint = [uri][System.IO.Path]::Combine($baseUrl, $linkComponents[1], $template);
                try {
                    Invoke-WebRequest $endpoint -Method HEAD -UseBasicParsing | Out-Null
                    $found = $true
                }
                catch {
                    Write-Verbose "$endpoint failed: $_"
                }
            }
        }

        if ( $found ) { $_ }
        else { Write-Warning "Unable to find installer for the $_ component." }
    }

    if( $foundComponents.Length -gt 0 )
    {
        [UnitySetupInstance]::new($Version, $foundComponents)
    }
}

<#
.Synopsis
   Installs a UnitySetup instance.
.DESCRIPTION
   Downloads and installs UnitySetup installers found via Find-UnitySetupInstaller.
.PARAMETER Installers
   What installers would you like to download and execute?
.PARAMETER Destination
   Where would you like the UnitySetup instance installed?
.PARAMETER Cache
   Where should the installers be cached. This defaults to $env:USERPROFILE\.unitysetup.
.EXAMPLE
   Find-UnitySetupInstaller -Version 2017.3.0f3 | Install-UnitySetupInstance
.EXAMPLE
   Find-UnitySetupInstaller -Version 2017.3.0f3 | Install-UnitySetupInstance -Destination D:\Unity-2017.3.0f3
#>
function Install-UnitySetupInstance {
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Scope = 'Function')]
    param(
        [parameter(ValueFromPipeline = $true)]
        [UnitySetupInstaller[]] $Installers,

        [parameter(Mandatory = $false)]
        [string]$Destination,

        [parameter(Mandatory = $false)]
        [string]$Cache = [io.Path]::Combine($env:USERPROFILE, ".unitysetup"),

        [parameter(Mandatory = $false)]
        [ValidateSet('Open', 'RunAs')]
        [string]$Verb
    )

    process {
        if (!(Test-Path $Cache -PathType Container)) {
            New-Item $Cache -ItemType Directory -ErrorAction Stop | Out-Null
        }

        $localInstallers = @()
        $localDestinations = @()

        $downloadSource = @()
        $downloadDest = @()
        foreach ( $i in $Installers) {
            $fileName = [io.Path]::GetFileName($i.DownloadUrl)
            $destPath = [io.Path]::Combine($Cache, "Installers\Unity-$($i.Version)\$fileName")

            $localInstallers += , $destPath
            if ($Destination) {
                $localDestinations += , $Destination
            }
            else {
                $localDestinations += , "C:\Program Files\Unity-$($i.Version)"
            }

            if ( Test-Path $destPath ) {   
                $destItem = Get-Item $destPath
                if ( ($destItem.Length -eq $i.Length ) -and ($destItem.LastWriteTime -eq $i.LastModified) ) {
                    Write-Verbose "Skipping download because it's already in the cache: $($i.DownloadUrl)"
                    continue
                }
            }

            $downloadSource += $i.DownloadUrl
            $downloadDest += $destPath
        }

        if ( $downloadSource.Length -gt 0 ) {
            for ($i = 0; $i -lt $downloadSource.Length; $i++) {
                Write-Verbose "Downloading $($downloadSource[$i]) to $($downloadDest[$i])"
                $destDirectory = [io.path]::GetDirectoryName($downloadDest[$i])
                if (!(Test-Path $destDirectory -PathType Container)) {
                    New-Item "$destDirectory" -ItemType Directory | Out-Null
                }
            }
        
            Start-BitsTransfer -Source $downloadSource -Destination $downloadDest
        }
       
        $spins = @('|', '/', '-', '\')
        for ($i = 0; $i -lt $localInstallers.Length; $i++) {
            $installer = $localInstallers[$i]
            $destination = $localDestinations[$i]

            $startProcessArgs = @{
                'FilePath' = $installer;
                'ArgumentList' = @("/S", "/D=$($localDestinations[$i])");
                'PassThru' = $true;
            }

            if ($Verb) {
                $startProcessArgs['Verb'] = $Verb
            }
            
            $spinnerIndex = 0
            $process = Start-Process @startProcessArgs
            while (!$process.HasExited) {
                Write-Host "`rInstalling $installer to $destination - $($spins[$spinnerIndex++ % $spins.Length])" -NoNewline
                Start-Sleep -Milliseconds 100
            }

            if ( $process.ExitCode -ne 0) {
                Write-Host "`bFailed."
                Write-Error "Installing $installer failed with exit code: $($process.ExitCode)"
            }
            else { 
                Write-Host "`bSucceeded."
            }
        }
    }
}

<#
.Synopsis
   Uninstall Unity Setup Instances
.DESCRIPTION
   Uninstall the specified Unity Setup Instances 
.PARAMETER Instance
   What instances of UnitySetup should be uninstalled
.EXAMPLE
   Get-UnitySetupInstance | Uninstall-UnitySetupInstance
#>
function Uninstall-UnitySetupInstance {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [UnitySetupInstance[]] $Instances
    )

    process {
        foreach ( $setupInstance in $Instances ) {
            $uninstaller = Get-ChildItem "$($setupInstance.Path)" -Filter 'Uninstall.exe' -Recurse |
                Select-Object -First 1 -ExpandProperty FullName

            if ($null -eq $uninstaller) { 
                Write-Error "Could not find Uninstaller.exe under $($setupInstance.Path)"
                continue
            }

            $startProcessArgs = @{
                'FilePath' = $uninstaller;
                'PassThru' = $true;
                'Wait' = $true;
                'ErrorAction' = 'Stop';
                'ArgumentList' = @("/S");
            }

            if ( -not $PSCmdlet.ShouldProcess("$uninstaller", "Start-Process")) { continue }

            $process = Start-Process @startProcessArgs
            if ( $process.ExitCode -ne 0 ) {
                Write-Error "Uninstaller quit with non-zero exit code"
            }
        }
    }
}

<#
.Synopsis
   Get the Unity versions installed
.DESCRIPTION
   Get the Unity versions installed and their locations
.PARAMETER BasePath
   Under what base patterns should we look for Unity installs?
.EXAMPLE
   Get-UnitySetupInstance
#>
function Get-UnitySetupInstance {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $false)]
        [string[]] $BasePath = @('C:\Program Files*\Unity*', 'C:\Program Files\Unity\Hub\Editor\*')
    )

    foreach ( $folder in $BasePath ) {
        $path = [io.path]::Combine("$folder", 'Editor\Data\UnityExtensions\Unity\Networking\ivy.xml');

        Get-ChildItem  $path -Recurse -ErrorAction Ignore | 
            ForEach-Object {
            [UnitySetupInstance]::new((Join-Path $_.Directory "..\..\..\..\..\" | Convert-Path))
        }
    }
}

<#
.Synopsis
   Selects a unity setup instance
.DESCRIPTION
   Given a set of unity setup instances, this will select the best one matching your requirements
.PARAMETER Latest
   Select the latest version available.
.PARAMETER Version
   Select only instances matching Version.
.PARAMETER Project
   Select only instances matching the version of the project at Project.
.PARAMETER instances
   The list of instances to Select from.
.EXAMPLE
   Get-UnitySetupInstance | Select-UnitySetupInstance -Latest
.EXAMPLE
   Get-UnitySetupInstance | Select-UnitySetupInstance -Version 2017.1.0f3
#>
function Select-UnitySetupInstance {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $false)]
        [switch] $Latest,

        [parameter(Mandatory = $false)]
        [UnityVersion] $Version,

        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [UnitySetupInstance[]] $Instances
    )
    
    process {
        if ( $Version ) { 
            $Instances = $Instances | Where-Object { [UnityVersion]::Compare($_.Version, $Version) -eq 0 }
        }

        if ( $Latest ) {
            foreach ( $i in $Instances ) { 
                if ( $null -eq $latestInstance -or [UnityVersion]::Compare($i.Version, $latestInstance.Version) -gt 0) {   
                    $latestInstance = $i
                } 
            }
        }
        elseif ( $Instances.Count -gt 0 ) { $Instances }
    }
    end {
        if ($latestInstance) { $latestInstance }
    }
}

<#
.Synopsis
   Get the Unity Projects under a specfied folder
.DESCRIPTION
   Recursively discovers Unity projects and their Unity version
.PARAMETER BasePath
   Under what base pattern should we look for Unity projects? Defaults to '$PWD'. 
.EXAMPLE
   Get-UnityProjectInstance
.EXAMPLE
   Get-UnityProjectInstance -BasePath .\MyUnityProjects -Recurse
#>
function Get-UnityProjectInstance {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $false)]
        [string] $BasePath = $PWD,

        [parameter(Mandatory = $false)]
        [switch] $Recurse
    )

    $args = @{
        'Path' = $BasePath;
        'Filter' = 'ProjectSettings';
        'ErrorAction' = 'Ignore';
        'Directory' = $true;
    }

    if ( $Recurse ) {
        $args['Recurse'] = $true;
    }

    Get-ChildItem @args |
        ForEach-Object {
        $path = [io.path]::Combine($_.FullName, "ProjectVersion.txt")
        if ( Test-Path $path ) {
            [UnityProjectInstance]::new((Join-Path $_.FullName "..\" | Convert-Path))
        }
    }
}

<#
.Synopsis
   Starts the Unity Editor
.DESCRIPTION
   If Project, Instance, and Latest are unspecified, tests if the current folder is a
   UnityProjectInstance, and if so, selects it as Project. Otherwise the latest
   UnitySetupInstance is selected as Instance.
.PARAMETER Project
   The project instance to open the Unity Editor for.
.PARAMETER Setup
   The setup instances to launch. If unspecified, the version at Project is selected.
.PARAMETER Latest
   Launch the latest version installed.
.PARAMETER Version
   Launch the specified version.
.PARAMETER IgnoreProjectContext
   Force operation as though $PWD is not a unity project.
.PARAMETER ExecuteMethod
   The script method for the Unity Editor to execute.
.PARAMETER OutputPath
   The output path that the Unity Editor should use.
.PARAMETER LogFile
   The log file for the Unity Editor to write to.
.PARAMETER BuildTarget
   The platform build target for the Unity Editor to start in.
.PARAMETER BatchMode
   Should the Unity Editor start in batch mode?
.PARAMETER Quit
   Should the Unity Editor quit after it's done?
.PARAMETER Wait
   Should the command wait for the Unity Editor to exit?
.EXAMPLE
   Start-UnityEditor
.EXAMPLE
   Start-UnityEditor -Latest
.EXAMPLE
   Start-UnityEditor -Version 2017.3.0f3
.EXAMPLE
   Start-UnityEditor -ExecuteMethod Build.Invoke -BatchMode -Quit -LogFile .\build.log -Wait
.EXAMPLE
   Get-UnityProjectInstance -Recurse | Start-UnityEditor -BatchMode -Quit
.EXAMPLE
   Get-UnitySetupInstance | Start-UnityEditor
#>
function Start-UnityEditor {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = "Context")]
    param(
        [parameter(Mandatory = $false, ValueFromPipeline = $true, ParameterSetName = 'Projects')]
        [parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'ProjectsLatest')]
        [parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'ProjectsVersion')]
        [ValidateNotNullOrEmpty()]
        [UnityProjectInstance[]] $Project,
        [parameter(Mandatory = $false, ValueFromPipeline = $true, ParameterSetName = 'Setups')]
        [ValidateNotNullOrEmpty()]
        [UnitySetupInstance[]]$Setup,
        [parameter(Mandatory = $true, ParameterSetName = 'Latest')]
        [parameter(Mandatory = $true, ParameterSetName = 'ProjectsLatest')]
        [switch]$Latest,
        [parameter(Mandatory = $true, ParameterSetName = 'Version')]
        [parameter(Mandatory = $true, ParameterSetName = 'ProjectsVersion')]
        [UnityVersion]$Version,
        [parameter(Mandatory = $false, ParameterSetName = 'Latest')]
        [parameter(Mandatory = $false, ParameterSetName = 'Version')]
        [parameter(Mandatory = $false, ParameterSetName = 'Context')]
        [switch]$IgnoreProjectContext,
        [parameter(Mandatory = $false)]
        [string]$ExecuteMethod,
        [parameter(Mandatory = $false)]
        [string[]]$ExportPackage,
        [parameter(Mandatory = $false)]
        [string]$ImportPackage,
        [parameter(Mandatory = $false)]
        [string]$CreateProject,
        [parameter(Mandatory = $false)]
        [string]$OutputPath,
        [parameter(Mandatory = $false)]
        [string]$LogFile,
        [parameter(Mandatory = $false)]
        [ValidateSet('StandaloneOSX', 'StandaloneWindows', 'iOS', 'Android', 'StandaloneLinux', 'StandaloneWindows64', 'WebGL', 'WSAPlayer', 'StandaloneLinux64', 'StandaloneLinuxUniversal', 'Tizen', 'PSP2', 'PS4', 'XBoxOne', 'N3DS', 'WiiU', 'tvOS', 'Switch')]
        [string]$BuildTarget,
        [parameter(Mandatory = $false)]
        [switch]$BatchMode,
        [parameter(Mandatory = $false)]
        [switch]$Quit,
        [parameter(Mandatory = $false)]
        [switch]$Wait,
        [parameter(Mandatory = $false)]
        [switch]$PassThru
    )
    process {  
        switch -wildcard ( $PSCmdlet.ParameterSetName ) {
            'Context' {
                $projectInstances = [UnityProjectInstance[]]@()
                $setupInstances = [UnitySetupInstance[]]@()

                $currentFolderProject = if ( !$IgnoreProjectContext ) { Get-UnityProjectInstance $PWD.Path }
                if ($null -ne $currentFolderProject) {
                    $projectInstances += , $currentFolderProject
                }
                else {
                    $setupInstance = Get-UnitySetupInstance | Select-UnitySetupInstance -Latest
                    if ($setupInstance.Count -gt 0) {
                        $setupInstances += , $setupInstance
                    }
                }
            }
            'Projects*' { 
                $projectInstances = $Project
                $setupInstances = [UnitySetupInstance[]]@()
            }
            'Setups' { 
                $projectInstances = [UnityProjectInstance[]]@()
                $setupInstances = $Setup
            }
            'Latest' {
                $projectInstances = [UnityProjectInstance[]]@()
                
                $currentFolderProject = if (!$IgnoreProjectContext) { Get-UnityProjectInstance $PWD.Path }
                if ($null -ne $currentFolderProject) {
                    $projectInstances += , $currentFolderProject
                }
                elseif ( $Latest ) {
                    $setupInstance = Get-UnitySetupInstance | Select-UnitySetupInstance -Latest
                    if ($setupInstance.Count -gt 0) {
                        $setupInstances = , $setupInstance
                    }
                }
            }
            'Version' {
                $projectInstances = [UnityProjectInstance[]]@()

                $currentFolderProject = if (!$IgnoreProjectContext) { Get-UnityProjectInstance $PWD.Path }
                if ($null -ne $currentFolderProject) {
                    $projectInstances += , $currentFolderProject
                }
                elseif ($null -ne $Version) {
                    $setupInstance = Get-UnitySetupInstance | Select-UnitySetupInstance -Version $Version
                    if ($setupInstance.Count -gt 0) {
                        $setupInstances = , $setupInstance
                    }
                    else {
                        Write-Error "Could not find Unity Editor for version $Version"
                    }
                }
            }
        }

        $sharedArgs = @()
        if ( $CreateProject ) { $sharedArgs += "-createProject", $CreateProject }
        if ( $ExecuteMethod ) { $sharedArgs += "-executeMethod", $ExecuteMethod }
        if ( $OutputPath ) { $sharedArgs += "-buildOutput", $OutputPath }
        if ( $LogFile ) { $sharedArgs += "-logFile", $LogFile }
        if ( $BuildTarget ) { $sharedArgs += "-buildTarget", $BuildTarget }
        if ( $BatchMode ) { $sharedArgs += "-batchmode" }
        if ( $Quit ) { $sharedArgs += "-quit" }
        if ( $ExportPackage ) { $sharedArgs += "-exportPackage", "$ExportPackage" }
        if ( $ImportPackage ) { $sharedArgs += "-importPackage", "$ImportPackage" }

        $instanceArgs = @()
        foreach ( $p in $projectInstances ) { 
            
            if ( $Latest ) {
                $setupInstance = Get-UnitySetupInstance | Select-UnitySetupInstance -Latest
                if ($setupInstance.Count -eq 0) {
                    Write-Error "Could not find any Unity Editor installed"
                    continue
                }
            }
            elseif ($null -ne $Version) {
                $setupInstance = Get-UnitySetupInstance | Select-UnitySetupInstance -Version $Version
                if ($setupInstance.Count -eq 0) {
                    Write-Error "Could not find Unity Editor for version $Version"
                    continue
                }
            }
            else {   
                $setupInstance = Get-UnitySetupInstance | Select-UnitySetupInstance -Version $p.Version
                if ($setupInstance.Count -eq 0) {
                    Write-Error "Could not find Unity Editor for version $($p.Version)"
                    continue
                }
            }
            
            $projectPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($($p.Path))
            $instanceArgs += , ("-projectPath", $projectPath)
            $setupInstances += , $setupInstance
        }

        for ($i = 0; $i -lt $setupInstances.Length; $i++) {
            $setupInstance = $setupInstances[$i]
            $editor = Get-ChildItem "$($setupInstance.Path)" -Filter 'Unity.exe' -Recurse | 
                Select-Object -First 1 -ExpandProperty FullName

            if ([string]::IsNullOrEmpty($editor)) {
                Write-Error "Could not find Unity.exe under setup instance path: $($setupInstance.Path)"
                continue
            }
            
            # clone the shared args list
            $unityArgs = $sharedArgs | ForEach-Object { $_ }
            if ( $instanceArgs[$i] ) { $unityArgs += $instanceArgs[$i] }
            $setProcessArgs = @{
                'FilePath' = $editor;
                'PassThru' = $true;
                'ErrorAction' = 'Stop';
            }

            if ($unityArgs -and $unityArgs.Length -gt 0) {
                $setProcessArgs['ArgumentList'] = $unityArgs
            }

            if (-not $PSCmdlet.ShouldProcess("$editor $unityArgs", "Start-Process")) {
                continue
            }

            $process = Start-Process @setProcessArgs
            if ( $Wait ) {
                $process.WaitForExit();
                if ( $process.ExitCode -ne 0 ) {
                    if ( $LogFile -and (Test-Path $LogFile -Type Leaf) ) {
                        Get-Content $LogFile | ForEach-Object { Write-Information -MessageData $_ -Tags 'Logs' }
                    }

                    Write-Error "Unity quit with non-zero exit code"
                }
            }

            if ($PassThru) { $process }
        }
    }
}

@(
    @{ 'Name' = 'gusi'; 'Value' = 'Get-UnitySetupInstance' },
    @{ 'Name' = 'gupi'; 'Value' = 'Get-UnityProjectInstance' },
    @{ 'Name' = 'susi'; 'Value' = 'Select-UnitySetupInstance' },
    @{ 'Name' = 'sue'; 'Value' = 'Start-UnityEditor' } 
) | ForEach-Object { 

    $alias = Get-Alias -Name $_.Name -ErrorAction 'SilentlyContinue'
    if( -not $alias ) {
        Write-Verbose "Creating new alias $($_.Name) for $($_.Value)" 
        New-Alias @_ 
    }
    elseif( $alias.ModuleName -eq 'UnitySetup' ) {
        Write-Verbose "Setting alias $($_.Name) to $($_.Value)" 
        Set-Alias @_
    }
    else {
        Write-Warning "Alias $($_.Name) already configured by $($alias.Source)"
    }
}