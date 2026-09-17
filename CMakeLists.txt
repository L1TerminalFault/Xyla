cmake_minimum_required(VERSION 3.20)
project(Xyla VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# Search path for custom KDDockWidgets build
list(APPEND CMAKE_PREFIX_PATH "/usr/local/KDAB/KDDockWidgets-2.5.0")

find_package(Qt6 REQUIRED COMPONENTS Core Quick QuickControls2 Gui Svg Core5Compat Qml)
find_package(KDDockWidgets-qt6 REQUIRED)
find_package(Vulkan REQUIRED)
find_package(PkgConfig REQUIRED)

pkg_check_modules(AVFORMAT REQUIRED IMPORTED_TARGET libavformat)
pkg_check_modules(SWRESAMPLE REQUIRED IMPORTED_TARGET libswresample)
pkg_check_modules(AVCODEC REQUIRED IMPORTED_TARGET libavcodec)
pkg_check_modules(AVUTIL REQUIRED IMPORTED_TARGET libavutil)
pkg_check_modules(SWSCALE REQUIRED IMPORTED_TARGET libswscale)
pkg_check_modules(PIPEWIRE REQUIRED IMPORTED_TARGET libpipewire-0.3)

find_library(SHADERC_LIB NAMES shaderc_shared shaderc_combined shaderc)
if(NOT SHADERC_LIB)
  pkg_check_modules(SHADERC REQUIRED IMPORTED_TARGET shaderc)
  set(SHADERC_LIB PkgConfig::SHADERC)
endif()

qt_policy(SET QTP0004 NEW)

# ==============================================================================
# Modular Subsystems Architecture
# ==============================================================================
# Decomposes core subsystems into standalone targets.
# Provides xyla_audio_core (pure C++20 DSP with zero GPU/UI dependencies).
add_subdirectory(src/core/audio)

# ==============================================================================
# Collect Production Sources & Assets
# ==============================================================================
file(GLOB_RECURSE CPP_SOURCES CONFIGURE_DEPENDS
    "src/*.cpp"
    "src/*.hpp"
    "src/*.h"
)

file(GLOB_RECURSE QML_SOURCES CONFIGURE_DEPENDS
    RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
    "src/qml/*.qml"
)

file(GLOB_RECURSE ABSOLUTE_ASSETS CONFIGURE_DEPENDS
    "src/qml/assets/*"
)

# ==============================================================================
# Application Target: Xyla
# ==============================================================================
add_executable(Xyla ${CPP_SOURCES})

qt_add_qml_module(Xyla
    URI "Xyla"
    VERSION 1.0
    RESOURCE_PREFIX "/"
    OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml_imports"
    NO_PLUGIN
    QML_FILES
        ${QML_SOURCES}
)

qt_add_resources(Xyla "app_assets"
    PREFIX "/"
    BASE "src/qml"
    FILES ${ABSOLUTE_ASSETS}
)

# Resolve KDDockWidgets target or library path
if (TARGET KDAB::kddockwidgets)
  set(KDDW_LIB KDAB::kddockwidgets)
elseif (TARGET KDAB::kddockwidgets-qt6)
  set(KDDW_LIB KDAB::kddockwidgets-qt6)
elseif (TARGET KDDockWidgets::kddockwidgets-qt6)
  set(KDDW_LIB KDDockWidgets::kddockwidgets-qt6)
elseif (TARGET KDDockWidgets-qt6::kddockwidgets-qt6)
  set(KDDW_LIB KDDockWidgets-qt6::kddockwidgets-qt6)
else()
  link_directories(
      # "/usr/local/KDAB/KDDockWidgets-2.5.0/lib"
      # "/usr/local/KDAB/KDDockWidgets-2.5.0/lib64"
  )
  set(KDDW_LIB kddockwidgets-qt6)
endif()

target_include_directories(Xyla PRIVATE
    src
    # "/usr/local/KDAB/KDDockWidgets-2.5.0/include"
    # "/usr/local/KDAB/KDDockWidgets-2.5.0/include/kddockwidgets-qt6"
    ${Vulkan_INCLUDE_DIRS}
    ${PIPEWIRE_INCLUDE_DIRS}
)

target_compile_definitions(Xyla PRIVATE
    KDDW_FRONTEND_QT
    KDDW_FRONTEND_QTQUICK
    PROJECT_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
)

target_link_libraries(Xyla PRIVATE
    xyla_audio    # <-- Modular audio subsystem target
    Qt6::Core
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Gui
    Qt6::Svg
    Qt6::Core5Compat
    ${KDDW_LIB}
    Vulkan::Vulkan
    ${SHADERC_LIB}
    PkgConfig::AVFORMAT
    PkgConfig::AVCODEC
    PkgConfig::AVUTIL
    PkgConfig::SWSCALE
    PkgConfig::PIPEWIRE
    PkgConfig::SWRESAMPLE
)

# ==============================================================================
# Unit Tests Configuration (/tests folder located alongside /src)
# ==============================================================================
include(CTest) # Standard CMake testing switch (BUILD_TESTING, default ON)

if(BUILD_TESTING)
  enable_testing()

  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests/CMakeLists.txt")
    # Subdirectory layout: delegates building tests to tests/CMakeLists.txt
    add_subdirectory(tests)
  else()
    # Direct fallback target: builds standalone tests linking xyla_audio_core
    find_package(GTest QUIET)
    if(NOT GTest_FOUND)
      include(FetchContent)
      FetchContent_Declare(
                googletest
                URL https://github.com/google/googletest/archive/refs/tags/v1.14.0.zip
            )
      set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
      FetchContent_MakeAvailable(googletest)
    endif()

    # 1. Collect ONLY test suite files in /tests
    file(GLOB_RECURSE TEST_SOURCES CONFIGURE_DEPENDS
            "tests/*.cpp"
            "tests/*.hpp"
            "tests/*.h"
        )

    # 2. Build standalone test runner
    # NOTE: Does NOT glob or compile shaderCompiler.cpp or videoFrameCache.cpp!
    add_executable(xyla_unit_tests
            ${TEST_SOURCES}
        )

    target_include_directories(xyla_unit_tests PRIVATE
            tests
        )

    target_compile_features(xyla_unit_tests PRIVATE cxx_std_20)

    # Link cleanly to xyla_audio_core + GoogleTest without Vulkan or Shaderc
    target_link_libraries(xyla_unit_tests PRIVATE
            xyla_audio_core
            GTest::gtest_main
            GTest::gmock
            pthread
        )

    include(GoogleTest)
    gtest_discover_tests(xyla_unit_tests)
  endif()
endif()
