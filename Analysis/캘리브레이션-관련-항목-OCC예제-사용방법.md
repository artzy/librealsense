# 캘리브레이션 관련 — OCC예제 사용방법

| 항목 | 내용 |
|------|------|
| 경로 | `examples/on-chip-calib/rs-on-chip-calib.cpp` |
| 실행 파일 | `rs-on-chip-calib.exe` |
| 역할 | OCC예제 |

---

## 사전 조건

- 예제 빌드 완료 (`BUILD_EXAMPLES`)
- D400 등 `auto_calibrated_device` 지원 장치
- 유효 depth 픽셀이 충분한 장면 (보통 >50%)

---

## 실행

```powershell
cd d:\study\librealsense\build\Release
.\rs-on-chip-calib.exe
```

공통 CLI 옵션(`--dds-domain` 등)은 `rs2::cli`로 처리된다.

---

## 동작 요약

1. Depth 스트림 `256x144 Z16 @ 90fps` 시작
2. JSON으로 OCC 파라미터 전달 후 `run_on_chip_calibration` 실행
3. 진행률(%) 출력 → `"Completed successfully"`
4. `Keep results? Yes/No` 입력
   - Yes → `set_calibration_table` + `write_calibration` → flash 저장
   - No → 전원/리셋 시 이전 테이블로 복귀

### 기본 JSON 예시

```json
{
  "calib type": 0,
  "speed": 2,
  "scan parameter": 0
}
```

| 파라미터 | 값 |
|----------|-----|
| speed | 0 very fast … 3 slow (기본) |
| scan parameter | 0 intrinsic, 1 extrinsic |

저장하지 않은 결과는 런타임에만 적용된다.
