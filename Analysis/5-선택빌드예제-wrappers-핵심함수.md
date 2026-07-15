# 5. 선택 빌드 예제 (`wrappers/`) — 핵심 함수

> 작성: 2026-06-19  
> 출처 표: `Analysis/예제-실행파일-난이도-기능별-분류.md` §5

---

## rs-pcl

**소스:** `wrappers/pcl/pcl/rs-pcl.cpp`  
**빌드:** PCL, `BUILD_PCL_EXAMPLES`  
**중요 기능:** PCL 포인트클라우드 + PassThrough 필터

| RealSense API | 설명 |
|---------------|------|
| `rs2::pointcloud pc` | depth → points |
| `pc.calculate(depth)` | `rs2::points` 생성 |
| `points.get_vertices()` | float3 vertex 배열 |
| `points.get_profile().as<video_stream_profile>()` | width/height |

| PCL API | 설명 |
|---------|------|
| `points_to_pcl()` | `rs2::points` → `pcl::PointCloud<pcl::PointXYZ>` |
| `pcl::PassThrough<pcl::PointXYZ>` | Z축 거리 필터 |
| `pass.setFilterLimits(0, 4)` | 0~4m 범위 |
| `pass.filter(*cloud_filtered)` | 필터 적용 |
| `draw_pointcloud()` | OpenGL로 PCL cloud 표시 |

---

## rs-pcl-color

**소스:** `wrappers/pcl/pcl-color/rs-pcl-color.cpp`  
**빌드:** PCL, `BUILD_PCL_EXAMPLES`  
**중요 기능:** RGB 텍스처 PCL 포인트클라우드·PCD 저장

| RealSense API | 설명 |
|---------------|------|
| `pipe.start()` | color+depth 스트리밍 |
| `rs2::pointcloud pc`, `pc.map_to(color)` | color 텍스처 매핑 |
| `pc.calculate(depth)` | points + texture coordinates |
| `points.get_texture_coordinates()` | UV 좌표 |
| `RGB_Texture(texture, Texture_XY)` | UV → RGB 픽셀 (`tuple<int,int,int>`) |

| PCL API | 설명 |
|---------|------|
| `pcl::PointXYZRGB` | RGB 포인트 타입 |
| `pcl::io::savePCDFile()` | `.pcd` 저장 |
| `pcl::visualization::PCLVisualizer` / `CloudViewer` | 3D 뷰어 |
| `Load_PCDFile()`, `cloudViewer()` | 저장·재로드·표시 루프 |

---

## rs-pointcloud-stitching

**소스:** `wrappers/pointcloud/pointcloud-stitching/rs-pointcloud-stitching.cpp`  
**빌드:** `BUILD_PC_STITCHING=ON`  
**중요 기능:** 다중 카메라 포인트클라우드 스티칭

| 핵심 클래스 / API | 설명 |
|-------------------|------|
| `CPointcloudStitcher` (`rs-pointcloud-stitching.h`) | 멀티카메라 스티처 메인 클래스 |
| `pc_stitcher.Init()` | 캘리브 파일·작업 디렉터리 초기화 |
| `pc_stitcher.Start()` | 다중 장치 센서 시작 |
| `pc_stitcher.Run(app)` | GL 루프·스티칭·표시 |
| `pc_stitcher.StopSensors()`, `CloseSensors()` | 정리 |
| `position_and_rotation` | 4×4 변환 행렬 (회전·translation) |
| `operator*` | 변환 행렬 곱 (카메라 pose 체인) |
| `rs2_intrinsics`, `rs2_extrinsics` | 멀티카메라 정합 (`rsutil.h`) |

---

## RealSenseBagReader (Open3D)

**소스:** `wrappers/open3d/cpp/RealSenseBagReader.cpp`  
**빌드:** Open3D, `BUILD_OPEN3D_EXAMPLES`  
**중요 기능:** RealSense `.bag` 재생·이미지 추출

| Open3D API | 설명 |
|------------|------|
| `t::io::RSBagReader` | RealSense bag 리더 |
| `bag_reader.Open(bag_filename)` | bag 열기 |
| `bag_reader.GetMetadata()` | 장치명·해상도·fps·duration |
| `bag_reader.NextFrame()` | 다음 RGBD 프레임 |
| `.ToLegacyRGBDImage()` | legacy RGBDImage 변환 |
| `bag_reader.SeekTimestamp()` | ±1초 시크 |
| `bag_reader.IsEOF()` | EOF 확인 |
| `io::WriteImage()` | color/depth PNG 저장 (`--output`) |
| `VisualizerWithKeyCallback` | color+depth 동시 표시·SPACE/ESC |

