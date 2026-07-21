# D415 USB Windows 복구 스크립트 정리

Windows에서 Intel RealSense **D415** USB 연결 문제를 진단·복구하기 위해 추가한 PowerShell/BAT 스크립트 모음입니다.  
(librealsense SDK의 `hardware_reset()`은 **장치가 SDK에 보일 때** 사용 — [USB-드라이버-문제-복구-기능-조사.md](./USB-드라이버-문제-복구-기능-조사.md) 참고)

---

## 스크립트 목록

| 스크립트 | 역할 |
|----------|------|
| [`scripts/reset-usb-root-hub.ps1`](../scripts/reset-usb-root-hub.ps1) | USB Root Hub `pnputil /restart-device` (관리자) |
| [`scripts/restart-realsense-d415-instanceid.ps1`](../scripts/restart-realsense-d415-instanceid.ps1) | D415 **InstanceId** 조회 + PnP Disable/Enable |
| [`scripts/recover-realsense-d415.ps1`](../scripts/recover-realsense-d415.ps1) | **상태 검사 후 자동 복구** (아래 흐름) |
| [`scripts/realsense-d415-pnp-lib.ps1`](../scripts/realsense-d415-pnp-lib.ps1) | D415 PnP 탐색·그룹화 공통 함수 |

각 `.bat` 파일은 동일 이름의 `.ps1` 실행 래퍼입니다.

---

## recover-realsense-d415 동작

```
상태 확인 (PnP + rs-enumerate-devices)
    │
    ├─ 정상 (PnP OK, USB 3.0+) → 종료
    │
    ├─ D415 PnP 있음 + (오류 / USB<3.0 / SDK 미인식)
    │       → InstanceId Disable → Enable (자식 MI → Composite)
    │
    └─ D415 없음 (PnP·SDK)
            → USB Root Hub 전체 reset
```

### 판단 기준

- **PnP 오류**: `Status != OK`, `Problem != CM_PROB_NONE`
- **USB 3.0 미만**: `rs-enumerate-devices`의 `Usb Type Descriptor` < 3.0
- **SDK 미인식**: PnP에 `8086:0AD3`는 있는데 SDK `No device detected`

### 사용 예

```powershell
cd scripts
.\recover-realsense-d415.ps1 -CheckOnly    # 진단만
.\recover-realsense-d415.ps1                 # 필요 시 복구 (UAC)
.\restart-realsense-d415-instanceid.ps1 -ListOnly
.\reset-usb-root-hub.ps1 -ListOnly
```

---

## D415 InstanceId 구조 (예)

한 대 연결 시 보통 3개 노드:

- Composite: `USB\VID_8086&PID_0AD3\<serial>`
- Depth: `...\&MI_00\...`
- RGB: `...\&MI_03\...`

PnP 재시작 순서: **Disable** MI_00 → MI_03 → Composite → **Enable** Composite → MI_00 → MI_03

---

## 주의

- Root Hub / PnP 복구는 **관리자(UAC)** 필요.
- Root Hub 리셋 시 같은 USB 컨트롤러의 키보드·마우스도 잠깐 끊김.
- `pnputil /restart-device` 연속 실행 시 Windows **재부팅 대기** 상태가 될 수 있음.
- OS 단계 `SET_ADDRESS` 실패 등 **완전 미열거**는 스크립트만으로 항상 해결되지 않을 수 있음 (케이블·포트·전원 확인).

---

## 관련 분석

- [USB-드라이버-문제-복구-기능-조사.md](./USB-드라이버-문제-복구-기능-조사.md) — SDK `hardware_reset`, Recovery, Pipeline 재연결 등
