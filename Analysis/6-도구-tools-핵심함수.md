# 6. 도구 (`tools/`) — 예제 vs 실무 (핵심 함수)

> 작성: 2026-06-19  
> 예제는 API 학습, 도구는 장치 운영·디버깅에 가깝습니다.  
> 출처 표: `Analysis/예제-실행파일-난이도-기능별-분류.md` §6

---

## realsense-viewer

**소스:** `tools/realsense-viewer/viewer-main.cpp` → `realsense-viewer.cpp`  
**중요 기능:** 공식 GUI — 스트림·녹화·캘리브·Advanced Mode

| 함수 / API | 설명 |
|------------|------|
| `run_viewer(argc, argv)` | Viewer 메인 진입 (`realsense-viewer.h`) |
| `rs2::cli("realsense-viewer").process()` | CLI·로그·DDS 등 설정 |
| `context ctx(settings.dump())` | 장치 컨텍스트 |
| `ux_window window(...)` | ImGui+GL 메인 윈도우 |
| `device_changes devices_connection_changes(ctx)` | 장치 연결/해제 이벤트 |
| `viewer_model viewer_model(ctx, ...)` | 스트림·녹화·필터·캘리브 UI 모델 |
| `update_viewer_configuration(viewer_model)` | 설정 로드 |
| `rs2::log_to_callback()` | 로그를 UI notifications에 표시 |
| `device_models` / `device_model` | per-device 스트림 패널·post-processing |
| (내부) record/playback, advanced mode, depth quality 패널 | 예제 기능의 GUI 통합 상위 대체 |

---

## rs-enumerate-devices

**소스:** `tools/enumerate-devices/rs-enumerate-devices.cpp`  
**중요 기능:** 연결 장치·센서·옵션·캘리브 데이터 나열

| 함수 / API | 설명 |
|------------|------|
| `context ctx(settings.dump())` | DDS on/off 등 CLI 설정 |
| `ctx.query_devices(mask)` | Intel/SW-only 장치 목록 |
| `ctx.load_device(playback_file)` | `-p` playback 파일 장치 검사 |
| `print(rs2_intrinsics)` | fx,fy,ppx,ppy,distortion |
| `print(rs2_extrinsics)` | rotation·translation 행렬 |
| `print(rs2_motion_device_intrinsic)` | IMU intrinsic |
| 장치 루프 | `get_info()`, `query_sensors()`, `get_stream_profiles()` |
| `-o` 옵션 | `sensor.supports(option)`, `get_option_range()`, `get_option()` |
| `-c` calib | stream profile `get_intrinsics()`, `get_extrinsics_to()` |
| `-d` defaults | 기본 스트림 구성 출력 |

---

## rs-depth-quality

**소스:** `tools/depth-quality/rs-depth-quality.cpp` + `depth-quality-model.h`  
**중요 기능:** depth 품질 메트릭 (fill rate, RMS, temporal noise 등)

| 함수 / API | 설명 |
|------------|------|
| `calculate_temporal_noise()` | 40프레임 FIFO → per-pixel std/median → temporal noise 메트릭 |
| `depth_images` deque | 시간적 depth 시퀀스 버퍼 |
| `rs2::region_of_interest roi` | ROI 내 픽셀만 분석 |
| `metric` / `single_metric_data` | fill rate, plane fit RMS, sub-pixel precision 등 |
| `depth_quality_model` (헤더) | UI·plane target·거리 슬라이더·메트릭 기록 |
| `rs2::pipeline`, `rs2::config` | depth 스트리밍 |
| `rs-config.h` | 뷰어와 공유 설정 |

---

## rs-record

**소스:** `tools/recorder/rs-record.cpp`  
**중요 기능:** CLI 녹화 (.db3)

| 함수 / API | 설명 |
|------------|------|
| `rs2::cli` | `-t` 시간(초), `-f` 출력 경로 |
| `cfg.enable_record_to_file(out_file)` | 녹화 파일 경로 |
| `pipe.start(cfg, callback)` | 녹화 중 프레임 콜백 (진행 시간 출력) |
| `pipe.stop()` | 녹화 종료·파일 flush |

---

## rs-convert

**소스:** `tools/convert/rs-convert.cpp` + `converters/*`  
**중요 기능:** bag/db3 프레임 → PNG/CSV/PLY/BIN 등 변환

