# USB/드라이버 문제 복구 기능 조사

librealsense 프로젝트에서 **USB가 완전히 끊기는 문제**나 **드라이버 문제**를 해결할 수 있는 기능을 코드베이스 전반에서 조사한 결과입니다.

---

## 결론

이 프로젝트에는 **"USB가 OS에서 완전히 사라진 상태"를 자동으로 복구하는 전용 도구는 없습니다.**

다만 **장치가 USB에 여전히 잡히는 경우**(Recovery 모드, 일시적 끊김, 스트리밍 오류, 드라이버/권한 문제)에 대응하는 기능은 여러 계층에 존재합니다.

---

## 1. 펌웨어 Recovery 복구 — `rs-fw-update.exe`

**가장 명확한 "복구" 기능**입니다. 펌웨어 업데이트 실패 등으로 **Recovery 모드**(`Intel RealSense D4XX Recovery`)에 빠진 장치를 복구합니다.

```powershell
rs-fw-update -r -f Signed_Image_UVC_xxx.bin
```

- Recovery 장치를 찾아 DFU 수행
- 완료 후 정상 모드 재등장까지 대기 (최대 15초)
- **전제:** USB에 Recovery PID(예: `0ADB`)로 **여전히 인식**되어야 함
- MIPI Recovery(D457 등)는 재부팅/드라이버 reload 안내

관련 소스:

- `tools/fw-update/rs-fw-update.cpp`
- `common/fw-update-helper.cpp`

---

## 2. 하드웨어 리셋 — `device.hardware_reset()`

카메라 펌웨어에 **HWRST** 명령을 보내 USB 재열거(soft reset)를 유도합니다.

```cpp
// src/ds/d400/d400-device.cpp
void d400_device::hardware_reset()
{
    command cmd(ds::HWRST);
    cmd.require_response = false;
    _hw_monitor->send(cmd);
}
```

### 사용자가 쓸 수 있는 경로

| 경로 | 용도 |
|------|------|
| **realsense-viewer** | 장치 메뉴 → **Hardware Reset** |
| **rs-dds-config --reset** | Ethernet 설정 장치 리셋 |
| **Python/C++ API** | `dev.hardware_reset()` |
| **DDS adapter** | 원격 `hw_reset` 제어 |

Viewer 테스트는 disconnect → reconnect를 검증합니다.

```cpp
// tools/realsense-viewer/tests/hw-reset/test-hw-reset.cpp
// Reset the device via the UI menu and verify it disconnects and reconnects
VIEWER_TEST( "device", "hardware_reset" )
```

**한계:** 장치가 이미 응답하지 않거나 OS에서 완전히 사라진 경우에는 동작하지 않습니다.

---

## 3. 재연결 감지·대기 — SDK API (복구가 아닌 대응)

USB가 **물리적으로 다시 연결**되면 앱이 이를 감지하고 재시작할 수 있는 메커니즘입니다.

| API | 역할 |
|-----|------|
| `context::set_devices_changed_callback()` | connect/disconnect 이벤트 |
| `device_hub::wait_for_device()` | 장치 연결까지 블록 |
| `device_hub::is_connected()` | 연결 여부 확인 |
| `device::is_connected()` | 현재 device 핸들 유효성 |
| **Pipeline** | `wait_for_frames()` 중 disconnect 감지 시 `unsafe_stop()` → `unsafe_start()` 재시도 |

```cpp
// src/pipeline/pipeline.cpp
if (!_hub->is_connected(*_active_profile->get_device()))
{
    try
    {
        auto prev_conf = _prev_conf;
        unsafe_stop();
        unsafe_start(prev_conf);
        // ...
    }
    catch (const std::exception& e)
    {
        throw std::runtime_error("Device disconnected. Failed to reconnect: ...");
    }
}
```

**한계:** OS/드라이버가 장치를 다시 enumerate 해줘야 합니다. "끊긴 USB를 되살리는" 기능은 아닙니다.

---

## 4. 스트리밍 중 USB 엔드포인트 리셋 — SDK 내부

프레임이 멈출 때 UVC watchdog이 **USB pipe reset**을 시도합니다.

```cpp
// src/uvc/uvc-streamer.cpp
LOG_ERROR("uvc streamer watchdog triggered on endpoint: ...");
_context.messenger->reset_endpoint(_read_endpoint, ENDPOINT_RESET_MILLISECONDS_TIMEOUT);
```

