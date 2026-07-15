@echo off
setlocal EnableDelayedExpansion
set ROOT=%~dp0..
set BIN=%ROOT%\build\Release
set PY311=C:\Users\PM\AppData\Local\Programs\Python\Python311\python.exe

if not exist "%BIN%\realsense2.dll" (
    echo [ERROR] 빌드가 없습니다. 먼저 build-d415-examples.bat 를 실행하세요.
    exit /b 1
)

set OPENCV_BIN=D:\Dev2019\opencv-4.13.0\x64\vc16\bin
set PATH=%OPENCV_BIN%;D:\Dev2019\opencv-4.13.0\bin;%PATH%

cd /d "%BIN%"

:menu
echo.
echo ===== D415 예제 실행 메뉴 =====
echo  [기본]
echo   1. rs-enumerate-devices   (연결 장치 확인)
echo   2. rs-hello-realsense     (depth 콘솔)
echo   3. rs-capture             (depth+color GUI)
echo   4. rs-align               (depth-color 정렬)
echo   5. rs-post-processing     (후처리 필터)
echo   6. rs-measure             (3D 거리 측정)
echo   7. rs-multicam            (다중 카메라)
echo  [3D / Viewer]
echo   8. rs-pointcloud          (포인트클라우드 3D 뷰)
echo   9. rs-gl                  (GPU 포인트클라우드)
echo  10. realsense-viewer       (공식 뷰어)
echo  11. rs-depth-quality       (깊이 품질 측정)
echo  [기타]
echo  12. Python Advanced Mode
echo   0. 종료
echo.
set /p CHOICE=선택 (0-12):

if "%CHOICE%"=="0" exit /b 0
if "%CHOICE%"=="1" rs-enumerate-devices.exe -S & goto menu
if "%CHOICE%"=="2" rs-hello-realsense.exe & goto menu
if "%CHOICE%"=="3" rs-capture.exe & goto menu
if "%CHOICE%"=="4" rs-align.exe & goto menu
if "%CHOICE%"=="5" rs-post-processing.exe & goto menu
if "%CHOICE%"=="6" rs-measure.exe & goto menu
if "%CHOICE%"=="7" rs-multicam.exe & goto menu
if "%CHOICE%"=="8" rs-pointcloud.exe & goto menu
if "%CHOICE%"=="9" rs-gl.exe & goto menu
if "%CHOICE%"=="10" start realsense-viewer.exe & goto menu
if "%CHOICE%"=="11" start rs-depth-quality.exe & goto menu
if "%CHOICE%"=="12" goto python_adv

echo 잘못된 선택입니다.
goto menu

:python_adv
if not exist "%PY311%" (
    echo [ERROR] Python 3.11 을 찾을 수 없습니다: %PY311%
    goto menu
)
set PYTHONPATH=%BIN%
"%PY311%" "%ROOT%\wrappers\python\examples\python-rs400-advanced-mode-example.py"
goto menu
