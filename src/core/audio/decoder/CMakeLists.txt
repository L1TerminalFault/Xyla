# ==============================================================================
# src/core/audio/decoder/CMakeLists.txt
# Audio Decoder Library (FFmpeg / libswresample integration)
# ==============================================================================

find_package(PkgConfig QUIET)
if(PKG_CONFIG_FOUND)
  pkg_check_modules(LIBAV QUIET
        libavcodec
        libavformat
        libswresample
        libavutil
    )
endif()

if(LIBAV_FOUND)
  add_library(xyla_audio_decoder STATIC
        audioDecoder.cpp
    )

  target_include_directories(xyla_audio_decoder PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../../..>
    )

  target_include_directories(xyla_audio_decoder PRIVATE
        ${LIBAV_INCLUDE_DIRS}
    )

  target_link_libraries(xyla_audio_decoder PUBLIC
        xyla_audio_types
    )

  target_link_libraries(xyla_audio_decoder PRIVATE
        ${LIBAV_LIBRARIES}
    )

  target_compile_definitions(xyla_audio_decoder PUBLIC
        XYLA_HAS_FFMPEG=1
    )

  target_compile_features(xyla_audio_decoder PUBLIC cxx_std_20)

  # message(STATUS "xyla_audio_decoder: Enabled with FFmpeg (${LIBAV_VERSION})")
else()
  # Graceful fallback: Header-only stub so downstream targets compile even without FFmpeg
  add_library(xyla_audio_decoder INTERFACE)

  target_include_directories(xyla_audio_decoder INTERFACE
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../../..>
    )

  target_link_libraries(xyla_audio_decoder INTERFACE
        xyla_audio_types
    )

  target_compile_definitions(xyla_audio_decoder INTERFACE
        XYLA_HAS_FFMPEG=0
    )

  target_compile_features(xyla_audio_decoder INTERFACE cxx_std_20)

  message(WARNING "xyla_audio_decoder: FFmpeg libraries not found (libavcodec, libavformat, libswresample). Decoding will be disabled.")
endif()
