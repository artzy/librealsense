# rs-kinfu 수정·적용 내역

> 대상: `wrappers/opencv/kinfu/rs-kinfu.cpp`  
> 환경: Windows, Visual Studio 2022, D415, RTX 3060 (12GB VRAM)  
> OpenCV: 4.13.0 + opencv_contrib (`OPENCV_ENABLE_NONFREE=ON`)  
> 정리 일자: 2026-06-18

---

## 1. 개요

Intel RealSense **rs-kinfu** 예제를 D415 + Windows 환경에서 실행 가능하도록 수정한 내역입니다.  
원본은 OpenCV KinFu의 `getCloud()` + OpenGL 포인트클라우드 표시 방식이었으나, NVIDIA GPU 환경에서 여러 OpenCL 이슈와 ICP 추적 실패로 **검은 화면·reset 반복**이 발생했습니다.

관련 초기 분석: [rs-kinfu-프로젝트-분석.md](./rs-kinfu-프로젝트-분석.md)

---

## 2. 문제 요약 및 해결

| # | 증상 | 원인 | 적용한 해결 |
|---|------|------|-------------|
| 1 | `KinFu init failed` (NONFREE) | OpenCV 빌드 시 `OPENCV_ENABLE_NONFREE` 미설정 | opencv_contrib 재빌드 (사전 요구) |
| 2 | `fillPtsNrm` OpenCL 오류, 검은 화면 | `getCloud()` → `fillPtsNrm` 커널이 NVIDIA에서 실패 | **`getCloud()` 제거**, `kf->render()` 로 표시 |
| 3 | OpenCL ON 후에도 검은 화면 | 위와 동일 + 포인트클라우드 비어 있음 | `draw_kinfu_render()` 텍스처 렌더링 |
| 4 | `reset` 콘솔 출력 반복 | `update()` ICP 실패 → 즉시 `kf->reset()` | **CPU KinFu 경로** + reset 디바운스 |
| 5 | ICP 실패 지속 (OpenCL ON) | NVIDIA OpenCL ICP (`getAb` 커널) 불안정 | `cv::ocl::setUseOpenCL(false)` |
| 6 | 추적 불안정 | intrinsics/decimation 불일치, HIGH_DENSITY 노이즈 | intrinsics 스케일, DEFAULT 프리셋, 640×480 |

---

## 3. 변경 타임라인 (대화 세션 기준)

### 3.1 OpenCL ON 시도

