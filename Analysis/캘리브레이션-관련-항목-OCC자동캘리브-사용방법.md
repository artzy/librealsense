# 캘리브레이션 관련 — OCC자동캘리브 사용방법

| 항목 | 내용 |
|------|------|
| 경로 | `wrappers/python/examples/depth_auto_calibration_example.py` |
| 역할 | OCC자동캘리브 |
| 순서 | On-Chip → Focal Length → Tare (UCAL 권장 시퀀스) |

---

## 사전 조건

- Python + `pyrealsense2`
- **D400** 제품군
- **USB3** 연결
- Advanced Mode 활성화
- Focal/Tare용 타깃 (기본 크기 175×100 mm)

---

## 실행

```powershell
cd d:\study\librealsense\wrappers\python\examples
python depth_auto_calibration_example.py
```

### 주요 인자

| 인자 | 기본 | 설명 |
|------|------|------|
| `--exposure` | auto | 노출 또는 `auto` |
| `--target-width` / `--target-height` | 175 / 100 | 타깃 크기(mm) |
| `--onchip-speed` | medium | very_fast / fast / medium / slow / wall |
| `--onchip-scan` | intrinsic | intrinsic / extrinsic |
| `--focal-adjustment` | right_only | right_only / both_sides |
| `--tare-gt` | auto | `auto` 또는 거리(mm) |
| `--tare-accuracy` | medium | very_high / high / medium / low |
| `--tare-scan` | intrinsic | intrinsic / extrinsic |

예:

```powershell
python depth_auto_calibration_example.py --onchip-speed fast --tare-gt 1000
```

---

## 동작 요약

1. 장치·USB3·Advanced Mode 검사
2. emitter OFF, thermal compensation OFF
3. **OCC** (256×144@90) → table write
4. **Focal Length** (IR1/IR2 1280×720, 타깃) → write
5. **Tare** (GT 자동 계산 또는 수동 mm) → write
6. thermal compensation 복구

각 단계에서 `set_calibration_table` + `write_calibration`까지 수행한다.
