cmake_minimum_required(VERSION 3.10)

project(RealSenseKinfuExample)

find_package(OpenGL REQUIRED)

# KinFu needs OpenCV contrib rgbd (kinfu.hpp). Default: opencv-4.9.0 on this machine.
set(KINFU_OPENCV_ROOT "D:/Dev2019/opencv-4.9.0" CACHE PATH "OpenCV install with rgbd/kinfu module")

if(KINFU_OPENCV_ROOT MATCHES "4\\.13")
    set(_kinfu_cv_suffix "4130")
elseif(KINFU_OPENCV_ROOT MATCHES "4\\.9")
    set(_kinfu_cv_suffix "490")
else()
    set(_kinfu_cv_suffix "490")
endif()

set(KINFU_OPENCV_LIB "${KINFU_OPENCV_ROOT}/x64/vc16/lib")
set(KINFU_OPENCV_BIN "${KINFU_OPENCV_ROOT}/x64/vc16/bin")
if(NOT EXISTS "${KINFU_OPENCV_LIB}/opencv_rgbd${_kinfu_cv_suffix}.lib")
    set(KINFU_OPENCV_LIB "${KINFU_OPENCV_ROOT}/x64/vc17/lib")
    set(KINFU_OPENCV_BIN "${KINFU_OPENCV_ROOT}/x64/vc17/bin")
endif()

file(GLOB IMGUI_SOURCES "../../../third-party/imgui/*.cpp")

add_executable(rs-kinfu rs-kinfu.cpp ../../../examples/example.hpp ${IMGUI_SOURCES})
set_property(TARGET rs-kinfu PROPERTY CXX_STANDARD 11)
include_directories(../../../examples ../../../third-party/imgui "${KINFU_OPENCV_ROOT}/include")

target_link_libraries(rs-kinfu
    PRIVATE
        realsense2
        glfw
        OpenGL::GL
        "${KINFU_OPENCV_LIB}/opencv_rgbd${_kinfu_cv_suffix}.lib"
        "${KINFU_OPENCV_LIB}/opencv_calib3d${_kinfu_cv_suffix}.lib"
        "${KINFU_OPENCV_LIB}/opencv_features2d${_kinfu_cv_suffix}.lib"
        "${KINFU_OPENCV_LIB}/opencv_flann${_kinfu_cv_suffix}.lib"
        "${KINFU_OPENCV_LIB}/opencv_imgproc${_kinfu_cv_suffix}.lib"
        "${KINFU_OPENCV_LIB}/opencv_core${_kinfu_cv_suffix}.lib"
)

if(MSVC)
    # vcpkg integration may inject glfw3dll.lib via *.lib wildcard; librealsense uses static glfw3.
    target_link_options(rs-kinfu PRIVATE "/NODEFAULTLIB:glfw3dll.lib")
endif()

set_target_properties(rs-kinfu PROPERTIES FOLDER "Examples/OpenCV")

add_custom_command(TARGET rs-kinfu POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${KINFU_OPENCV_BIN}/opencv_core${_kinfu_cv_suffix}.dll"
        "${KINFU_OPENCV_BIN}/opencv_imgproc${_kinfu_cv_suffix}.dll"
        "${KINFU_OPENCV_BIN}/opencv_flann${_kinfu_cv_suffix}.dll"
        "${KINFU_OPENCV_BIN}/opencv_features2d${_kinfu_cv_suffix}.dll"
        "${KINFU_OPENCV_BIN}/opencv_calib3d${_kinfu_cv_suffix}.dll"
        "${KINFU_OPENCV_BIN}/opencv_rgbd${_kinfu_cv_suffix}.dll"
        "$<TARGET_FILE_DIR:rs-kinfu>"
)

install(
    TARGETS rs-kinfu
    RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX}/bin
)
