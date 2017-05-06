
<#
.SYNOPSIS
This is a Powershell script to download the output of the latest release distributed on Mobile Center.
.DESCRIPTION
This is a Powershell script to download the output of the latest release distributed on Mobile Center using their REST API with the parameters you provide.
.PARAMETER Owner
The owner of the app defined in Mobile Center.
.PARAMETER AppName
The name of the app defined in Mobile Center.
.PARAMETER MobileCenterApiKey
The Mobile Center API token.
.PARAMETER DownloadFileName
The name of the file to save to the build output to.
#>

Param(
    [Parameter(Mandatory=$true)]
    [string]$Owner,
    [Parameter(Mandatory=$true)]
    [string]$AppName,
    [Parameter(Mandatory=$true)]
    [string]$MobileCenterApiKey,
    [Parameter(Mandatory=$true)]
    [string]$DownloadFileName
)

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-API-Token", $MobileCenterApiKey)

$releases = Invoke-RestMethod -Uri "api.mobile.azure.com/v0.1/apps/$Owner/$AppName/releases/" -Method Get -Headers $headers

$releaseId = $releases[0].id

if ($releaseId -eq "")
{
    throw "Can't find release!!!"
}

$release = Invoke-RestMethod -Uri "api.mobile.azure.com/v0.1/apps/$Owner/$AppName/releases/$releaseId" -Method Get -Headers $headers

$downloadUrl = $release.download_url

if ($releaseId -eq "")
{
    throw "Can't get download url for release!!!"
}

(New-Object System.Net.WebClient).DownloadFile($release.download_url, $DownloadFileName)