---

## RealSenseRecorder (Open3D)

**소스:** `wrappers/open3d/cpp/RealSenseRecorder.cpp`  
**빌드:** Open3D, `BUILD_OPEN3D_EXAMPLES`  
**중요 기능:** Open3D로 RealSense 녹화·라이브 뷰

| Open3D API | 설명 |
|------------|------|
| `tio::RealSenseSensor::ListDevices()` | `--list-devices` |
| `io::ReadIJsonConvertible(config_file, rs_cfg)` | JSON 스트림 설정 |
| `tio::RealSenseSensor rs` | RealSense 래퍼 |
| `rs.InitSensor(rs_cfg, 0, bag_file)` | 센서·선택적 bag 경로 |
| `rs.StartCapture(flag_start)` | 캡처 시작 |
| `rs.CaptureFrame(true, align_streams)` | RGBD 프레임 (align 옵션) |
| `rs.PauseRecord()`, `ResumeRecord()` | 녹화 pause/resume |
| `GetMetadata().ToString()` | 메타데이터 출력 |

---

## rs-face-dlib

**소스:** `wrappers/dlib/face/rs-face-dlib.cpp`  
**빌드:** Dlib  
**중요 기능:** 얼굴 랜드마크 + depth anti-spoof

| RealSense API | 설명 |
|---------------|------|
| `pipe.start()`, `get_depth_scale(dev)` | 스트리밍·depth scale |
| `rs2::align align_to_color(COLOR)` | depth→color 정렬 |
| `rs_frame_image<dlib::rgb_pixel, RGB8>(color_frame)` | RealSense → dlib image |

| Dlib API | 설명 |
|----------|------|
| `dlib::get_frontal_face_detector()` | HOG 얼굴 검출 |
| `dlib::shape_predictor` | 68-point 랜드마크 |
| `dlib::deserialize("shape_predictor_68_face_landmarks.dat")` | 모델 로드 |
| `face_bbox_detector(image)` | bbox 목록 |
| `face_landmark_annotator(image, bbox)` | 랜드마크 |

| 커스텀 | 설명 |
|--------|------|
| `validate_face(depth, scale, face)` | depth로 실제 얼굴 vs 평면 판별 |
| `render_face(face, color)` | 랜드마크 오버레이 |
| `dlib::image_window` | 결과 표시 |

---

## rs-face-vino

**소스:** `wrappers/openvino/face/rs-face-vino.cpp`  
**빌드:** OpenVINO  
**중요 기능:** OpenVINO 얼굴 검출 + RealSense depth

| RealSense API | 설명 |
|---------------|------|
| `pipe.start()` | color+depth |
| `rs2::align align_to(COLOR)` | 정렬 |
| `frame_to_mat(color_frame)` | OpenCV Mat |

| OpenVINO (`rs-vino/`) | 설명 |
|-----------------------|------|
| `InferenceEngine::Core engine` | IE 런타임 |
| `openvino_helpers::object_detection` | face-detection-adas-0001 래퍼 |
| `detector.load_into(engine, "CPU")` | 모델·CPU 플러그인 로드 |
| `detector.submit_frame(image)` | 추론 요청 |
| `detector.fetch_results()` | 검출 bbox·confidence |
| `detected_objects` | 결과 컬렉션·트래킹 ID |

---

## rs-dnn-vino

**소스:** `wrappers/openvino/dnn/rs-dnn-vino.cpp`  
**빌드:** OpenVINO  
**중요 기능:** 디스크의 여러 OpenVINO DNN 모델 런타임 전환

| RealSense API | 설명 |
|---------------|------|
| `pipe.start()`, `rs2::align` | color+depth·정렬 |
| `frame_to_mat()` | Mat 변환 |

| OpenVINO | 설명 |
|----------|------|
| `load_detectors_into()` | `*.xml` glob → detector 목록 |
| `detector_and_labels` | 모델 + labels 파일 |
| `openvino_helpers::read_labels()` | `.labels` 클래스 이름 |
| `detector->load_into(engine, device)` | 각 모델 IE 로드 |
| `detector->submit_frame()`, `fetch_results()` | 추론·결과 |
| 런타임 모델 전환 | 키 입력으로 detector 인덱스 변경 |

---

*각 예제는 해당 서드파티(PCL/Open3D/Dlib/OpenVINO) 설치·CMake 옵션 필요*
