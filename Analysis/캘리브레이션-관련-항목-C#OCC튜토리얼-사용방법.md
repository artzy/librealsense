# 캘리브레이션 관련 — C#OCC튜토리얼 사용방법

| 항목 | 내용 |
|------|------|
| 경로 | `wrappers/csharp/tutorial/d400-occ/` |
| 핵심 | `ExampleAutocalibrateDevice.cs` |
| 역할 | C#OCC튜토리얼 |

---

## 사전 조건

- Visual Studio + .NET (프로젝트 CMake/`Intel.RealSense` 래퍼 빌드)
- D400 계열 장치
- C# RealSense 바인딩 사용 가능

---

## 빌드·실행

CMake에서 C# 래퍼/튜토리얼을 빌드한 뒤, `d400-occ` 실행 파일을 Visual Studio 또는 출력 폴더에서 실행한다.

```text
wrappers/csharp/tutorial/d400-occ/
  Program.cs
  Window.xaml(.cs)          # WPF UI (해당 구성 시)
  ExampleAutocalibrateDevice.cs
```

---

## 콘솔 메뉴 (`ExampleAutocalibrateDevice`)

시작 시:

| 선택 | 동작 |
|------|------|
| 1 | Calibrate (OCC) |
| 2 | Reset calibration to factory defaults |
| 3 | Calibration modes test |
| 4 | Exit |

### OCC 파라미터 개념

| 항목 | 값 |
|------|-----|
| Speed | VeryFast / Fast(권장) / Medium / Slow |
| Scan | Intrinsic(기본) / Extrinsic |
| Health | Good / CouldBePerformed / NeedRecalibration / Failed |

절차 안내·health 해석·flash write는 클래스 내 `Calibrate` / `ResetToFactoryCalibration` 흐름을 따른다.

---

## 참고

- C++ CLI 예제: `examples/on-chip-calib`
- Python 자동 시퀀스: `depth_auto_calibration_example.py`
