# 캘리브레이션 관련 — 캘리브UI 사용방법

| 항목 | 내용 |
|------|------|
| 경로 | `tools/realsense-viewer/` (`realsense-viewer.exe`) |
| 역할 | 캘리브UI |
| 관련 코드 | `common/on-chip-calib.*`, `d500-on-chip-calib.*`, `calibration-model.*` |

---

## 사전 조건

- `build\Release\realsense-viewer.exe`
- OpenVINO 연동 빌드인 경우 PATH에 `ngraph.dll` 등 필요:

```powershell
$env:PATH = "D:\Dev2019\deployment_tools\ngraph\lib;D:\Dev2019\deployment_tools\inference_engine\bin\intel64\Release;D:\Dev2019\deployment_tools\inference_engine\external\tbb\bin;D:\Dev2019\opencv-4.13.0\x64\vc16\bin;" + $env:PATH
cd d:\study\librealsense\build\Release
.\realsense-viewer.exe
```

---

## 캘리브 메뉴 위치

장치 연결 후 왼쪽 **장치 패널**에서 Self-Calibration / Calibration 관련 항목을 선택한다.

### D400 계열 (예: D415)

| 메뉴 | 설명 |
|------|------|
| On-Chip Calibration | 타깃 없이 depth 노이즈 개선. 유효 depth >50% 장면 권장 |
| Focal Length Calibration | 초점거리 (컬러 스트리밍 중엔 일부 비활성) |
| Tare Calibration | 알려진 거리로 스케일 보정 |
| UV-Map Calibration | Depth↔Color 정렬 (지원 장치) |
| Calibration Data | 테이블 수동 편집·JSON·factory reset·flash write |

### D500 계열

| 메뉴 | 설명 |
|------|------|
| On-Chip Calibration | D500 OCC |
| Dry Run On-Chip Calibration | 플래시 기록 없이 시험 |
| Calibration Data | 테이블 편집 |

---

## OCC 권장 흐름

1. Depth 스트림이 잘 나오는 장면을 조준 (흰 벽 모드는 프로젝터 ON + 평면 벽 전용)
2. **On-Chip Calibration** → Calibrate
3. Health-check 확인 (대략 **>0.25**이면 새 캘리브 적용 권장)
4. Apply / Write to flash로 저장

상세: [Self-Calibration Whitepaper](https://dev.realsenseai.com/docs/self-calibration-for-depth-cameras)
