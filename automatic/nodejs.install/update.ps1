﻿[CmdletBinding()]
param($IncludeStream, [switch] $Force)

Import-Module Chocolatey-AU

if ($MyInvocation.InvocationName -ne '.') {
  # run the update only if the script is not sourced
  function global:au_BeforeUpdate { Get-RemoteFiles -NoSuffix -Purge }
}

function global:au_SearchReplace {
  $version = [version]$Latest.Version
  $silentArgs = if ($version -lt [version]'11.0') {
    ' REMOVE=NodeEtwSupport,NodePerfCtrSupport'
  }
  $silentArgs = "/quiet ADDLOCAL=ALL${silentArgs}"


  @{
    ".\tools\chocolateyInstall.ps1" = @{
      "(^[$]filePath32\s*=\s*`"[$]toolsPath\\)(.*)`"" = "`$1$($Latest.FileName32)`""
      "(^[$]filePath64\s*=\s*`"[$]toolsPath\\)(.*)`"" = "`$1$($Latest.FileName64)`""
      "(?i)(^\s*SilentArgs\s*=\s*)'.*'"               = "`${1}'$silentArgs'"
    }
    ".\legal\verification.txt"      = @{
      "(?i)(32-Bit.+)\<.*\>"      = "`${1}<$($Latest.URL32)>"
      "(?i)(64-Bit.+)\<.*\>"      = "`${1}<$($Latest.URL64)>"
      "(?i)(checksum type:\s+).*" = "`${1}$($Latest.ChecksumType32)"
      "(?i)(checksum32:\s+).*"    = "`${1}$($Latest.Checksum32)"
      "(?i)(checksum64:\s+).*"    = "`${1}$($Latest.Checksum64)"
    }
  }
}

function global:au_GetLatest {
  [string] $scheduleUri = 'https://raw.githubusercontent.com/nodejs/Release/main/schedule.json'
  [PSCustomObject] $schedules = Invoke-RestMethod -Uri $scheduleUri -UseBasicParsing

  [datetime] $curDate = (Get-Date).Date
  [string[]] $supportedChannels = @()
  $schedules.PSObject.Properties.Name | ForEach-Object {
    [string] $name = $_
    [PSCustomObject] $schedule = $schedules.$name
    [datetime] $scheduleStart = [datetime]::parseexact($schedule.start, 'yyyy-MM-dd', $null)
    [datetime] $scheduleEnd = [datetime]::parseexact($schedule.end, 'yyyy-MM-dd', $null)
    if (($scheduleStart -le $curDate) -and ($scheduleEnd -ge $curDate)) {
      $supportedChannels += $name
    }
  }

  [string] $versionsUri = 'https://nodejs.org/dist/index.json'
  [PSCustomObject] $versions = Invoke-RestMethod -Uri $versionsUri -UseBasicParsing

  $streams = @{ }

  $supportedChannels | ForEach-Object {
    [string] $channel = $_
    [PSCustomObject] $latestVersion = $versions | Where-Object -FilterScript { $_.version.StartsWith($channel) } | Select-Object -First 1
    Write-Host "$($latestVersion.version) / $($latestVersion.date)"
    [string] $version = $latestVersion.version
    [version] $versionStrict = [version]::Parse($latestVersion.version.Substring(1))

    [string] $url32 = "https://nodejs.org/dist/$version/node-$version-x86.msi"
    [string] $url64 = "https://nodejs.org/dist/$version/node-$version-x64.msi"

    $streams.Add($versionStrict.Major, @{ Version = $versionStrict.ToString() ; URL32 = $url32; URL64 = $url64 } )
  }

  return @{ Streams = $streams }
}

if ($MyInvocation.InvocationName -ne '.') {
  # run the update only if script is not sourced
  update -ChecksumFor none -IncludeStream $IncludeStream -Force:$Force
}
