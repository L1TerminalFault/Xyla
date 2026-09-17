# ==============================================================================
# src/core/audio/timeline/CMakeLists.txt
# ==============================================================================
set(TIMELINE_SRCS
    # audioClipBuffer.cpp
    waveformGenerator.cpp
)

# Optional audioDecoder if FFmpeg is installed
if(LIBAV_FOUND AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../decoder/audioDecoder.cpp")
  list(APPEND TIMELINE_SRCS "${CMAKE_CURRENT_SOURCE_DIR}/../decoder/audioDecoder.cpp")
endif()

add_library(xyla_audio_timeline STATIC
    ${TIMELINE_SRCS}
)

target_include_directories(xyla_audio_timeline PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../decoder>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../../..>
)

target_link_libraries(xyla_audio_timeline PUBLIC
    xyla_audio_types
    xyla_audio_dsp
    xyla_audio_nodes
)

if(LIBAV_FOUND)
  target_include_directories(xyla_audio_timeline PRIVATE ${LIBAV_INCLUDE_DIRS})
  target_link_libraries(xyla_audio_timeline PRIVATE ${LIBAV_LIBRARIES})
  target_compile_definitions(xyla_audio_timeline PUBLIC XYLA_HAS_FFMPEG=1)
endif()
