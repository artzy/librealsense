# Check Intel RealSense D415 health and recover:
#   - PnP error or USB below 3.0 -> disable/enable D415 InstanceIds (admin)
#   - No D415 present -> reset USB Root Hub(s) (admin)
#
# Usage:
#   .\recover-realsense-d415.ps1 -CheckOnly
#   .\recover-realsense-d415.ps1
#   .\recover-realsense-d415.ps1 -PnpWaitSeconds 3 -HubWaitSeconds 5

param(
    [switch]$CheckOnly,
    [int]$PnpWaitSeconds = 2,
    [int]$HubWaitSeconds = 5,
    [switch]$ScanAfterHubReset
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
    if ($CheckOnly) { $argList += "-CheckOnly" }
    if ($PnpWaitSeconds -ne 2) { $argList += "-PnpWaitSeconds"; $argList += $PnpWaitSeconds }
    if ($HubWaitSeconds -ne 5) { $argList += "-HubWaitSeconds"; $argList += $HubWaitSeconds }
    if ($ScanAfterHubReset) { $argList += "-ScanAfterHubReset" }

    Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList ($argList -join " ")
    exit
}

function Find-RsEnumerateDevicesExe
{
    $roots = @(
        (Join-Path $PSScriptRoot "..")
    )
    foreach ($root in $roots)
    {
        if (-not (Test-Path $root)) { continue }
        $found = Get-ChildItem -Path $root -Recurse -Filter "rs-enumerate-devices.exe" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match "\\Release\\|\\Debug\\" } |
            Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

function Get-D415SdkProbe
{
    $exe = Find-RsEnumerateDevicesExe
    if (-not $exe)
    {
        return [PSCustomObject]@{
            ToolAvailable = $false
            Detected      = $false
            UsbType       = $null
            IsUsb3Plus    = $null
            Summary       = "rs-enumerate-devices.exe not found (USB speed check skipped)"
        }
    }

    $output = & $exe 2>&1 | Out-String
    if ($output -match "No device detected")
    {
        return [PSCustomObject]@{
            ToolAvailable = $true
            Detected      = $false
            UsbType       = $null
            IsUsb3Plus    = $false
            Summary       = "SDK: no RealSense device detected"
        }
    }

    $isD415 = ($output -match "D415") -or ($output -match "0AD3")
    $usbType = $null
    if ($output -match "Usb Type Descriptor\s*:\s*([\d.]+)")
    {
        $usbType = [double]$matches[1]
    }

    $isUsb3Plus = $false
    if ($null -ne $usbType)
    {
        $isUsb3Plus = ($usbType -ge 3.0)
    }
    elseif ($output -match "USB2|USB 2")
    {
        $isUsb3Plus = $false
    }

    $summary = if ($isD415) { "SDK: D415 detected" } else { "SDK: RealSense detected (not confirmed D415)" }
    if ($null -ne $usbType)
    {
        $summary += ", Usb Type Descriptor $usbType"
    }

    return [PSCustomObject]@{
        ToolAvailable = $true
        Detected      = $isD415
        UsbType       = $usbType
        IsUsb3Plus    = $isUsb3Plus
        Summary       = $summary
    }
}

function Get-D415PnpPresentDevices
{
    $devices = @(Get-D415Devices -PresentOnly)
    return @($devices | Where-Object { $_.Problem -ne "CM_PROB_PHANTOM" })
}

function Test-D415PnpHealthy
{
    param(
        [Parameter(Mandatory = $true)]
        $Devices
    )

    $issues = @()
    foreach ($dev in $Devices)
    {
        if ($dev.Status -ne "OK")
        {
            $issues += "PnP Status=$($dev.Status) $($dev.FriendlyName) [$($dev.InstanceId)]"
        }
        if ($dev.Problem -and $dev.Problem -ne "CM_PROB_NONE")
        {
            $issues += "PnP Problem=$($dev.Problem) $($dev.FriendlyName)"
        }
    }
    return $issues
}

function Invoke-D415PnpRestart
{
    param(
        [Parameter(Mandatory = $true)]
        $Groups,
        [int]$WaitSeconds
    )

    Write-Host "`n=== D415 PnP Disable / Enable ===`n"
    foreach ($group in $Groups)
    {
        Write-Host "--- Serial: $($group.Serial) ---`n"
        foreach ($dev in $group.DisableOrder)
        {
            Write-Host "Disable: $($dev.FriendlyName)"
            Write-Host "  InstanceId: $($dev.InstanceId)"
            Disable-PnpDevice -InstanceId $dev.InstanceId -Confirm:$false
        }
        Write-Host "Waiting ${WaitSeconds}s..."
        Start-Sleep -Seconds $WaitSeconds
        foreach ($dev in $group.EnableOrder)
        {
            Write-Host "Enable: $($dev.FriendlyName)"
            Write-Host "  InstanceId: $($dev.InstanceId)"
            Enable-PnpDevice -InstanceId $dev.InstanceId -Confirm:$false
        }
        Write-Host ""
    }
}

function Invoke-RootHubResetAll
{
    param(
        [int]$WaitSeconds,
        [switch]$ScanAfter
    )

    function Reset-RootHubPnPUtil
    {
        param([string]$HubInstanceId)

        $output = pnputil /restart-device $HubInstanceId 2>&1 | Out-String
        Write-Host $output.TrimEnd()

        if ($output -match "Restarting device:")
        {
            if ($output -match "System reboot is needed|pending system reboot")
            {
                Write-Host "WARNING: Windows reports a reboot may be needed to complete the operation."
            }
            return
        }

        if ($output -match "Failed to restart device")
        {
            if ($output -match "pending system reboot")
            {
                throw "Root Hub restart is pending a system reboot. Reboot Windows and retry."
            }
            throw "pnputil /restart-device failed for: $HubInstanceId"
        }

        if ($LASTEXITCODE -ne 0)
        {
            throw "pnputil /restart-device failed for: $HubInstanceId"
        }
    }

    $hubs = @(Get-PnpDevice -PresentOnly | Where-Object {
        $_.InstanceId -like "USB\ROOT_HUB30\*" -or $_.InstanceId -like "USB\ROOT_HUB20\*"
    } | Sort-Object InstanceId)

    if ($hubs.Count -eq 0)
    {
        throw "No USB Root Hub devices found."
    }

    Write-Host "`n=== USB Root Hub reset (no D415 present) ===`n"
    Write-Host "Resetting $($hubs.Count) Root Hub(s)...`n"

    foreach ($hub in $hubs)
    {
        Write-Host "Root Hub: $($hub.FriendlyName)"
        Write-Host "  InstanceId: $($hub.InstanceId)"
        Reset-RootHubPnPUtil -HubInstanceId $hub.InstanceId
        if ($WaitSeconds -gt 0)
        {
            Write-Host "Waiting ${WaitSeconds}s..."
            Start-Sleep -Seconds $WaitSeconds
        }
    }

    if ($ScanAfter)
    {
        Write-Host "Scanning for hardware changes..."
        pnputil /scan-devices | Out-Host
    }
}

Write-Host "=== D415 recover: check ===`n"

$pnpDevices = @(Get-D415PnpPresentDevices)
$sdk = Get-D415SdkProbe

Write-Host "PnP: $($pnpDevices.Count) present D415 node(s)"
foreach ($dev in (Sort-D415DevicesForDisplay -Devices $pnpDevices))
{
    Write-Host "  $($dev.Status) | $($dev.FriendlyName)"
    Write-Host "    $($dev.InstanceId)"
}
Write-Host ""
Write-Host $sdk.Summary

$pnpIssues = @(Test-D415PnpHealthy -Devices $pnpDevices)
$hasPnpD415 = ($pnpDevices.Count -gt 0)

$needsPnpFix = $false
$reasons = @()

if ($pnpIssues.Count -gt 0)
{
    $needsPnpFix = $true
    $reasons += "PnP device error"
}

if ($sdk.ToolAvailable -and $sdk.Detected -and ($sdk.IsUsb3Plus -eq $false))
{
    $needsPnpFix = $true
    $reasons += "USB connection is not 3.0+ (Usb Type Descriptor=$($sdk.UsbType))"
}
elseif ($sdk.ToolAvailable -and -not $sdk.Detected -and $hasPnpD415)
{
    $needsPnpFix = $true
    $reasons += "SDK cannot see D415 while PnP nodes exist"
}

if ($pnpIssues.Count -gt 0)
{
    Write-Host "`nPnP issues:"
    foreach ($i in $pnpIssues) { Write-Host "  - $i" }
}

if ($reasons.Count -gt 0)
{
    Write-Host "`nRecovery needed: $($reasons -join '; ')"
}
else
{
    if ($hasPnpD415 -or ($sdk.ToolAvailable -and $sdk.Detected))
    {
        Write-Host "`nD415 looks healthy (PnP OK, USB 3.0+ if SDK available). No recovery performed."
        exit 0
    }
}

if ($CheckOnly)
{
    if (-not $hasPnpD415 -and (-not $sdk.ToolAvailable -or -not $sdk.Detected))
    {
        Write-Host "`nCheckOnly: would reset USB Root Hub (no D415)."
    }
    elseif ($needsPnpFix)
    {
        Write-Host "`nCheckOnly: would restart D415 PnP devices."
    }
    exit 0
}

Ensure-Administrator

if (-not $hasPnpD415 -and (-not $sdk.ToolAvailable -or -not $sdk.Detected))
{
    Invoke-RootHubResetAll -WaitSeconds $HubWaitSeconds -ScanAfter:$ScanAfterHubReset
    Write-Host "`nPost-check..."
    Start-Sleep -Seconds 2
    $afterPnp = @(Get-D415PnpPresentDevices)
    $afterSdk = Get-D415SdkProbe
    Write-Host "PnP D415 nodes: $($afterPnp.Count)"
    Write-Host $afterSdk.Summary
    exit 0
}

if ($needsPnpFix -and $hasPnpD415)
{
    $groups = @(Get-D415DeviceGroups -Devices $pnpDevices)
    Write-D415DeviceList -Groups $groups
    Invoke-D415PnpRestart -Groups $groups -WaitSeconds $PnpWaitSeconds
    Write-Host "D415 PnP restart completed."
    Write-Host "`nPost-check..."
    Start-Sleep -Seconds 2
    $afterSdk = Get-D415SdkProbe
    Write-Host $afterSdk.Summary
    exit 0
}

if (-not $hasPnpD415)
{
    Invoke-RootHubResetAll -WaitSeconds $HubWaitSeconds -ScanAfter:$ScanAfterHubReset
    exit 0
}

Write-Host "No recovery action matched."
exit 0
