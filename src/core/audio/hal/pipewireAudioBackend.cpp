#include "pipewireAudioBackend.hpp"
#include "core/audio/types/audioClock.hpp"
#include "core/log/logger.hpp"
#include "pipewireUtils.hpp"

#include <pipewire/pipewire.h>
#include <spa/param/audio/format-utils.h>
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

PipeWireAudioBackend::PipeWireAudioBackend()
    : m_streamListener(std::make_unique<struct spa_hook>()) {
  pw_init(nullptr, nullptr);
}

PipeWireAudioBackend::~PipeWireAudioBackend() {
  shutdown();
  pw_deinit();
}

bool PipeWireAudioBackend::initialize(const AudioDeviceConfig &config,
                                      IAudioRenderCallback *callback) {
  shutdown();

  m_config = config;
  m_callback = callback;
  m_hardwareSampleCounter = 0;

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
  if (m_running.load(std::memory_order_acquire)) {
    return true;
  }
  if (!m_loop || !m_callback) {
    return false;
  }

  struct pw_loop *pwLoop = pw_main_loop_get_loop(m_loop);
  struct pw_context *context = pw_context_new(pwLoop, nullptr, 0);
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

  // Lock latency quantum using our testable helper
  const std::string latencyStr = hal::PipeWireUtils::formatLatencyString(
      m_config.bufferSizeFrames, m_config.format.sampleRate);

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

  pw_stream_add_listener(m_stream, m_streamListener.get(), &streamEvents, this);

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

  m_loopThread = std::thread([this]() { pw_main_loop_run(m_loop); });

  return true;
}

bool PipeWireAudioBackend::stop() {
  if (!m_running.load(std::memory_order_acquire)) {
    return true;
  }

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
  if (!m_stream || !m_callback) {
    return;
  }

  struct pw_buffer *b = pw_stream_dequeue_buffer(m_stream);
  if (!b) {
    return;
  }

  struct spa_buffer *buf = b->buffer;
  const uint32_t channels = m_config.format.channelCount;

  if (!buf->datas[0].data) {
    pw_stream_queue_buffer(m_stream, b);
    return;
  }

  const uint32_t n_frames = m_config.bufferSizeFrames;
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
      static_cast<double>(m_config.format.sampleRate);

  m_pipewireBuffer.clear();
  m_callback->renderAudio(m_pipewireBuffer, clockInfo);

  float *dstInterleaved = static_cast<float *>(buf->datas[0].data);
  const float *channelPointers[2] = {m_pipewireBuffer.channelData(0),
                                     (channels > 1)
                                         ? m_pipewireBuffer.channelData(1)
                                         : m_pipewireBuffer.channelData(0)};

  // Use our decoupled real-time interleaver
  hal::PipeWireUtils::interleavePlanarToPacked(channelPointers, channels,
                                               dstInterleaved, n_frames);

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
