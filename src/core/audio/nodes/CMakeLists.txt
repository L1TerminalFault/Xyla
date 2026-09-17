# ==============================================================================
# src/core/audio/nodes/CMakeLists.txt
# ==============================================================================
add_library(xyla_audio_nodes STATIC
    # audioNode.cpp
    masterOutputNode.cpp
    mixerTrackNode.cpp
)

target_include_directories(xyla_audio_nodes PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../../..>
)

target_link_libraries(xyla_audio_nodes PUBLIC
    xyla_audio_types
    xyla_audio_dsp
)
