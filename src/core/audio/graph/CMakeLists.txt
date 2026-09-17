# ==============================================================================
# src/core/audio/graph/CMakeLists.txt
# ==============================================================================
add_library(xyla_audio_graph STATIC
    audioGraph.cpp
)

target_include_directories(xyla_audio_graph PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../../..>
)

target_link_libraries(xyla_audio_graph PUBLIC
    xyla_audio_nodes
)
