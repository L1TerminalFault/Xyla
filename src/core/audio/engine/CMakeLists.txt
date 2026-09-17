# ==============================================================================
# src/core/audio/engine/CMakeLists.txt
# ==============================================================================
add_library(xyla_audio_engine STATIC
    audioEngine.cpp
)

target_include_directories(xyla_audio_engine PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../../..>
)

target_link_libraries(xyla_audio_engine PUBLIC
    xyla_audio_graph
    xyla_audio_hal
    xyla_audio_timeline
)
