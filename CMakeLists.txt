cmake_minimum_required(VERSION 3.20)
project(Xyla VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

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

target_include_directories(Xyla PRIVATE
    src
    "/usr/include/kddockwidgets-qt6"
    ${Vulkan_INCLUDE_DIRS}
    ${PIPEWIRE_INCLUDE_DIRS}
)

target_compile_definitions(Xyla PRIVATE KDDW_FRONTEND_QT KDDW_FRONTEND_QTQUICK)

if (TARGET KDDockWidgets::kddockwidgets-qt6)
  set(KDDW_LIB KDDockWidgets::kddockwidgets-qt6)
elseif (TARGET KDDockWidgets-qt6::kddockwidgets-qt6)
  set(KDDW_LIB KDDockWidgets-qt6::kddockwidgets-qt6)
else()
  set(KDDW_LIB kddockwidgets-qt6)
endif()

target_link_libraries(Xyla PRIVATE
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