- `cv::ocl::setUseOpenCL(true)` 적용
- RTX 3060 인식 확인: `OpenCL enabled: NVIDIA GeForce RTX 3060`
- `getCloud()` 호출 시 `fillPtsNrm` (128³ 또는 512³) `CL_OUT_OF_RESOURCES` 지속  
  → **VRAM 문제가 아님** (OpenCV rgbd OpenCL 버그, [opencv_contrib #2029](https://github.com/opencv/opencv_contrib/issues/2029))

### 3.2 시각화 경로 변경 (검은 화면 해결)

- **제거**: `draw_kinfu_pointcloud()` + `kf->getCloud()`
- **추가**: `draw_kinfu_render()` + `kf->render()`
- OpenCV `kinfu_demo`와 동일하게 **Phong 셰이딩 2D 이미지**로 융합 장면 표시
- `mat_queue`에 `rendered` (CV_8UC4) 전달

### 3.3 KinFu 파라미터 조정

| 단계 | Params | ICP 거리 | ICP 각도 | 비고 |
|------|--------|----------|----------|------|
| 원본 | `coarseParams()` | 0.1 m | 30° | 128³ 볼륨 |
| 1차 | `defaultParams()` | 0.15 m | 45° | reset 여전히 발생 |
| **최종** | `defaultParams()` | **0.2 m** | **60°** | 512³ 볼륨, ICP {10,5,4} |

### 3.4 reset 반복 해결 (최종)

1. **`cv::ocl::setUseOpenCL(false)`**  
   - `KinFu::create()` 시 `KinFuImpl<Mat>` (CPU) 사용  
   - OpenCL ICP 대신 **CPU Mat ICP** → 추적 안정
2. **reset 디바운스**  
   - ICP 1회 실패마다 reset → **30프레임 연속 실패** 시에만 reset  
   - 메시지: `reset (ICP lost for 30 frames)`
3. **깊이 파이프라인 개선** (아래 §4)

---

## 4. 현재 적용된 설정 (최종 코드)

### 4.1 RealSense

```cpp
cfg.enable_stream(RS2_STREAM_DEPTH, 640, 480, RS2_FORMAT_Z16);
dpt.set_option(RS2_OPTION_VISUAL_PRESET, RS2_RS400_VISUAL_PRESET_DEFAULT);
decimation.set_option(RS2_OPTION_FILTER_MAGNITUDE, 2);  // → 320×240
spatial + temporal 필터
clipping: max_dist = 2.5 m
```

### 4.2 KinFu Params

```cpp
Params::defaultParams()
volumeDims = 512³
icpDistThresh = 0.2f
icpAngleThresh = 60°
frameSize = decimation 후 크기 (320×240)
intrinsics = fx,fy,cx,cy × (decimated/raw) 스케일
depthFactor = 1 / depth_scale
OpenCL = false  → CPU KinFu
```

### 4.3 처리·표시 아키텍처

```
[워커 스레드]
  wait_for_frames → decimation/spatial/temporal
  → Mat 복사 + 클리핑 → kf->update(Mat)
  → 성공 시 kf->render() → render_queue

[메인 스레드]
  render_queue → draw_kinfu_render() (OpenGL 텍스처)
```

### 4.4 유지·미사용 코드

- `colorize_pointcloud()`, `export_to_ply()`: PLY 내보내기용으로 **코드만 유지**, 현재 런타임 경로에서는 **호출하지 않음** (`getCloud` OpenCL 이슈로 export 비활성)

---

## 5. 원본 대비 주요 코드 차이

| 항목 | 원본 (`readme`/초기 코드) | 현재 |
|------|---------------------------|------|
| Params | `coarseParams()` | `defaultParams()` + ICP 완화 |
| 깊이 해상도 | 1280×720 | 640×480 |
| 프리셋 | HIGH_DENSITY | DEFAULT |
| OpenCL | `setUseOpenCL(false)` (후 ON 시도) | **`setUseOpenCL(false)` (CPU 고정)** |
| 표시 | `getCloud()` + GL_POINTS | **`render()` + GL 텍스처** |
| reset | `update()` 실패 즉시 | **30프레임 연속 실패 시** |
| 깊이 클리핑 | RealSense 버퍼 in-place 수정 | **Mat 복사 후 클리핑** |
| intrinsics | decimation 후 스케일 없음 (초기) | **decimation 비율로 스케일** |

---

## 6. 빌드·실행

### 6.1 CMake (KinFu 예제 포함)

```powershell
cmake -S d:\study\librealsense -B d:\study\librealsense\build `
  -G "Visual Studio 17 2022" -A x64 `
  -DBUILD_CV_EXAMPLES=ON `
  -DBUILD_CV_KINFU_EXAMPLE=ON `
  -DBUILD_GRAPHICAL_EXAMPLES=ON `
  -DKINFU_OPENCV_ROOT=D:/Dev2019/opencv-4.13.0-contrib

cmake --build d:\study\librealsense\build --config Release --parallel --target rs-kinfu
```

### 6.2 실행

```powershell
cd d:\study\librealsense\build\Release
.\rs-kinfu.exe
```

### 6.3 정상 시작 메시지

```
KinFu: CPU path (stable ICP; OpenCL ICP fails on many NVIDIA GPUs)
```

- `fillPtsNrm` 오류 **없어야** 함
- `reset`은 추적을 오래 잃었을 때만 가끔 출력

---

## 7. OpenCL / VRAM 관련 정리

| 주제 | 결론 |
|------|------|
| 12GB VRAM으로 OpenCL ON? | TSDF integrate는 가능하나 **`getCloud`/`fillPtsNrm`은 NVIDIA에서 실패** |
| OpenCL ICP ON (RTX 3060) | **`getAb` 커널 경로 불안정** → ICP 매 프레임 실패 → reset 반복 |
| 현재 선택 | **CPU KinFu 전체** (TSDF+ICP). 속도↓, 안정성↑ |
| 향후 OpenCL TSDF + CPU ICP | OpenCV `fast_icp.cpp` 패치 필요 (ICP GPU 분기 비활성) |

---

## 8. 사용 팁

1. **카메라를 천천히** 움직이며, 책상·물체 등 **깊이 변화가 있는 장면** 촬영
2. RealSense Viewer 등 **다른 프로그램에서 D415 사용 중이면** 종료
3. 화면은 **3D 포인트클라우드가 아닌** 융합 장면 **렌더 이미지** (회색 배경 + 중앙 Phong 셰이딩)
4. `reset (ICP lost for 30 frames)` 가 잦으면 움직임을 더 느리게, 또는 장면에 특징 추가

---

## 9. 알려진 제한

- PLY 자동 저장: `getCloud()` 의존 → **현재 비활성**
- 마우스 orbit: `make_view_pose` 제거됨 → `render()`는 **추적 카메라 시점** 기준
- CPU 경로: 512³ TSDF → **프레임레이트는 OpenCL 대비 낮을 수 있음**
- `export_to_ply` PLY 헤더 `property float8 x` 형식: 원본 버그 그대로 (표준 PLY 파서 호환 주의)

---

## 10. 참고 링크

- [OpenCV KinFu API](https://docs.opencv.org/4.x/d8/d1f/classcv_1_1kinfu_1_1KinFu.html)
- [opencv_contrib KinFu 이슈 #2029](https://github.com/opencv/opencv_contrib/issues/2029)
- [librealsense rs-kinfu readme](../wrappers/opencv/kinfu/readme.md)
- [D415 Windows 빌드 가이드](./D415-예제-Windows-빌드-실행-가이드.md)

---

## 11. 수정 파일 목록

| 파일 | 변경 |
|------|------|
| `wrappers/opencv/kinfu/rs-kinfu.cpp` | 전체 로직·파라미터·렌더링·ICP/reset 정책 |
| `Analysis/rs-kinfu-프로젝트-분석.md` | 초기 프로젝트 분석 (선행 문서) |
| `Analysis/rs-kinfu-수정-적용-내역.md` | **본 문서** |

---

*본 문서는 Cursor 대화 세션에서 rs-kinfu에 적용한 수정 사항을 통합 정리한 것입니다.*
