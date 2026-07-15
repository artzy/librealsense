# D415 예제 — Windows 빌드·실행 가이드

> 작성: 2026-06-18  
> 환경: Windows 10/11, Visual Studio 2022, CMake 4.1, Python 3.11  
> 연결 장치: **Intel RealSense D415** (PID `0AD3`, FW 5.17.0.10)

---

## 1. 빌드 결과 (완료 — ALL_BUILD)

CMake `ALL_BUILD`로 기본 예제·도구 전체 빌드 완료.

### 예제 (examples/)

| 실행 파일 | 설명 |
|-----------|------|
| `rs-hello-realsense.exe` | depth 콘솔 출력 |
| `rs-capture.exe` | depth + color GUI |
| `rs-align.exe` / `rs-align-advanced.exe` / `rs-align-gl.exe` | depth-color 정렬 |
| `rs-pointcloud.exe` | 텍스처 포인트클라우드 3D 뷰 |
| `rs-gl.exe` | GPU 가속 포인트클라우드 |
| `rs-labeled-pointcloud.exe` | 라벨 포인트클라우드 |
| `rs-post-processing.exe` | 후처리 필터 + 3D 비교 |
| `rs-measure.exe` | 3D 거리 측정 |
| `rs-multicam.exe` | 다중 카메라 |
| `rs-hdr.exe` | HDR (D400) |
| `rs-record-playback.exe` | 녹화/재생 |
| `rs-on-chip-calib.exe` | 온칩 캘리브레이션 |

### 도구 (tools/)

| 실행 파일 | 설명 |
|-----------|------|
| `realsense-viewer.exe` | 공식 GUI 뷰어 |
| `rs-depth-quality.exe` | 깊이 품질 측정 |
| `rs-enumerate-devices.exe` | 장치 정보 |
| `rs-fw-update.exe` / `rs-terminal.exe` | 펌웨어 / HWM |

### 라이브러리

`realsense2.dll`, `realsense2-gl.dll`, `pyrealsense2.cp311-win_amd64.pyd`

### OpenCV 예제 (wrappers/opencv/) — 빌드 완료

OpenCV 경로: `D:\Dev2019\opencv-4.13.0`  
CMake: `-DOpenCV_DIR=D:/Dev2019/opencv-4.13.0/x64/vc16/lib`

| 실행 파일 | 설명 |
|-----------|------|
| `rs-imshow.exe` | OpenCV depth 표시 |
| `rs-grabcuts.exe` | GrabCut 배경 제거 |
| `rs-latency-tool.exe` | 지연 측정 |
| `rs-dnn.exe` | DNN 객체 검출 |
| `rs-depth-filter.exe` | depth 필터 |
| `rs-rotate-pc.exe` | 포인트클라우드 회전 |

실행 시 OpenCV DLL PATH 추가:
```bat
set PATH=D:\Dev2019\opencv-4.13.0\x64\vc16\bin;D:\Dev2019\opencv-4.13.0\bin;%PATH%
```

### 빌드되지 않음 (추가 의존성 필요)

| 예제 | 필요 조건 |
|------|----------|
| `rs-kinfu` (실시간 3D 재구성) | **opencv_contrib** `rgbd` 모듈 포함 OpenCV 재빌드 필요 (현재 설치본에 `opencv2/rgbd/kinfu.hpp` 없음) |
| `rs-pcl` | PCL, `BUILD_PCL_EXAMPLES=ON` |
| `rs-pointcloud-stitching` | `BUILD_PC_STITCHING=ON` |
| Open3D 예제 | Open3D, `BUILD_OPEN3D_EXAMPLES=ON` |

---

## 2. 빠른 실행

### 배치 스크립트 (권장)

```bat
Analysis\build-d415-examples.bat   REM 최초 1회 또는 재빌드 시
Analysis\run-d415-examples.bat     REM 메뉴에서 예제 선택 실행
```

### 수동 실행

**반드시 `build\Release` 폴더에서 실행**하거나, PATH에 해당 폴더를 추가해야 `realsense2.dll`을 찾을 수 있습니다.

```powershell
cd d:\study\librealsense\build\Release

# 장치 확인
.\rs-enumerate-devices.exe -S

# 콘솔 예제 (Ctrl+C 종료)
.\rs-hello-realsense.exe

# GUI 예제
.\rs-capture.exe
.\rs-align.exe
```

---

## 3. Python Advanced Mode 예제

D415 PID(`0AD3`)가 `python-rs400-advanced-mode-example.py`의 지원 목록에 포함됩니다.

```powershell
cd d:\study\librealsense\build\Release
$env:PYTHONPATH = "d:\study\librealsense\build\Release"
C:\Users\PM\AppData\Local\Programs\Python\Python311\python.exe `
  d:\study\librealsense\wrappers\python\examples\python-rs400-advanced-mode-example.py
