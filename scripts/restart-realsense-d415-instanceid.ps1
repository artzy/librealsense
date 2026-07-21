# Find Intel RealSense D415 InstanceId(s) and restart PnP devices (Disable/Enable).
#
# Requires administrator (UAC) when performing restart (not for -ListOnly).
#
# Usage:
#   .\restart-realsense-d415-instanceid.ps1 -ListOnly
#   .\restart-realsense-d415-instanceid.ps1 -ListOnly -IncludePhantom
#   .\restart-realsense-d415-instanceid.ps1
#   .\restart-realsense-d415-instanceid.ps1 -WaitSeconds 3
#   .\restart-realsense-d415-instanceid.ps1 -InstanceId "USB\VID_8086&PID_0AD3\844513020421"

param(
    [switch]$ListOnly,
    [switch]$IncludePhantom,
    [string[]]$InstanceId,
    [int]$WaitSeconds = 2
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "realsense-d415-pnp-lib.ps1")

function Test-Administrator
{
    $current = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $current.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Administrator
{
    if (Test-Administrator) { return }

    $argList = @(
        "-NoProfile"
        "-ExecutionPolicy", "Bypass"
        "-File", ('"' + $PSCommandPath + '"')
    )

    if ($ListOnly) { $argList += "-ListOnly" }
    if ($IncludePhantom) { $argList += "-IncludePhantom" }
    if ($InstanceId) { foreach ($id in $InstanceId) { $argList += "-InstanceId"; $argList += ('"' + $id + '"') } }
    if ($WaitSeconds -ne 2) { $argList += "-WaitSeconds"; $argList += $WaitSeconds }

    Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList ($argList -join " ")
    exit
}

function Invoke-PnpDeviceDisableAll
{
    param(
        [Parameter(Mandatory = $true)]
        $Devices
    )

    foreach ($dev in $Devices)
    {
        Write-Host "Disable: $($dev.FriendlyName)"
        Write-Host "  InstanceId: $($dev.InstanceId)"
        Disable-PnpDevice -InstanceId $dev.InstanceId -Confirm:$false
    }
}

function Invoke-PnpDeviceEnableAll
{
    param(
        [Parameter(Mandatory = $true)]
        $Devices
    )

    foreach ($dev in $Devices)
    {
        Write-Host "Enable: $($dev.FriendlyName)"
        Write-Host "  InstanceId: $($dev.InstanceId)"
        Enable-PnpDevice -InstanceId $dev.InstanceId -Confirm:$false
    }
}

$usePresentOnly = -not ($ListOnly -and $IncludePhantom)
$devices = @(Get-D415Devices -PresentOnly:$usePresentOnly)

if (-not $IncludePhantom)
{
    $devices = @($devices | Where-Object { $_.Problem -ne "CM_PROB_PHANTOM" })
}

if ($devices.Count -eq 0)
{
    Write-Host "D415 device not found."
    Write-Host "  Try: .\restart-realsense-d415-instanceid.ps1 -ListOnly -IncludePhantom"
    exit 1
}

$groups = @(Get-D415DeviceGroups -Devices $devices)

if ($InstanceId -and $InstanceId.Count -gt 0)
{
    if ($ListOnly -and $IncludePhantom)
    {
        throw "-InstanceId cannot be used with -ListOnly -IncludePhantom."
    }

    $knownIds = @($devices | ForEach-Object { $_.InstanceId })
    foreach ($id in $InstanceId)
    {
        if ($knownIds -notcontains $id)
        {
            throw "InstanceId not found among selected D415 devices: $id"
        }
    }

    $selected = @($devices | Where-Object { $InstanceId -contains $_.InstanceId })
    $groups = @(
        [PSCustomObject]@{
            Serial       = "Custom"
            Devices      = $selected
            DisableOrder = @($selected | Sort-Object InstanceId -Descending)
            EnableOrder  = @($selected | Sort-Object InstanceId)
        }
    )
}

Write-D415DeviceList -Groups $groups

if ($ListOnly)
{
    Write-Host "--- Copy-paste (Composite, present) ---"
    $composites = Get-D415Devices -PresentOnly | Where-Object {
        $_.InstanceId -match "^USB\\VID_8086&PID_0AD3\\[^\\]+$" -and $_.Problem -ne "CM_PROB_PHANTOM"
    }
    foreach ($c in $composites)
    {
        Write-Host $c.InstanceId
    }

    Write-Host "`nListOnly specified. No PnP restart performed."
    exit 0
}

Ensure-Administrator

Write-Host "=== D415 PnP Disable / Enable ===`n"

foreach ($group in $groups)
{
    Write-Host "--- Serial: $($group.Serial) ---`n"

    Invoke-PnpDeviceDisableAll -Devices $group.DisableOrder

    Write-Host "Waiting ${WaitSeconds}s (between disable-all and enable-all)..."
    Start-Sleep -Seconds $WaitSeconds

    Invoke-PnpDeviceEnableAll -Devices $group.EnableOrder
    Write-Host ""
}

Write-Host "D415 PnP restart completed."
