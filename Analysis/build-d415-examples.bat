@echo off
setlocal
set ROOT=%~dp0..
set BUILD=%ROOT%\build

echo === librealsense D415 예제 빌드 ===
if not exist "%BUILD%" mkdir "%BUILD%"

cmake -S "%ROOT%" -B "%BUILD%" -G "Visual Studio 17 2022" -A x64 ^
    -DBUILD_PYTHON_BINDINGS=ON ^
    -DBUILD_CV_EXAMPLES=ON ^
    -DBUILD_CV_KINFU_EXAMPLE=OFF ^
    -DOpenCV_DIR=D:/Dev2019/opencv-4.13.0/x64/vc16/lib
if errorlevel 1 exit /b 1

cmake --build "%BUILD%" --config Release --parallel --target ALL_BUILD

if errorlevel 1 exit /b 1

echo.
echo === 빌드 완료 ===
echo 실행 파일: %BUILD%\Release\
dir /b "%BUILD%\Release\rs-*.exe"
echo Python: %BUILD%\Release\pyrealsense2.cp311-win_amd64.pyd
endlocal
