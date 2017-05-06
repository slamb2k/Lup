## Problem statement ##

Lüp operates with a small, multi discipline engineering team with the manual deployment pipeline being managed by one developer. After a new version is made available as a result of this release pipeline, a number of other team memebers are required to manually access each device and install the latest version. 

The actual build is performed using on-premise macOS machines that need to be maintained. As the build is being performed locally there is no continuous integration and resulting feedback loop indicating the current quality of the build. In addition a local build machine does not have the same stability of an externally hosted build machine.

Once the build is complete, the release requires the manual handcrafting of a .plist xml file to point to the .ipa file to be installed. The .plist file contains the required metadata for that release.

The .ipa and .plist files are then hosted on DropBox and linked to on [http://apps.exponews.com.au/](http://apps.exponews.com.au/) for distribution.

The actual deployment then requires access to a large number of iPads so the new version can be manually installed by a technician. The long term plans are to utilise a mobile device management (MDM) platform to push the resulting release to enrolled devices but that step is not being addressed by this solution.

Discussions with Lüp Management and Customers helped the engineering team to derive the following requirements:

1. Continuous integration should be implemented as soon as possible.
2. Lüp would like to avoid having to maintain macOS based build machines.
3. The solution should provide the opportunity for automated testing on different target devices.
4. The framework should provide the ability to capture telemetry and report back performance metrics.
5. The solution should allow crash analytics to be collected by the system for reporting purposes.
6. The systems used in the current release method shouldn't change but instead the manual steps should be automated.
7. The solution should leverage Lüp's existing investment in DevOps tools such as Octopus Deploy.

After considering a number of solutions, Visual Studio Mobile Center has been chosen as is now being used to build the solution.

## Solution ##

The Lüp engineering team had identified the need to replace our existing build pipeline with an external build system such as Visual Studio Mobile Center. Mobile Center provides macOS based build assets which removes the need to maintain local build resources. Mobile Center also provides an API for device based testing, the collection of telemetry and the reporting of crash analytics.

The resulting build can be accessed via the Mobile Center API, the .plist file can be generated programatically and deployed to DropBox using its API. These steps can be orchestrated using Octupus Deploy.

### Technical Architecture

Build is provided by Visual Studio Mobile Center. Lüp uses BitBucket as a version control platform and Mobile Center provides native BitBucket integration. Continuous integration can be provided quite simply by using the native tools to automatically perform the build on every commit to Bitbucket.

As Mobile Center maintains its own hosted macOS based build machines there is no requirement to provision any agents or external machines that run macOS to build Lüp's iOS apps.

The testing features on Mobile Center provide a test cloud service that offers more than 2000 real devices in 400 unique device configurations. Tests can be written in several different languages including C# (UITest), Ruby (Calabash), or Java (Appium).

**NEED TO ASK JEREMY IF THEY WANT TO USE COCOAPODS OR JUST INCLUDE THE BINARIES FOR TELEMETRY AND CRASH ANALYTICS COLLECTION**

Three PowerShell cmdlets were written to automate the deployment pipeline:

1. Retrieve-VSMobileCenterBuild
2. Upload-DropBox (Called to upload the .ipa and get the sharing link)
2. Create-PList
4. Upload-DropBox (Called again to upload the .plist and get the sharing link)

These cmdlets were then called by Octupus Deploy to perform the release.

## Retrieve-VSMobileCenterBuild

Downloads the latest distribution of a Mobile Center build so it can uploaded to DropBox

~~~~<#
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
~~~~

## Upload-DropBox

The following PowerShell cmdlet uploads thre .ipa to DropBox, shares it publicly and then returns the sharing link for addition to the .plist file.

~~~~<#
.SYNOPSIS
This is a Powershell script to upload a file to DropBox using their REST API.
.DESCRIPTION
This Powershell script will upload file to DropBox using their REST API with the parameters you provide.
.PARAMETER SourceFilePath
The path of the file to upload.
.PARAMETER TargetFilePath
The path of the file on DropBox.
.PARAMETER DropBoxAccessToken
The DropBox access token.
#>

Param(
    [Parameter(Mandatory=$true)]
    [string]$SourceFilePath,
    [Parameter(Mandatory=$true)]
    [string]$TargetFilePath,
    [Parameter(Mandatory=$true)]
    [string]$DropBoxAccessToken
)

$authorization = "Bearer " + $DropBoxAccessToken

$arg = '{ "path": "' + $TargetFilePath + '", "mode": "add", "autorename": true, "mute": false }'

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", $authorization)
$headers.Add("Dropbox-API-Arg", $arg)
$headers.Add("Content-Type", 'application/octet-stream')

Invoke-RestMethod -Uri https://content.dropboxapi.com/2/files/upload -Method Post -InFile $SourceFilePath -Headers $headers

$body = '{ "path": "' + $TargetFilePath + '", "short_url": false }'

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", $authorization)
$headers.Add("Content-Type", 'application/json')

$shared = Invoke-RestMethod -Uri https://api.dropboxapi.com/2/sharing/create_shared_link -Method Post -Body $body -Headers $headers

return $shared.url
~~~~

## Create-PList

Creates the .plist file which contains the required metadata for an iOS release.

~~~~<#
.SYNOPSIS
This is a Powershell script to create a .plist file for IOS distribution.
.DESCRIPTION
This is a Powershell script to create a .plist file for IOS distribution.
.PARAMETER PListFile
The path of the .plist file to write.
.PARAMETER IpaLink
The shared link to the IPA file to distribute.
.PARAMETER Version
The version of the release being distributed.
#>

Param(
    [Parameter(Mandatory=$true)]
    [string]$PListFile,
    [Parameter(Mandatory=$true)]
    [string]$IpaLink,
    [Parameter(Mandatory=$true)]
    [string]$Version
)

$pListXml = @”
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>items</key>
    <array>
        <dict>
            <key>assets</key>
            <array>
                <dict>
                    <key>kind</key>
                    <string>software-package</string>
                    <key>url</key>
                    <string>$IpaLink</string>
                </dict>
            </array>
            <key>metadata</key>
            <dict>
                <key>bundle-identifier</key>
                <string>com.exponews.LupApp</string>
                <key>bundle-version</key>
                <string>$Version</string>
                <key>kind</key>
                <string>software</string>
                <key>title</key>
                <string>LupApp</string>
            </dict>
        </dict>
    </array>
</dict>
</plist>
"@

$pListXml | Out-File $PListFile -Force
~~~~

### Reduction in Costs and Errors

The automated deployment has considerable less costs for deployment as it doesn't require a team member to manually perform the steps. Along with this the process is repeatable and reduces potential errors that come from manually crafting the .plist file and uploading the required payloads.

## Conclusion and next steps ##

The process reduces cost and errors associated with deployment but does not address the requirement to manually perform the installation on a large number of devices.

The next step would be to utilise a Mobile Device Management platform like Intune to automatically deploy the build to enrolled devices.
