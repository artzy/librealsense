# 캘리브레이션 관련 — OCCTare예제 사용방법

| 항목 | 내용 |
|------|------|
| 경로 | `wrappers/python/examples/depth_ucal_example.py` |
| 역할 | OCC/Tare예제 (파일명: OCCTare예제) |
| 형태 | 대화형 메뉴로 OCC·Tare·테이블 R/W |

---

## 사전 조건

- Python + `pyrealsense2`
- auto calibration 지원 장치
- (선택) OCC/Tare용 JSON 파라미터 파일

---

## 실행

```powershell
cd d:\study\librealsense\wrappers\python\examples
python depth_ucal_example.py
```

도움말:

```powershell
python depth_ucal_example.py -h
```

JSON 지정:

```powershell
python depth_ucal_example.py --occ occ.json --tare tare.json
```

시작 시 `hardware_reset` 후 약 3초 대기한다.

---

## 메뉴

| 키 | 동작 |
|----|------|
| `c` | On-Chip Calibration |
| `C` | OCC + host assist (HD depth 1280×720) |
| `t` | Tare Calibration (GT mm 입력) |
| `T` | Tare + host assist |
| `g` | 현재 활성 캘리브 테이블 조회 |
| `w` | 새 캘리브를 set + write (flash) |
| `a` | Advanced Mode on/off 토글 |
| `e` | 종료 |

Host assist 모드(`C`/`T`)는 프레임을 받아 `process_calibration_frame`을 반복한다.

---

## 참고

- OCC/Tare 시 emitter를 켜고 thermal compensation을 끈 뒤, 끝나면 복구한다.
- JSON이 없으면 스크립트 내 기본 JSON을 사용한다.
- 통합 시퀀스 참고용 예제이며, 자동 풀시퀀스는 `depth_auto_calibration_example.py`를 본다.