| 함수 / API | 설명 |
|------------|------|
| `ctx.convert_bag_to_db3(in, out)` | legacy `.bag` → `.db3` (C API, `-D`) |
| `converter_png`, `converter_csv`, `converter_3d_csv` | 포맷별 변환기 |
| `converter_ply`, `converter_raw`, `converter_bin`, `converter_text` | 추가 포맷 |
| `rs2::pipeline`, `rs2::config` | `enable_device_from_file(bag)` 재생 |
| `pipe.start(cfg, callback)` | 프레임 순회·converter에 전달 |
| CLI 필터 | `-f/-t` 프레임 번호, `-s/-e` 시간, `-d/-c` depth/color only |

---

## rs-data-collect

**소스:** `tools/data-collect/rs-data-collect.cpp` + `rs-data-collect.h`  
**중요 기능:** 프레임 통계 CSV (대역·성능 분석)

| 함수 / API | 설명 |
|------------|------|
| `data_collector::parse_and_configure()` | CSV 설정 파일 파싱 (`stream_request`) |
| `parse_configuration()` | stream_type, width, height, format, fps, index |
| `sensor.open()`, `sensor.start(callback)` | 저수준 센서 스트리밍 |
| `on_frame_callback` | 프레임 헤더·IMU 데이터 CSV 기록 |
| `pipe` / 직접 sensor | 설정에 따른 멀티 스트림 |
| timeout / max_frames | `-t`, `-n` 종료 조건 |

---

## rs-fw-update

**소스:** `tools/fw-update/rs-fw-update.cpp`  
**중요 기능:** 펌웨어 업데이트

| 함수 / API | 설명 |
|------------|------|
| `read_fw_file(path)` | `.bin` 펌웨어 읽기 |
| `dev.as<rs2::update_device>()` | 업데이트 인터페이스 |
| `update(fwu_dev, fw_image)` | `fwu_dev.update(image, progress_cb)` |
| `ctx.on_devices_changed()` | 업데이트 후 재연결 장치 감지 |
| `print_device_info()` | 펌웨어 버전 등 |
| recovery 모드 | `RS2_CAMERA_INFO_FIRMWARE_UPDATE_ID` 등 recovery 장치 처리 |
| `common/fw-update-common.h` | 공유 업데이트 유틸 |

---

## rs-terminal

**소스:** `tools/terminal/rs-terminal.cpp` + `parser.hpp`  
**중요 기능:** HWM·펌웨어 raw 명령 터미널

| 함수 / API | 설명 |
|------------|------|
| `commands_xml` | XML 정의 명령 파싱 |
| `build_raw_command_data()` | CLI 문자열 → raw 바이트 |
| `encode_raw_command_data()` | parameter 인코딩 (`parser.hpp`) |
| `dev.as<rs2::debug_protocol_device>()` | debug/HWM 프로토콜 |
| `debug_dev.send_and_receive_raw(raw, response)` | raw 명령 송수신 |
| `auto_complete` | 명령 자동완성 (`auto-complete.h`) |
| `xml_mode()` | hex 토큰 → raw 명령 실행 |

---

## rs-fw-logger

**소스:** `tools/fw-logger/rs-fw-logger.cpp`  
**중요 기능:** 카메라 내부 펌웨어 로그 수집

| 함수 / API | 설명 |
|------------|------|
| `rs2::device_hub hub(ctx)` | 장치 연결 대기 |
| `dev.as<rs2::log_device>()` | FW 로그 인터페이스 |
| `fw_log_device.load_xml(xml_path)` | 이벤트 XML 정의 로드 |
| `fw_log_device.create_message()` | 로그 메시지 버퍼 |
| `get_firmware_log()` / `get_flash_log()` | RAM vs flash 로그 |
| `fw_log_device.parse_log(msg, parsed)` | XML 기반 파싱·문자열 |
| `log_message.data()` | raw 로그 바이트 |

---

## rs-embed

**소스:** `tools/embed/rs-embed.cpp`  
**중요 기능:** OBJ/PNG → LZ4 압축 C++ 임베드 (OEM·3D 모델)

| 함수 / API | 설명 |
|------------|------|
| `TCLAP::CmdLine` | 입력 파일·출력 경로 |
| `stbi_load()` | PNG 로드 |
| `LZ4_compress_default()` | raw 데이터 LZ4 압축 |
| 생성 `uncompress_*_obj()` | 압축 데이터 + `LZ4_decompress_safe()` 헤더 출력 |
| vertex/index memcpy | OBJ vertex·index 배열 복원 |