- Windows: `WinUsb_ResetPipe`
- Linux: libusb clear halt 등

**한계:** 스트리밍 hang 완화용. **완전 disconnect·드라이버 crash**에는 해당 없음.

---

## 5. 드라이버/환경 문제 — 스크립트·빌드 옵션 (Linux 중심)

런타임 도구가 아니라 **OS/드라이버 측 예방·수리**입니다.

| 항목 | 설명 |
|------|------|
| `scripts/patch-realsense-ubuntu-lts.sh` 등 | Linux `uvcvideo` 커널 패치 (메타데이터, 안정성) |
| `scripts/setup_udev_rules.sh` | USB 접근 권한 (권한 문제로 "안 보이는" 경우) |
| `scripts/libuvc_installation.sh` | `-DFORCE_RSUSB_BACKEND=ON` — 커널 UVC 대신 **userspace USB** |
| `doc/troubleshooting.md` | `dmesg`, `lsusb`, UVC trace, `udevadm monitor` 등 **진단** |
| `doc/installation_jetson.md` | RSUSB vs 네이티브 드라이ver 선택 |

Windows: `doc/installation_windows.md`의 레지스트리(MetadataBufferSizeInKB) 등.

---

## 6. 진단·원격 트러블슈팅 도구 (복구 X)

| 도구 | 역할 |
|------|------|
| `rs-enumerate-devices` | 연결/상태 확인 |
| `rs-terminal` | 펌웨어 디버그 명령 (Intel Support용), `device_hub`로 연결 대기 |
| `rs-fw-logger` | 연결될 때까지 polling, disconnect 시 루프 |
| `rs-fw-update -l` | Recovery 모드 포함 장치 목록 |

`tools/readme.md`에서 Terminal을 **"Troubleshooting tool"**으로 분류합니다.

---

## 상황별 정리

| 상황 | 프로젝트 내 대응 | 비고 |
|------|------------------|------|
| Recovery 모드 (USB에 `D4XX Recovery`로 보임) | ✅ `rs-fw-update -r` | 가장 직접적인 복구 |
| 장치 hang, 응답은 있음 | ✅ Viewer **Hardware Reset** / API | USB 재열거 유도 |
| 스트리밍 중 프레임 멈춤 | △ SDK 내부 `reset_endpoint` | 자동, 사용자 도구 아님 |
| 앱 실행 중 USB 재연결 | △ `device_hub`, Pipeline 재시작 | **재연결 대기** |
| Linux uvcvideo/권한 문제 | △ patch 스크립트, udev, RSUSB | 빌드/설치 단계 |
| USB 완전 disconnect (Device Manager에도 없음) | ❌ | 케이블/포트/허브/드라이버 재설치 등 **OS/하드웨어** |
| 드라이버 크래시 후 enumerate 안 됨 | ❌ (런타임) | 재부팅, 드라이버 재설치, `dmesg` 분석 |

---

## rs-enumerate-devices / rs-fw-update와의 관계

| 도구 | USB/드라이버 복구 |
|------|-------------------|
| `rs-enumerate-devices` | ❌ 조회·진단만 |
| `rs-fw-update -r` | ✅ Recovery 모드 펌웨어 복구 |
| `rs-fw-update` (일반) | △ 업데이트 후 재연결 대기 |

---

## 권장 대응 흐름

USB가 완전히 끊긴 경우:

1. `rs-enumerate-devices -l` 또는 `rs-fw-update -l`로 **인식 여부** 확인
2. **Recovery**로 보이면 → `rs-fw-update -r -f <firmware.bin>`
3. **정상 장치**로 보이면 → Viewer **Hardware Reset** 또는 API `hardware_reset()`
4. **아예 안 보이면** → 물리 재연결, 다른 USB 3 포트, Device Manager 확인, 드라이버 재설치
5. Linux → `dmesg`, `lsusb`, udev 규칙, 커널 패치/RSUSB 백엔드 검토

---

## 관련 문서

- `Analysis/rs-enumerate-devices-작동원리.md`
- `Analysis/rs-fw-update-기능설명.md`
- `doc/error_handling.md` — `camera_disconnected_error`, disconnect 처리
- `doc/troubleshooting.md` — 로그·커널·UVC 진단
