# 4. OpenCV 예제 (`wrappers/opencv/`) — 핵심 함수

> 작성: 2026-06-19  
> 빌드: `BUILD_CV_EXAMPLES=ON`, `OpenCV_DIR` 지정  
> 출처 표: `Analysis/예제-실행파일-난이도-기능별-분류.md` §4

---

## rs-imshow

**소스:** `wrappers/opencv/imshow/rs-imshow.cpp`  
**중요 기능:** colorized depth OpenCV 창 표시 (최소 연동)

| 함수 / API | 설명 |
|------------|------|
| `rs2::colorizer` | depth → RGB |
| `pipe.start()` | 기본 Pipeline |
| `data.get_depth_frame().apply_filter(color_map)` | colorized depth 프레임 |
| `cv::Mat(Size(w,h), CV_8UC3, data, AUTO_STEP)` | RealSense 버퍼 zero-copy Mat |
| `cv::namedWindow()`, `cv::imshow()` | OpenCV 창 |
| `cv::waitKey(1)`, `getWindowProperty(WND_PROP_AUTOSIZE)` | 루프·창 닫기 감지 |

---

## rs-grabcuts

**소스:** `wrappers/opencv/grabcuts/rs-grabcuts.cpp`  
**중요 기능:** depth 초기 마스크 + GrabCut 전경 분리

| RealSense API | 설명 |
|---------------|------|
| `rs2::align align_to(RS2_STREAM_COLOR)` | depth→color 정렬 |
| `align_to.process(data)` | 정렬 frameset |
| `colorize.set_option(RS2_OPTION_COLOR_SCHEME, 2)` | near=white 히스토그램 equalization |
| `depth.apply_filter(colorize)` | depth 시각화 |

| OpenCV API | 설명 |
|------------|------|
| `frame_to_mat()` | RealSense → Mat (`cv-helpers.hpp`) |
| `threshold()`, `dilate()`, `erode()` | near/far depth 마스크 생성 |
| `mask.setTo(GC_FGD/GC_PR_BGD/GC_BGD)` | GrabCut 초기 마스크 |
| `cv::grabCut(color_mat, mask, ..., GC_INIT_WITH_MASK)` | GrabCut 최적화 분할 |
| `color_mat.copyTo(foreground, mask)` | 전경만 추출 |

---

## rs-latency-tool

**소스:** `wrappers/opencv/latency-tool/rs-latency-tool.cpp` + `latency-detector.h`  
**중요 기능:** 화면 패턴(이진 시계)으로 end-to-end 지연 추정

| RealSense API | 설명 |
|---------------|------|
| `cfg.enable_stream(RS2_STREAM_COLOR, 1920, 1080, BGR8, 30)` | 고해상도 color (설정 변경 가능) |
| `pipe.start(cfg)` | Pipeline 시작 |
| `pipe.wait_for_frames()` | color 프레임 수신 |

| 커스텀 / OpenCV | 설명 |
|-----------------|------|
| `detector::submit_frame(f)` | 카메라 프레임을 지연 검출기에 전달 |
| `detector::get_next_value()` | 다음 표시할 시계 값 |
| `detector::begin_render()` | 렌더 시간 측정 시작 |
| `bit_packer::try_pack()` | 값을 이진 비트로 인코딩 |
| `detector::copy_preview_to(display)` | 검출 결과 미리보기 |
| `cv::circle()` | 비트를 원 패턴으로 화면에 렌더 |
| `cv::waitKey()` | 실제 화면 출력·지연 측정 트리거 |

---

## rs-dnn

**소스:** `wrappers/opencv/dnn/rs-dnn.cpp`  
**중요 기능:** MobileNet-SSD 검출 + depth 거리

| RealSense API | 설명 |
|---------------|------|
| `pipe.start()` | color+depth 기본 스트림 |
| `rs2::align align_to(RS2_STREAM_COLOR)` | depth 정렬 |
| `align_to.process(data)` | 정렬 |
| `depth_frame_to_meters(depth_frame)` | depth → 미터 float Mat |

| OpenCV DNN | 설명 |
|------------|------|
| `readNetFromCaffe(prototxt, caffemodel)` | MobileNet-SSD 로드 |
| `blobFromImage()` | 입력 blob 생성 |
| `net.setInput()`, `net.forward("detection_out")` | 추론 |
| `mean(depth_mat(object))` | bbox 내 평균 depth → 거리 |
| `rectangle()`, `putText()` | bbox·거리 라벨 |

