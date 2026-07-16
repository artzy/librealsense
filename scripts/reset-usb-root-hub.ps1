# Reset USB Root Hub(s) on Windows (soft USB bus reset without reboot or replug).
#
# WARNING: All devices on the affected USB host controller will disconnect briefly
#          (keyboard, mouse, other USB devices).
#
# Usage:
#   .\reset-usb-root-hub.ps1 -ListOnly
#   .\reset-usb-root-hub.ps1
#   .\reset-usb-root-hub.ps1 -InstanceId "USB\ROOT_HUB30\4&C7355C0&1&0"
#   .\reset-usb-root-hub.ps1 -WaitSeconds 8 -ScanAfter
#   .\reset-usb-root-hub.ps1 -LogFile "$env:TEMP\usb-reset.log"

param(
    [switch]$ListOnly,
    [string[]]$InstanceId,
    [int]$WaitSeconds = 5,
    [switch]$ScanAfter,
    [string]$LogFile,
    [ValidateSet("Auto", "PnPUtil", "DisableEnable")]
    [string]$Method = "Auto"
)

$ErrorActionPreference = "Stop"

function Write-Log
{
    param([string]$Message)
    Write-Host $Message
    if ($LogFile)
    {
        Add-Content -Path $LogFile -Value $Message -Encoding UTF8
    }
}

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
    if ($InstanceId) { foreach ($id in $InstanceId) { $argList += "-InstanceId"; $argList += ('"' + $id + '"') } }
    if ($WaitSeconds -ne 5) { $argList += "-WaitSeconds"; $argList += $WaitSeconds }
    if ($ScanAfter) { $argList += "-ScanAfter" }
    if ($LogFile) { $argList += "-LogFile"; $argList += ('"' + $LogFile + '"') }
    if ($Method -ne "Auto") { $argList += "-Method"; $argList += $Method }

    Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList ($argList -join " ")
    exit
}

function Get-UsbRootHubs
{
    Get-PnpDevice -PresentOnly | Where-Object {
        $_.InstanceId -like "USB\ROOT_HUB30\*" -or
        $_.InstanceId -like "USB\ROOT_HUB20\*"
    } | Sort-Object InstanceId
}

function Get-HubLocationInfo
{
    param([string]$HubInstanceId)

    $prop = Get-PnpDeviceProperty -InstanceId $HubInstanceId -KeyName "DEVPKEY_Device_LocationInfo" -ErrorAction SilentlyContinue
    if ($prop -and $prop.Data) { return [string]$prop.Data }
    return ""
}

function Reset-UsbRootHubWithPnPUtil
{
    param([string]$HubInstanceId)

    $output = pnputil /restart-device $HubInstanceId 2>&1 | Out-String
    Write-Log $output.TrimEnd()

    if ($output -match "Restarting device:")
    {
        if ($output -match "System reboot is needed|pending system reboot")
        {
            Write-Log "WARNING: Windows reports a reboot may be needed to complete the operation."
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

function Reset-UsbRootHubWithDisableEnable
{
    param(
        [string]$HubInstanceId,
        [int]$DelaySeconds
    )

    Write-Log "Disabling Root Hub..."
    Disable-PnpDevice -InstanceId $HubInstanceId -Confirm:$false

    Write-Log "Waiting ${DelaySeconds}s..."
    Start-Sleep -Seconds $DelaySeconds

    Write-Log "Enabling Root Hub..."
    Enable-PnpDevice -InstanceId $HubInstanceId -Confirm:$false
}

function Reset-UsbRootHub
{
    param(
        [Parameter(Mandatory = $true)][string]$HubInstanceId,
        [int]$DelaySeconds,
        [string]$ResetMethod
    )

    $hub = Get-PnpDevice -InstanceId $HubInstanceId -ErrorAction SilentlyContinue
    if (-not $hub)
    {
        throw "Root Hub not found: $HubInstanceId"
    }

    $location = Get-HubLocationInfo -HubInstanceId $HubInstanceId
    $label = if ($location) { "$($hub.FriendlyName) [$location]" } else { $hub.FriendlyName }

    Write-Log "Resetting: $label"
    Write-Log "  InstanceId: $HubInstanceId"
    Write-Log "  Method    : $ResetMethod"

    switch ($ResetMethod)
    {
        "PnPUtil"
        {
            Reset-UsbRootHubWithPnPUtil -HubInstanceId $HubInstanceId
            if ($DelaySeconds -gt 0)
            {
                Write-Log "Waiting ${DelaySeconds}s..."
                Start-Sleep -Seconds $DelaySeconds
            }
        }
        "DisableEnable"
        {
            Reset-UsbRootHubWithDisableEnable -HubInstanceId $HubInstanceId -DelaySeconds $DelaySeconds
        }
        default { throw "Unknown reset method: $ResetMethod" }
    }

    Write-Log "Done: $label`n"
}

$rootHubs = @(Get-UsbRootHubs)
if ($rootHubs.Count -eq 0)
{
    Write-Host "No USB Root Hub devices found."
    exit 1
}

Write-Host "Found $($rootHubs.Count) USB Root Hub(s):`n"
$index = 0
foreach ($hub in $rootHubs)
{
    $index++
    $location = Get-HubLocationInfo -HubInstanceId $hub.InstanceId
    Write-Host "[$index] $($hub.FriendlyName)"
    Write-Host "    Status    : $($hub.Status)"
    if ($location) { Write-Host "    Location  : $location" }
    Write-Host "    InstanceId: $($hub.InstanceId)"
    Write-Host ""
}

if ($ListOnly)
{
    Write-Host "ListOnly specified. No reset performed."
    exit 0
}

$targets = @()
if ($InstanceId -and $InstanceId.Count -gt 0)
{
    foreach ($id in $InstanceId)
    {
        $match = $rootHubs | Where-Object { $_.InstanceId -eq $id }
        if (-not $match)
        {
            throw "Specified Root Hub not found or not present: $id"
        }
        $targets += $match
    }
}
else
{
    $targets = $rootHubs
}

Ensure-Administrator

Write-Log "=== USB Root Hub Reset ==="
Write-Log "This will briefly disconnect USB devices on the selected hub(s).`n"
Write-Log "Resetting $($targets.Count) Root Hub(s)...`n"

foreach ($hub in $targets)
{
    if ($Method -eq "Auto" -or $Method -eq "PnPUtil")
    {
        try
        {
            Write-Log "Resetting: $($hub.FriendlyName)"
            Write-Log "  InstanceId: $($hub.InstanceId)"
            Write-Log "  Method    : PnPUtil"
            Reset-UsbRootHubWithPnPUtil -HubInstanceId $hub.InstanceId
            if ($WaitSeconds -gt 0)
            {
                Write-Log "Waiting ${WaitSeconds}s..."
                Start-Sleep -Seconds $WaitSeconds
            }
            Write-Log "Done: $($hub.FriendlyName)`n"
        }
        catch
        {
            if ($Method -eq "DisableEnable")
            {
                throw
            }
            Write-Log "ERROR: $($_.Exception.Message)"
            Write-Log "Disable/Enable fallback is often unsupported for Root Hub on Windows."
            throw
        }
    }
    else
    {
        Reset-UsbRootHub -HubInstanceId $hub.InstanceId -DelaySeconds $WaitSeconds -ResetMethod "DisableEnable"
    }
}

if ($ScanAfter)
{
    Write-Log "Scanning for hardware changes..."
    $scanOutput = pnputil /scan-devices 2>&1 | Out-String
    Write-Log $scanOutput.TrimEnd()
}

Write-Log "Root Hub reset completed."
