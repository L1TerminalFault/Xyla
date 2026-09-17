# ==============================================================================
# src/core/audio/CMakeLists.txt
# ==============================================================================

# 1. Types (Header-only)
add_subdirectory(types)

# 2. Pure DSP math (Header-only)
add_subdirectory(dsp)

# 3. File decoder (FFmpeg)
add_subdirectory(decoder)

# 4. Processing graph nodes
add_subdirectory(nodes)

# 5. DAG and schedule compiler
add_subdirectory(graph)

# 6. Hardware abstraction (PipeWire / Dummy)
add_subdirectory(hal)

# 7. Timeline clips and waveforms
add_subdirectory(timeline)

# 8. Engine facade
add_subdirectory(engine)

# Umbrella target for consumers
add_library(xyla_audio INTERFACE)
target_link_libraries(xyla_audio INTERFACE
    xyla_audio_engine
    xyla_audio_timeline
    xyla_audio_decoder
)
