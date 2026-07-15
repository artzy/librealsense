cmake_minimum_required(VERSION 3.10)

project(RealSensePCLExample)

file(GLOB IMGUI_SOURCES "../../../third-party/imgui/*.cpp")

add_executable(rs-pcl rs-pcl.cpp ../../../examples/example.hpp ${IMGUI_SOURCES})
set_property(TARGET rs-pcl PROPERTY CXX_STANDARD 11)

# Prefer the configured PCL install (e.g. PCL 1.12.1) over VCPKG_ROOT auto-includes.
target_include_directories(rs-pcl BEFORE PRIVATE
    ${PCL_INCLUDE_DIRS}
    ${CMAKE_SOURCE_DIR}/examples
    ${CMAKE_SOURCE_DIR}/third-party/imgui
)
target_link_libraries(rs-pcl PRIVATE ${DEPENDENCIES})

if(MSVC AND DEFINED ENV{VCPKG_ROOT})
    set_target_properties(rs-pcl PROPERTIES VS_GLOBAL_VcpkgEnabled "false")
endif()

if(MSVC AND CMAKE_PREFIX_PATH MATCHES "vcpkg")
    # vcpkg adds lib/*.lib (includes glfw3dll.lib); do not also link static glfw3.
    target_include_directories(rs-pcl PUBLIC "${CMAKE_SOURCE_DIR}/third-party/glfw/include")
elseif(MSVC)
    target_link_libraries(rs-pcl PRIVATE "${CMAKE_BINARY_DIR}/$<CONFIG>/glfw3.lib")
    target_include_directories(rs-pcl PUBLIC "${CMAKE_SOURCE_DIR}/third-party/glfw/include")
elseif(NOT glfw3_DIR)
    target_include_directories(rs-pcl PUBLIC "${PROJECT_SOURCE_DIR}/third-party/glfw/include")
    target_link_directories(rs-pcl PUBLIC "${CMAKE_BINARY_DIR}/third-party/glfw/src/${CMAKE_BUILD_TYPE}")
endif()

set_target_properties (rs-pcl PROPERTIES
    FOLDER "Examples/PCL"
)

install(
    TARGETS

    rs-pcl

    RUNTIME DESTINATION
    ${CMAKE_INSTALL_PREFIX}/bin
)
