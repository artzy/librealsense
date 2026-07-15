# rs-enumerate-devices 도구

## 목적
`rs-enumerate-devices`는 RealSense 장치 정보를 출력하는 콘솔 애플리케이션입니다.

## 사용법
`librealsense`를 설치한 뒤 `rs-enumerate-devices`를 실행합니다.
D415 카메라에서 `-S` 옵션을 사용한 출력 예시는 다음과 같습니다.

```
Device Name                   Serial Number       Firmware Version
Intel RealSense D415          725112060411        05.12.02.100
Device info:
    Name                          :     Intel RealSense D415
    Serial Number                 :     725112060411
    Firmware Version              :     05.12.02.100
    Physical Port                 :     \\?\usb#vid_8086&pid_0ad3&mi_00#6&2a371216&0&0000#{e5323777-f976-4f5b-9b55-b94699c46e44}\global
    Debug Op Code                 :     15
    Advanced Mode                 :     YES
    Product Id                    :     0AD3
    Camera Locked                 :     NO
    Usb Type Descriptor           :     3.2
    Product Line                  :     D400
    Asic Serial Number            :     012345678901
    Firmware Update Id            :     012345678901

```

## 명령줄 매개변수

|플래그   |설명   |
|---|---|
|`-s`,`--short`|연결된 각 장치에 대해 한 줄 정보를 출력|
|`-S`,`--compact`|`-s`를 확장하여 장치별 짧은 요약을 제공|
|`-o`,`--option`|지원하는 장치 컨트롤, 옵션, 스트리밍 모드를 나열|
|`-c`,`--calib_data`|캘리브레이션(Intrinsic/Extrinsic) 및 스트리밍 모드 정보를 제공|
|`-p <path>`,`--playback_device <path>`|ROSBag 녹화 파일에 포함된 스트림을 나열|
|`-d`,`--defaults`|기본 스트림 설정을 표시|
|`--dds-domain <0-232>`|DDS 도메인 ID 설정 (기본값 0)|
|`-v`,`--verbose`|추가 정보를 표시|
|`--debug`|LibRS 디버그 로그를 켭니다|
|`--`,`--ignore_rest`|이 플래그 뒤에 오는 나머지 레이블 인자를 무시|
|`--format <raw/basic/FULL>`|사용할 'format-conversion'을 선택|
|`--sw-only`|소프트웨어 장치만 표시: playback, DDS 등 — USB/HID 등은 제외|
| 없음| 기본 모드. `-S`에 더해 지원하는 모든 스트리밍 프로파일 목록을 출력|

`-o`, `-c`, `-p` 옵션은 서로 더해 쓸 수 있습니다. 예:
`rs-enumerate-devices -o -c -p rosbag.rec` — 실시간 카메라와 사전 녹화된 `rosbag.rec` 파일 모두에 대해 카메라 정보, 스트리밍 모드, 지원 옵션, 캘리브레이션 데이터를 출력합니다.

`-S`, `-s`는 제한적인 옵션이라 `-o`, `-c`와는 함께 쓸 수 없지만,
`-p <file_name>`과는 함께 사용할 수 있습니다.
