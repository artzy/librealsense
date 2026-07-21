# Shared helpers for Intel RealSense D415 PnP device queries on Windows.

$d415PidPattern = "VID_8086&PID_0AD3"

function Get-D415Devices
{
    param(
        [switch]$PresentOnly
    )

    $devices = if ($PresentOnly) { Get-PnpDevice -PresentOnly } else { Get-PnpDevice }

    return @($devices | Where-Object {
        $_.InstanceId -match $d415PidPattern -or
        ($_.FriendlyName -match "Depth Camera 415" -and $_.InstanceId -match "VID_8086")
    })
}

function Get-D415GroupKey
{
    param([string]$InstanceId)

    if ($InstanceId -match "^USB\\VID_8086&PID_0AD3\\([^\\]+)$")
    {
        return $matches[1]
    }

    $parentProp = Get-PnpDeviceProperty -InstanceId $InstanceId -KeyName "DEVPKEY_Device_Parent" -ErrorAction SilentlyContinue
    if ($parentProp -and [string]$parentProp.Data -match "^USB\\VID_8086&PID_0AD3\\([^\\]+)$")
    {
        return $matches[1]
    }

    return $InstanceId
}

function Get-DevicePortInfo
{
    param([string]$InstanceId)

    $loc = Get-PnpDeviceProperty -InstanceId $InstanceId -KeyName "DEVPKEY_Device_LocationInfo" -ErrorAction SilentlyContinue
    $parent = Get-PnpDeviceProperty -InstanceId $InstanceId -KeyName "DEVPKEY_Device_Parent" -ErrorAction SilentlyContinue

    [PSCustomObject]@{
        Location = if ($loc) { [string]$loc.Data } else { "" }
        Parent   = if ($parent) { [string]$parent.Data } else { "" }
    }
}

function Get-D415DeviceGroups
{
    param(
        [Parameter(Mandatory = $true)]
        $Devices
    )

    $bySerial = @{}
    foreach ($dev in $Devices)
    {
        $key = Get-D415GroupKey -InstanceId $dev.InstanceId
        if (-not $bySerial.ContainsKey($key))
        {
            $bySerial[$key] = @()
        }
        $bySerial[$key] += $dev
    }

    $groups = @()
    foreach ($entry in ($bySerial.GetEnumerator() | Sort-Object Name))
    {
        $groupDevices = @($entry.Value)
        $composite = @($groupDevices | Where-Object { $_.InstanceId -match "^USB\\VID_8086&PID_0AD3\\[^\\]+$" })
        $children = @($groupDevices | Where-Object { $_.InstanceId -match "&MI_" } | Sort-Object InstanceId)

        $disableOrder = @($children) + @($composite)
        if ($disableOrder.Count -eq 0)
        {
            $disableOrder = @($groupDevices | Sort-Object InstanceId -Descending)
        }

        $enableOrder = @($composite) + @($children)
        if ($enableOrder.Count -eq 0)
        {
            $enableOrder = @($groupDevices | Sort-Object InstanceId)
        }

        $groups += [PSCustomObject]@{
            Serial       = $entry.Key
            Devices      = $groupDevices
            DisableOrder = $disableOrder
            EnableOrder  = $enableOrder
        }
    }

    return $groups
}

function Sort-D415DevicesForDisplay
{
    param(
        [Parameter(Mandatory = $true)]
        $Devices
    )

    $composite = @($Devices | Where-Object { $_.InstanceId -match "^USB\\VID_8086&PID_0AD3\\[^\\]+$" })
    $children = @($Devices | Where-Object { $_.InstanceId -match "&MI_" } | Sort-Object InstanceId)
    $rest = @($Devices | Where-Object {
        ($composite -notcontains $_) -and ($children -notcontains $_)
    } | Sort-Object InstanceId)

    return @($composite) + @($children) + @($rest)
}

function Write-D415DeviceList
{
    param(
        [Parameter(Mandatory = $true)]
        $Groups
    )

    Write-Host "=== Intel RealSense D415 InstanceId ===`n"

    $groupIndex = 0
    foreach ($group in $Groups)
    {
        $groupIndex++
        Write-Host "[$groupIndex] USB Serial: $($group.Serial)"

        $composite = $group.Devices | Where-Object { $_.InstanceId -match "^USB\\VID_8086&PID_0AD3\\[^\\]+$" } | Select-Object -First 1
        if ($composite)
        {
            Write-Host "    Composite InstanceId:"
            Write-Host "      $($composite.InstanceId)"
        }

        foreach ($dev in (Sort-D415DevicesForDisplay -Devices $group.Devices))
        {
            $extra = Get-DevicePortInfo -InstanceId $dev.InstanceId
            Write-Host "    $($dev.Status) | $($dev.Class) | $($dev.FriendlyName)"
            Write-Host "      InstanceId: $($dev.InstanceId)"
            if ($extra.Location) { Write-Host "      Port      : $($extra.Location)" }
            if ($extra.Parent) { Write-Host "      Parent    : $($extra.Parent)" }
        }

        Write-Host "    Disable order:"
        foreach ($dev in $group.DisableOrder)
        {
            Write-Host "      -> $($dev.InstanceId)"
        }
        Write-Host "    Enable order:"
        foreach ($dev in $group.EnableOrder)
        {
            Write-Host "      -> $($dev.InstanceId)"
        }
        Write-Host ""
    }
}
