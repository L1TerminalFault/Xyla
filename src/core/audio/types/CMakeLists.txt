# ==============================================================================
# src/core/audio/types/CMakeLists.txt
# Header-only core audio types and buffer pool
# ==============================================================================

add_library(xyla_audio_types INTERFACE)

target_include_directories(xyla_audio_types INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../../..>
)

target_compile_features(xyla_audio_types INTERFACE cxx_std_20)
