# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(quickjpeg_library VERSION 0.0.1 LANGUAGES C)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_library(quickjpeg SHARED
  "quickjpeg.c"
  "log.c"
)

set(CMAKE_CXX_FLAGS "-Wall -Wextra")
target_compile_options(quickjpeg PUBLIC "-O3")
message("BUILD TYPE: ${CMAKE_BUILD_TYPE}")

set_target_properties(quickjpeg PROPERTIES
  PUBLIC_HEADER quickjpeg.h
  OUTPUT_NAME "quickjpeg"
)

include(ExternalProject)

include(FetchContent)
FetchContent_Declare(
  libyuv 
  GIT_REPOSITORY https://chromium.googlesource.com/libyuv/libyuv
  GIT_TAG        main 
)

FetchContent_MakeAvailable(libyuv)

if(ANDROID)
ExternalProject_Add(libjpegturbo
        CMAKE_ARGS
            -DANDROID_ABI=${ANDROID_ABI}
            -DANDROID_PLATFORM=${ANDROID_PLATFORM}
            -DANDROID_TOOLCHAIN=${ANDROID_TOOLCHAIN}
            -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
            -DENABLE_SHARED=OFF
            -DENABLE_STATIC=ON
            -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
            -DWITH_JPEG8=OFF
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON
        GIT_REPOSITORY https://github.com/libjpeg-turbo/libjpeg-turbo.git
        GIT_TAG        3.1.1
        BUILD_BYPRODUCTS <INSTALL_DIR>/lib/${CMAKE_STATIC_LIBRARY_PREFIX}turbojpeg${CMAKE_STATIC_LIBRARY_SUFFIX}
)

ExternalProject_Get_Property(libjpegturbo install_dir)
set(LIBJPEG_TURBO_INCLUDE_DIR "${install_dir}/include")
set(LIBJPEG_TURBO_LIBRARY_DIR "${install_dir}/lib")
set(LIBJPEG_TURBO_LIBRARY "${install_dir}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}turbojpeg${CMAKE_STATIC_LIBRARY_SUFFIX}")

add_library(libjpeg-turbo STATIC IMPORTED)

set_target_properties(libjpeg-turbo PROPERTIES
    IMPORTED_LOCATION             "${LIBJPEG_TURBO_LIBRARY_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}turbojpeg${CMAKE_STATIC_LIBRARY_SUFFIX}"
    INTERFACE_INCLUDE_DIRECTORIES "${LIBJPEG_TURBO_INCLUDE_DIR}"
)

add_dependencies(quickjpeg libjpegturbo)	

target_compile_definitions(quickjpeg PUBLIC DART_SHARED_LIB)

target_include_directories(quickjpeg PUBLIC ${LIBJPEG_TURBO_INCLUDE_DIR})
target_link_libraries(quickjpeg PUBLIC ${LIBJPEG_TURBO_LIBRARY})
find_library(
        log-lib
        log
)

target_link_libraries(quickjpeg PUBLIC ${log-lib})
elseif(LINUX)
add_executable("test"
  "quickjpeg.c"
  "test.c"
  "log.c"
)

find_package(PkgConfig)
pkg_check_modules(turbojpeg REQUIRED libturbojpeg)
target_link_libraries(quickjpeg PUBLIC turbojpeg)
target_link_libraries("test" PUBLIC turbojpeg)
target_link_libraries("test" PUBLIC yuv)
target_link_libraries("test" PUBLIC m)
target_include_directories("test" PUBLIC "${libyuv_SOURCE_DIR}/include/")
endif()
target_include_directories("quickjpeg" PUBLIC "${libyuv_SOURCE_DIR}/include/")
target_link_libraries(quickjpeg PUBLIC yuv)
target_link_libraries(quickjpeg PUBLIC m)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(quickjpeg PRIVATE "-Wl,-z,max-page-size=16384")
endif()