---

## rs-rosbag-inspector

**소스:** `tools/rosbag-inspector/rs-rosbag-inspector.cpp` + `rosbag_content.h`  
**중요 기능:** legacy ROS `.bag` 검사 (Foxglove db3 대안)

| 함수 / API | 설명 |
|------------|------|
| `rosbag_content` | bag 메타·토픽·메시지 캐시 |
| `rosbag::Bag`, `rosbag::View` | ROS bag 읽기 |
| `draw_bag_content()` | ImGui로 토픽·메시지 목록 |
| `bag.instanciate_and_cache(m, count)` | 메시지 내용 문자열화 |
| `file_dialog_open()` | bag 파일 선택 |
| `draw_menu_bar()`, `draw_files_left_panel()` | UI 패널 |
| bag 복사/필터 | `bag_out.write()` — 토픽 필터 export |

---

## rs-benchmark

**소스:** `tools/benchmark/rs-benchmark.cpp`  
**중요 기능:** CPU vs GPU processing block 성능 벤치마크

| 함수 / API | 설명 |
|------------|------|
| `suite` / `test` | 벤치마크 테스트 단위 |
| `processing_blocks` suite | `rs2::align`, `colorizer`, `pointcloud`, `decimation` 등 CPU |
| `gl_blocks` suite | `rs2::gl::align`, `gl::colorizer`, `gl::pointcloud` 등 GPU |
| `gl::init_processing(win, true)` | GL GPU 경로 |
| `REGISTER_TEST` 매크로 | 각 블록별 프레임 처리 시간 측정 |
| `pipeline.start(cfg)` | depth + color/IR 벤치 스트림 |
| `get_cpu()` | CPU 모델 문자열 |

---

## rs-dds-sniffer

**소스:** `tools/dds/dds-sniffer/rs-dds-sniffer.cpp`  
**빌드:** `BUILD_WITH_DDS=ON`  
**중요 기능:** DDS 도메인 트래픽 스니핑

| 함수 / API | 설명 |
|------------|------|
| FastDDS `DomainParticipant` | DDS participant 생성 |
| `DataReader`, `DataReaderListener` | 토픽 구독·콜백 |
| `realdds::dds_guid`, `print_guid()` | GUID 표시 |
| `realdds::dds-serialization` | 메시지 역직렬화 |
| `DynamicDataFactory`, `DynamicDataHelper` | 동적 타입 덤프 |
| TCLAP | domain-id 등 CLI |

---

## rs-dds-adapter

**소스:** `tools/dds/dds-adapter/rs-dds-adapter.cpp`  
**중요 기능:** USB RealSense → DDS 네트워크 장치 브릿지

| 함수 / API | 설명 |
|------------|------|
| `dds_participant::init(domain, ...)` | DDS participant |
| `realdds::dds_publisher` | DDS publisher |
| `topics::ros2::participant_entities_info_msg` | ROS2 discovery 토픽 |
| `rs2::context`, `query_devices()` | USB 장치 감지 |
| USB→DDS 브릿지 루프 | 장치 프레임을 DDS writer로 publish |

---

## rs-dds-config

**소스:** `tools/dds/dds-config/rs-dds-config.cpp`  
**중요 기능:** Ethernet/DDS 카메라 네트워크·DDS 설정 CLI

| 함수 / API | 설명 |
|------------|------|
| `rs2::cli_no_dds` | DDS 비활성 CLI 파서 |
| `get_device_by_sn(ctx, sn)` | 시리얼로 장치 선택 |
| `dev.as<rs2::eth_config_device>()` | Ethernet 설정 |
| DHCP/IP/mask/gateway CLI | `set_dhcp_config`, `set_ip_address` 등 |
| `domain-id`, `sdk-domain-id` | DDS domain 설정·SDK 기본값 저장 |
| `usb-first` / `eth-first` / `dynamic-priority` | 링크 우선순위 |
| `factory-reset`, `golden` | golden 값 vs 현재 설정 비교·복원 |
| `dev.hardware_reset()` | 설정 후 HW reset (`--reset`) |

---

*DDS 도구 3종: `BUILD_WITH_DDS=ON` 필요*