---

## rs-depth-filter

**소스:** `wrappers/opencv/depth-filter/rs-depth-filter.cpp`  
**중요 기능:** outdoor 드론 OA용 고신뢰 depth (커스텀 `rs2::filter`)

| RealSense API | 설명 |
|---------------|------|
| `cfg.enable_stream(DEPTH, 848, 480)`, `INFRARED, 1` | D43x depth+IR |
| `cfg.resolve(pipe)` | 프로파일 사전 확인 |
| `prof.get_device().as<rs400::advanced_mode>()` | Advanced Mode |
| `advanced.load_json(str)` | `camera-settings.json` 로드 |
| `data.apply_filter(filter)` | 커스텀 필터 적용 |

| `high_confidence_filter` (커스텀) | 설명 |
|-----------------------------------|------|
| `downsample_min_4x4()` | 4×4 depth 다운샘플 |
| `cv::cornerHarris()` | Harris 코너 → 신뢰 마스크 |
| `cv::Scharr()`, `convertScaleAbs()` | IR 엣지 검출 |
| `cv::morphologyEx(MORPH_OPEN)` | 마스크 정제 |
| `decimated_depth.copyTo(output, combined_mask)` | 신뢰 픽셀만 depth 유지 |
| `src.allocate_video_frame()`, `allocate_composite_frame()` | SDK filter 출력 프레임 생성 |
| `src.frame_ready(cmp)` | 필터 결과 전달 |

---

## rs-rotate-pc

**소스:** `wrappers/opencv/rotate-pointcloud/rs-rotate-pc.cpp`  
**중요 기능:** depth 포인트클라우드 yaw/roll 회전 시뮬레이션

| RealSense API | 설명 |
|---------------|------|
| `rs2::align depthToColorAlignment(COLOR)` | depth→color 정렬 |
| `rs2::threshold_filter` | min/max 거리 클리핑 |
| `threshold.set_option(MIN/MAX_DISTANCE)` | 0.3~1.5m |
| `rs2::processing_block` | 커스텀 lambda 필터 (회전 depth 생성) |
| `pipe.wait_for_frames().apply_filter(procBlock)` | 회전된 depth |

| OpenCV | 설명 |
|--------|------|
| `cv::Mat(CV_16UC1, data, AUTO_STEP)` | depth zero-copy |
| yaw 시뮬레이션 | 열 인덱스를 depth 값으로 재매핑 |
| `cv::rotate(image, rotated, angle)` | roll 90°/180°/270° |
| `color_map.process()` | 회전 depth colorize |

---

## rs-kinfu

**소스:** `wrappers/opencv/kinfu/rs-kinfu.cpp`  
**중요 기능:** OpenCV contrib KinectFusion 실시간 3D 재구성

| RealSense API | 설명 |
|---------------|------|
| `cfg.enable_stream(DEPTH, 640, 480, Z16)` | KinFu 권장 해상도 |
| `dpt.set_option(VISUAL_PRESET, DEFAULT)` | ICP 안정 프리셋 |
| `dpt.get_depth_scale()` | KinFu `depthFactor` |
| `depth_profile.get_intrinsics()` | 카메라 intrinsics → KinFu params |
| `decimation`, `spatial`, `temporal` | depth 전처리 |

| OpenCV rgbd::KinFu | 설명 |
|--------------------|------|
| `Params::defaultParams()` | 기본 TSDF·ICP 파라미터 |
| `params->intr`, `params->depthFactor`, `params->frameSize` | RealSense에 맞게 스케일·intrinsics 조정 |
| `KinFu::create(params)` | KinFu 인스턴스 (CPU 경로) |
| `kf->update(depth_mat)` | depth 프레임 fusion·pose 추정 |
| `kf->reset()` | ICP 실패 연속 시 볼륨 리셋 |
| `kf->render(rendered)` | TSDF raycast → 2D 렌더 이미지 |
| `draw_kinfu_render()` | GL로 rendered Mat 표시 |
| `export_to_ply()` | fusion 결과 PLY 저장 |

---

*rs-kinfu: `opencv_contrib` rgbd, `BUILD_CV_KINFU_EXAMPLE=ON` 필요*
