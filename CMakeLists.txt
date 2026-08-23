cmake_minimum_required(VERSION 3.20)
project(Xyla VERSION 0.1.0 LANGUAGES C CXX)

# Standard C++23 configuration
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# 1. Locate Qt6, KDDockWidgets, and PkgConfig
find_package(Qt6 REQUIRED COMPONENTS Core Quick QuickControls2 Gui Svg Core5Compat Qml)
find_package(KDDockWidgets-qt6 REQUIRED)
find_package(PkgConfig REQUIRED)

# Locate FFmpeg Libraries
pkg_check_modules(AVFORMAT REQUIRED IMPORTED_TARGET libavformat)
pkg_check_modules(AVCODEC REQUIRED IMPORTED_TARGET libavcodec)
pkg_check_modules(AVUTIL REQUIRED IMPORTED_TARGET libavutil)
pkg_check_modules(SWSCALE REQUIRED IMPORTED_TARGET libswscale)

qt_policy(SET QTP0004 NEW)

# 2. Glob C++ Files
file(GLOB_RECURSE CPP_SOURCES CONFIGURE_DEPENDS
    "src/*.cpp"
    "src/*.hpp"
    "src/*.h"
)

# 3. Glob QML Files
file(GLOB_RECURSE QML_SOURCES CONFIGURE_DEPENDS
    RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
    "src/qml/*.qml"
)

# 4. Glob Assets
file(GLOB_RECURSE ABSOLUTE_ASSETS CONFIGURE_DEPENDS
    "src/qml/assets/*"
)

# 5. Define Executable Target
add_executable(Xyla ${CPP_SOURCES})

# 6. Configure QML Module
qt_add_qml_module(Xyla
    URI "Xyla"
    VERSION 1.0
    RESOURCE_PREFIX "/"
    OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml_imports"
    NO_PLUGIN
    QML_FILES
        ${QML_SOURCES}
)

# 7. Assets Resource Management
qt_add_resources(Xyla "app_assets"
    PREFIX "/"
    BASE "src/qml"
    FILES ${ABSOLUTE_ASSETS}
)

# 8. Include and Linkage
target_include_directories(Xyla PRIVATE
    src
    "/usr/include/kddockwidgets-qt6"
)

target_compile_definitions(Xyla PRIVATE KDDW_FRONTEND_QT KDDW_FRONTEND_QTQUICK)

# FIX: Link against the official CMake imported target namespace
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
    PkgConfig::AVFORMAT
    PkgConfig::AVCODEC
    PkgConfig::AVUTIL
    PkgConfig::SWSCALE
)
