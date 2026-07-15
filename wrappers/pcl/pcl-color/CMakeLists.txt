cmake_minimum_required(VERSION 3.10)

project(RealSensePCLColorExample)

add_executable (rs-pcl-color rs-pcl-color.cpp)
set_property(TARGET rs-pcl-color PROPERTY CXX_STANDARD 11)
find_package(PCL REQUIRED COMPONENTS common io visualization)
find_package(OpenCV REQUIRED)

# Prefer the configured PCL install (e.g. PCL 1.12.1) over VCPKG_ROOT auto-includes.
target_include_directories(rs-pcl-color BEFORE PRIVATE
    ${PCL_INCLUDE_DIRS}
    ${OpenCV_INCLUDE_DIRS}
)
target_link_directories(rs-pcl-color PRIVATE ${PCL_LIBRARY_DIRS})
target_compile_definitions(rs-pcl-color PRIVATE ${PCL_DEFINITIONS})
target_link_libraries(rs-pcl-color PRIVATE ${DEPENDENCIES} ${PCL_LIBRARIES} ${OpenCV_LIBS})

if(MSVC AND DEFINED ENV{VCPKG_ROOT})
    set_target_properties(rs-pcl-color PROPERTIES VS_GLOBAL_VcpkgEnabled "false")
endif()

if(MSVC AND CMAKE_PREFIX_PATH MATCHES "vcpkg")
    target_include_directories(rs-pcl-color PUBLIC "${CMAKE_SOURCE_DIR}/third-party/glfw/include")
elseif(MSVC)
    target_link_libraries(rs-pcl-color PRIVATE "${CMAKE_BINARY_DIR}/$<CONFIG>/glfw3.lib")
    target_include_directories(rs-pcl-color PUBLIC "${CMAKE_SOURCE_DIR}/third-party/glfw/include")
elseif(NOT glfw3_DIR)
    target_include_directories(rs-pcl-color PUBLIC "${PROJECT_SOURCE_DIR}/third-party/glfw/include")
    target_link_directories(rs-pcl-color PUBLIC "${CMAKE_BINARY_DIR}/third-party/glfw/src/${CMAKE_BUILD_TYPE}")
endif()

set_target_properties (rs-pcl-color PROPERTIES
    FOLDER "Examples/PCL"
)

install(
    TARGETS

    rs-pcl-color

    RUNTIME DESTINATION
    ${CMAKE_INSTALL_PREFIX}/bin
)
