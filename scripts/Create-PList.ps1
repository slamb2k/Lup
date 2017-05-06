
<#
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