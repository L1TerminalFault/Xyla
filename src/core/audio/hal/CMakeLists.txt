# ==============================================================================
# src/core/audio/hal/CMakeLists.txt
# ==============================================================================
find_package(Qt6 REQUIRED COMPONENTS Core) # <-- Add this

set(HAL_SRCS
    dummyAudioBackend.hpp
    pipewireUtils.hpp
)

if(PIPEWIRE_FOUND)
  list(APPEND HAL_SRCS pipewireAudioBackend.cpp)
endif()

add_library(xyla_audio_hal STATIC
    ${HAL_SRCS}
)

target_include_directories(xyla_audio_hal PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../../..>
)

target_link_libraries(xyla_audio_hal PUBLIC
    xyla_audio_types
    Qt6::Core    # <-- Add this so <QtLogging> and <QDebug> are found
)

if(PIPEWIRE_FOUND)
  target_include_directories(xyla_audio_hal PRIVATE ${PIPEWIRE_INCLUDE_DIRS})
  target_link_libraries(xyla_audio_hal PRIVATE ${PIPEWIRE_LIBRARIES})
  target_compile_definitions(xyla_audio_hal PUBLIC XYLA_HAS_PIPEWIRE=1)
endif()
