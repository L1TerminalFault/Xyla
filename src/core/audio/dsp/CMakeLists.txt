# ==============================================================================
# src/core/audio/dsp/CMakeLists.txt
# ==============================================================================
add_library(xyla_audio_dsp INTERFACE)

target_include_directories(xyla_audio_dsp INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../../..>
)

target_link_libraries(xyla_audio_dsp INTERFACE
    xyla_audio_types
)
