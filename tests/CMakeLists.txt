# ==============================================================================
# tests/CMakeLists.txt
# Generates a standalone executable for EVERY test .cpp file automatically
# ==============================================================================

if(POLICY CMP0135)
  cmake_policy(SET CMP0135 NEW)
endif()

find_package(GTest QUIET)
if(NOT GTest_FOUND)
  include(FetchContent)
  FetchContent_Declare(
      googletest
      URL https://github.com/google/googletest/archive/refs/tags/v1.14.0.zip
  )
  set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
  FetchContent_MakeAvailable(googletest)
endif()

include(GoogleTest)

# 1. Automatically find all test source files
file(GLOB_RECURSE TEST_SOURCES CONFIGURE_DEPENDS
    "core/audio/*.cpp"
    "core/audio/**/*.cpp"
)

# 2. Define common link dependencies for all audio test runners
set(AUDIO_TEST_DEPS
    xyla_audio_types
    xyla_audio_dsp
    xyla_audio_nodes
    xyla_audio_graph
    xyla_audio_hal
    xyla_audio_timeline
    xyla_audio_engine
    GTest::gtest_main
    GTest::gmock
    pthread
)

# 3. Create a custom meta-target so you can run: cmake --build build --target check_all_audio
add_custom_target(check_all_audio
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure
    COMMENT "Running all granular unit tests..."
)

# 4. Loop through each file and dynamically create a standalone target
foreach(TEST_SRC ${TEST_SOURCES})
  # Extract file name without extension (e.g. "core/audio/test_mixer_dsp.cpp" -> "test_mixer_dsp")
  get_filename_component(TEST_NAME ${TEST_SRC} NAME_WE)

  # Prefix the target name for clean IDE grouping and collision prevention
  set(EXEC_TARGET "test_${TEST_NAME}")

  # Add standalone executable containing JUST this one source file
  add_executable(${EXEC_TARGET} ${TEST_SRC})

  target_include_directories(${EXEC_TARGET} PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}"
        "${CMAKE_CURRENT_SOURCE_DIR}/../src"
    )

  target_compile_features(${EXEC_TARGET} PRIVATE cxx_std_20)

  target_link_libraries(${EXEC_TARGET} PRIVATE
        ${AUDIO_TEST_DEPS}
    )

  # Register each individual test with CTest
  gtest_discover_tests(${EXEC_TARGET})

  # Add as a dependency to the meta check target
  add_dependencies(check_all_audio ${EXEC_TARGET})
endforeach()
