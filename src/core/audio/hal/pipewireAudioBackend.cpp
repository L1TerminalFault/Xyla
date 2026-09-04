#include "pipewireAudioBackend.hpp"
#include "core/audio/types/audioClock.hpp"
#include "core/log/logger.hpp"
#include <spa/param/audio/layout.h>
#include <spa/param/param.h>

namespace xyla::audio {

static void onStreamProcess(void *userdata) {
  auto *backend = static_cast<PipeWireAudioBackend *>(userdata);
  if (backend) {
    backend->onProcess();
  }
}

static const struct pw_stream_events streamEvents = {
    .version = PW_VERSION_STREAM_EVENTS,
    .destroy = nullptr,
    .state_changed = nullptr,
    .control_info = nullptr,
    .io_changed = nullptr,
    .param_changed = nullptr,
    .add_buffer = nullptr,
    .remove_buffer = nullptr,
    .process = onStreamProcess,
    .drained = nullptr,
    .command = nullptr,
    .trigger_done = nullptr,
};

PipeWireAudioBackend::PipeWireAudioBackend() { pw_init(nullptr, nullptr); }

PipeWireAudioBackend::~PipeWireAudioBackend() {
  shutdown();
  pw_deinit();
}

bool PipeWireAudioBackend::initialize(const AudioDeviceConfig &config,
                                      IAudioRenderCallback *callback) {
  shutdown();

  m_config = config;
  m_callback = callback;

  m_pipewireBuffer.allocate(m_config.format.channelCount,
                            m_config.bufferSizeFrames);

  m_loop = pw_main_loop_new(nullptr);
  if (!m_loop) {
    XYLA_LOG_ERROR("PipeWire", "Failed to create pw_main_loop");
    return false;
  }

  return true;
}

bool PipeWireAudioBackend::start() {
  if (m_running.load(std::memory_order_acquire))
    return true;
  if (!m_loop || !m_callback)
    return false;

  XYLA_LOG_INFO("PipeWire", "Attempting to connect to PipeWire server...");

  struct pw_context *context =
      pw_context_new(pw_main_loop_get_loop(m_loop), nullptr, 0);
  if (!context) {
    XYLA_LOG_ERROR("PipeWire", "Failed to create pw_context!");
    return false;
  }

  struct pw_core *core = pw_context_connect(context, nullptr, 0);
  if (!core) {
    pw_context_destroy(context);
    XYLA_LOG_ERROR("PipeWire", "Failed to connect to PipeWire core!");
    return false;
  }

  // Force latency lock to prevent quantum mismatches (e.g. 256/48000)
  std::string latencyStr = std::to_string(m_config.bufferSizeFrames) + "/" +
                           std::to_string(m_config.format.sampleRate);

  struct pw_properties *props = pw_properties_new(
      PW_KEY_MEDIA_TYPE, "Audio", PW_KEY_MEDIA_CATEGORY, "Playback",
      PW_KEY_MEDIA_ROLE, "Production", PW_KEY_APP_NAME, "Xyla NLE",
      PW_KEY_NODE_NAME, "xyla_audio_master", PW_KEY_NODE_LATENCY,
      latencyStr.c_str(), nullptr);

  m_stream = pw_stream_new(core, "Xyla Playback", props);
  if (!m_stream) {
    XYLA_LOG_ERROR("PipeWire", "Failed to create pw_stream!");
    return false;
  }

  pw_stream_add_listener(m_stream, &m_streamListener, &streamEvents, this);

  uint8_t buffer[1024];
  struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));

  struct spa_audio_info_raw info = {};
  info.format = SPA_AUDIO_FORMAT_F32;
  info.rate = m_config.format.sampleRate;
  info.channels = m_config.format.channelCount;

  if (info.channels == 2) {
    info.position[0] = SPA_AUDIO_CHANNEL_FL;
    info.position[1] = SPA_AUDIO_CHANNEL_FR;
  }

  const struct spa_pod *params[1];
  params[0] = spa_format_audio_raw_build(&b, SPA_PARAM_EnumFormat, &info);

  int res = pw_stream_connect(
      m_stream, PW_DIRECTION_OUTPUT, PW_ID_ANY,
      static_cast<pw_stream_flags>(PW_STREAM_FLAG_AUTOCONNECT |
                                   PW_STREAM_FLAG_MAP_BUFFERS |
                                   PW_STREAM_FLAG_RT_PROCESS),
      params, 1);

  if (res < 0) {
    XYLA_LOG_ERROR("PipeWire",
                   "pw_stream_connect failed: " + std::string(strerror(-res)));
    return false;
  }

  m_running.store(true, std::memory_order_release);

  m_loopThread = std::thread([this]() {
    XYLA_LOG_INFO("PipeWire",
                  "pw_main_loop_run entered successfully on dedicated thread.");
    pw_main_loop_run(m_loop);
    XYLA_LOG_INFO("PipeWire", "pw_main_loop_run exited.");
  });

  return true;
}

