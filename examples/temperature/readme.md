# rs-temperature Sample

## Overview

This example reads **temperature-related device options** on Intel RealSense cameras (for example D415).

On D400 USB devices, `Asic Temperature` and `Projector Temperature` are available on the depth sensor. Values can be queried **only while depth is streaming**.

## Build

Build librealsense with examples enabled (default). The target is `rs-temperature`.

## Run

```text
rs-temperature
```

## Expected Output

```text
Device: Intel RealSense D415
Supported temperature options on Stereo Module:
  Asic Temperature (range -40 .. 125 C)
  Projector Temperature (range -40 .. 125 C)
Supported temperature options on RGB Camera:
  (none)

Waiting for streaming to stabilize...
Current temperature readings:
  Asic Temperature: 38.0 C
  Projector Temperature: 41.0 C
```

D435i and other models with an IMU may also report `Motion Module Temperature`.

## Notes

- Depth stream must be active before calling `get_option()` on temperature options.
- `Projector Temperature` may be invalid if the emitter is disabled.
- RGB `auto white balance temperature` (Kelvin) is a color setting, not device heat; this sample does not read it.