```

> **주의**: `.pyd`는 Python **3.11**용으로 빌드되었습니다. Python 3.14 등 다른 버전에서는 import 실패할 수 있습니다.

---

## 4. D415 장치 확인 결과

```
Device Name     : Intel RealSense D415
Serial Number   : 314522061035
Firmware        : 5.17.0.10
Product Id      : 0AD3
Product Line    : D400
Advanced Mode   : YES
Usb Type        : 3.2
```

---

## 5. D415 추천 학습 순서

| 순서 | 예제 | 설명 |
|------|------|------|
| 1 | `rs-hello-realsense` | Pipeline API, depth 값 읽기 |
| 2 | `rs-capture` | color + depth 동시 스트리밍 |
| 3 | `rs-align` | depth를 color 좌표계에 매핑 |
| 4 | `rs-post-processing` | spatial/temporal 필터 |
| 5 | `rs-measure` | 3D 측정 (High Accuracy 프리셋) |
| 6 | Python Advanced Mode | IR 패턴 제거 등 ASIC 튜닝 |

---

## 6. D415 전용 팁

### Advanced Mode — Remove IR Pattern

D415는 `d415_remove_ir` 프리셋을 지원합니다 (`src/ds/advanced_mode/presets.cpp`).

- Viewer에서 Color preset **"Remove IR2"** (1280x720)
- Depth preset **"Face2"** 권장 (LabVIEW readme 참고)

### Visual Preset (코드)

```cpp
depth_sensor.set_option(RS2_OPTION_VISUAL_PRESET, RS2_RS400_VISUAL_PRESET_HIGH_DENSITY);
```

KinFu 예제(`wrappers/opencv/kinfu/`)에서 D415에 이 프리셋을 사용합니다.

### 카메라 없이 테스트

`doc/sample-data.md`의 D415 녹화 파일:

- [outdoors.bag](https://librealsense.realsenseai.com/rs-tests/TestData/outdoors.bag)
- [depth_under_water.bag](https://librealsense.realsenseai.com/rs-tests/TestData/depth_under_water.bag)

---

## 7. 재빌드 (특정 타깃만)

```powershell
cmake --build d:\study\librealsense\build --config Release --parallel --target rs-capture
```

---

## 8. OpenCV 설정 및 KinFu (미빌드)

### OpenCV 경로

```
D:\Dev2019\opencv-4.13.0
OpenCV_DIR = D:/Dev2019/opencv-4.13.0/x64/vc16/lib
버전: 4.13.0 (opencv_world4130.lib)
```

### CMake 재설정 (OpenCV 예제 포함)

```powershell
cmake -S d:\study\librealsense -B d:\study\librealsense\build `
  -G "Visual Studio 17 2022" -A x64 `
  -DBUILD_PYTHON_BINDINGS=ON `
  -DBUILD_CV_EXAMPLES=ON `
  -DBUILD_CV_KINFU_EXAMPLE=OFF `
  -DOpenCV_DIR=D:/Dev2019/opencv-4.13.0/x64/vc16/lib

cmake --build d:\study\librealsense\build --config Release --parallel --target rs-imshow
```

### rs-kinfu가 빌드되지 않는 이유

현재 OpenCV 설치본은 **opencv_contrib 없이** 빌드되어 `opencv2/rgbd/kinfu.hpp` 헤더가 없습니다.

KinFu를 사용하려면 OpenCV를 **opencv_contrib** 와 함께 재빌드해야 합니다:

1. [opencv_contrib](https://github.com/opencv/opencv_contrib) 클론 (4.13.0 브랜치)
2. CMake에서 `OPENCV_EXTRA_MODULES_PATH` 에 contrib/modules 지정
3. `rgbd` 모듈 포함 확인 후 빌드·설치
4. librealsense 재설정:

```powershell
cmake ... -DBUILD_CV_KINFU_EXAMPLE=ON -DOpenCV_DIR=<새 OpenCV 경로>
```

> KinFu CMakeLists는 `find_package(glfw3)` 를 사용합니다. librealsense 내장 GLFW 경로 지정이 추가로 필요할 수 있습니다.

---

## 9. CMake 설정 요약 (현재 build/)

```
Generator : Visual Studio 17 2022, x64
Backend   : RS2_USE_WMF_BACKEND (Windows 10/11)
Options   : BUILD_PYTHON_BINDINGS=ON
            BUILD_EXAMPLES=ON (기본)
            BUILD_GRAPHICAL_EXAMPLES=ON (기본)
```

---

## 10. 문제 해결

| 증상 | 해결 |
|-----------|------|
| `realsense2.dll` 없음 | `build\Release`에서 실행하거나 DLL 경로 추가 |
| 장치 미검출 | USB 3.x 포트, RealSense 드라이버 확인 |
| Python import 실패 | Python 3.11 사용 + `PYTHONPATH=build\Release` |
| GUI 예제 즉시 종료 | 카메라가 다른 프로그램(Viewer 등)에서 사용 중인지 확인 |
| 메타데이터 없음 | `scripts/realsense_metadata_win10.ps1` (관리자) 실행 |