bool PipeWireAudioBackend::stop() {
  if (!m_running.load(std::memory_order_acquire))
    return true;

  if (m_loop) {
    pw_main_loop_quit(m_loop);
  }

  if (m_loopThread.joinable()) {
    m_loopThread.join();
  }

  if (m_stream) {
    pw_stream_disconnect(m_stream);
    pw_stream_destroy(m_stream);
    m_stream = nullptr;
  }

  m_running.store(false, std::memory_order_release);
  return true;
}

void PipeWireAudioBackend::shutdown() {
  stop();

  if (m_loop) {
    pw_main_loop_destroy(m_loop);
    m_loop = nullptr;
  }
}

void PipeWireAudioBackend::onProcess() {
  if (!m_stream || !m_callback)
    return;

  struct pw_buffer *b = pw_stream_dequeue_buffer(m_stream);
  if (!b)
    return;

  struct spa_buffer *buf = b->buffer;
  uint32_t channels = m_config.format.channelCount;

  if (!buf->datas[0].data) {
    pw_stream_queue_buffer(m_stream, b);
    return;
  }

  // Exactly render what buffer can hold up to our period size
  uint32_t n_frames = m_config.bufferSizeFrames;
  m_pipewireBuffer.setFrameCount(n_frames);

  AudioClockInfo clockInfo;
  clockInfo.hardwareSamplePosition = m_hardwareSampleCounter;
  clockInfo.timelineSamplePosition =
      AudioMasterClock::instance().timelineSamples();
  clockInfo.sampleRate = m_config.format.sampleRate;
  clockInfo.bufferSizeFrames = n_frames;
  clockInfo.isPlaying = AudioMasterClock::instance().isPlaying();
  clockInfo.timelineSeconds =
      static_cast<double>(clockInfo.timelineSamplePosition) /
      m_config.format.sampleRate;

  m_pipewireBuffer.clear();
  m_callback->renderAudio(m_pipewireBuffer, clockInfo);

  float *dstInterleaved = static_cast<float *>(buf->datas[0].data);
  const float *srcL = m_pipewireBuffer.channelData(0);
  const float *srcR = (channels > 1) ? m_pipewireBuffer.channelData(1) : srcL;

  for (uint32_t i = 0; i < n_frames; ++i) {
    dstInterleaved[i * 2 + 0] = srcL[i];
    dstInterleaved[i * 2 + 1] = srcR[i];
  }

  if (clockInfo.isPlaying) {
    AudioMasterClock::instance().updateFromRenderCallback(
        clockInfo.timelineSamplePosition, n_frames, m_config.format.sampleRate,
        true);
  }
  m_hardwareSampleCounter += n_frames;

  buf->datas[0].chunk->offset = 0;
  buf->datas[0].chunk->stride = channels * sizeof(float);
  buf->datas[0].chunk->size = n_frames * channels * sizeof(float);

  pw_stream_queue_buffer(m_stream, b);
}

} // namespace xyla::audio
