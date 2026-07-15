# 캘리브레이션 관련 — IMU6방향캘리브 사용방법

| 항목 | 내용 |
|------|------|
| 경로 | `tools/rs-imu-calibration/rs-imu-calibration.py` |
| 역할 | IMU6방향캘리브 |
| 대상 | D435i 등 IMU 내장 RealSense |

---

## 사전 조건

- Python + `pyrealsense2` 설치
- IMU가 있는 카메라 연결
- 상세: [IMU Calibration Whitepaper](https://dev.realsenseai.com/docs/imu-calibration-tool-for-intel-realsense-depth-camera)

---

## 실행

```powershell
cd d:\study\librealsense\tools\rs-imu-calibration
python rs-imu-calibration.py
```

### 옵션

| 플래그 | 설명 |
|--------|------|
| `-h` | 도움말 |
| `-i <accel_file> [gyro_file]` | 이전에 저장한 raw 결과를 EEPROM에 기록 |
| `-s <serial>` | 지정 시리얼 장치만 캘리브 (기본: 첫 장치) |
| `-g` | 캘리브 전후 데이터 그래프 표시 |

---

## 절차

1. 스크립트가 카메라 **6방향** 자세를 안내한다.
2. 각 방향마다:
   - **Rotation**: 안내 방향과 오차가 `[0,0,0]`이 될 때까지 정렬
   - **Wait to Stablize**: 약 3초 안정 대기
   - **Collecting data**: 점(`.`)이 20개 찰 때까지 데이터 수집 (자세가 틀어지면 Rotation으로 복귀)
3. 6방향 완료 후 raw 저장 여부 입력 (`accel_<footer>.txt`, `gyro_<footer>.txt`)
4. Device(EEPROM) 저장 여부 → `Y` 입력 시 `"SUCCESS: saved calibration to camera."`
5. 중도 중단: **ESC** (CTRL-C는 비권장)

자세 고정에는 카메라 박스 등 홀더 사용을 권장한다 (`images/` 참고).
