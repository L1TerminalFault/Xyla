#include "backgroundTranscoder.hpp"
#include "core/log/logger.hpp"
#include <QDir>
#include <QStandardPaths>
#include <chrono>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/opt.h>
#include <libswscale/swscale.h>
}

namespace xyla {

BackgroundTranscoder::BackgroundTranscoder() { start(); }
BackgroundTranscoder::~BackgroundTranscoder() { stop(); }

void BackgroundTranscoder::start() {
  if (m_running.load())
    return;
  m_running.store(true);
  m_workerThread = std::thread(&BackgroundTranscoder::workerLoop, this);
  XYLA_LOG_INFO("Transcoder", "Background hardware transcoder active.");
}

void BackgroundTranscoder::stop() {
  if (!m_running.load())
    return;
  m_running.store(false);
  m_cv.notify_all();
  if (m_workerThread.joinable()) {
    m_workerThread.join();
  }
}

void BackgroundTranscoder::queueTranscode(const QString &assetId,
                                          const QString &inputFilePath) {
  QString cacheDir =
      QStandardPaths::writableLocation(QStandardPaths::CacheLocation) +
      "/xyla_optimized/";
  QDir().mkpath(cacheDir);

  QString outputPath = cacheDir + assetId + "_intra.mp4";

  std::lock_guard<std::mutex> lock(m_queueMutex);
  m_jobQueue.push({assetId, inputFilePath, outputPath});
  m_cv.notify_one();
}

void BackgroundTranscoder::workerLoop() {
  while (m_running.load()) {
    TranscodeJob job;

    {
      std::unique_lock<std::mutex> lock(m_queueMutex);
      m_cv.wait(lock,
                [this] { return !m_jobQueue.empty() || !m_running.load(); });

      if (!m_running.load())
        break;

      job = m_jobQueue.front();
      m_jobQueue.pop();
    }

    // Short 500ms delay to prevent CUDA initialization collisions with
    // MediaPool
    std::this_thread::sleep_for(std::chrono::milliseconds(500));

    if (!m_running.load())
      break;

    XYLA_LOG_INFO("Transcoder",
                  "Starting NVENC All-Intra transcode for asset: " +
                      job.assetId.toStdString());

    if (transcodeToAllIntra(job.inputPath, job.outputPath)) {
      XYLA_LOG_INFO("Transcoder", "Transcode complete for asset: " +
                                      job.assetId.toStdString());
      emit transcodeCompleted(job.assetId, job.outputPath);
    } else {
      XYLA_LOG_ERROR("Transcoder", "Transcode failed for asset: " +
                                       job.assetId.toStdString());
    }
  }
}

bool BackgroundTranscoder::transcodeToAllIntra(const QString &inputPath,
                                               const QString &outputPath) {
  AVFormatContext *inFmt = nullptr;
  if (avformat_open_input(&inFmt, inputPath.toStdString().c_str(), nullptr,
                          nullptr) < 0)
    return false;

  if (avformat_find_stream_info(inFmt, nullptr) < 0) {
    avformat_close_input(&inFmt);
    return false;
  }

  const AVCodec *decoder = nullptr;
  int videoIdx =
      av_find_best_stream(inFmt, AVMEDIA_TYPE_VIDEO, -1, -1, &decoder, 0);
  if (videoIdx < 0) {
    avformat_close_input(&inFmt);
    return false;
  }

  AVCodecContext *decCtx = avcodec_alloc_context3(decoder);
  avcodec_parameters_to_context(decCtx, inFmt->streams[videoIdx]->codecpar);
  decCtx->thread_count = 0; // Multithreaded software decode
  if (avcodec_open2(decCtx, decoder, nullptr) < 0) {
    avcodec_free_context(&decCtx);
    avformat_close_input(&inFmt);
    return false;
  }

  // Use NVIDIA NVENC Hardware Encoder
  const AVCodec *encoder = avcodec_find_encoder_by_name("h264_nvenc");
  if (!encoder)
    encoder = avcodec_find_encoder(AV_CODEC_ID_H264);

  if (!encoder) {
    avcodec_free_context(&decCtx);
    avformat_close_input(&inFmt);
    return false;
  }

  AVFormatContext *outFmt = nullptr;
  if (avformat_alloc_output_context2(&outFmt, nullptr, nullptr,
                                     outputPath.toStdString().c_str()) < 0) {
    avcodec_free_context(&decCtx);
    avformat_close_input(&inFmt);
    return false;
  }

  AVStream *outStream = avformat_new_stream(outFmt, nullptr);
  AVCodecContext *encCtx = avcodec_alloc_context3(encoder);

  encCtx->width = decCtx->width;
  encCtx->height = decCtx->height;
  encCtx->pix_fmt = AV_PIX_FMT_NV12; // NVENC requires NV12 pixel format!
  encCtx->time_base = inFmt->streams[videoIdx]->time_base;
  encCtx->gop_size = 1; // KEY: GOP = 1 makes every frame an I-Frame (All-Intra)
  encCtx->max_b_frames = 0;

  av_opt_set(encCtx->priv_data, "preset", "p1", 0); // Ultra-fast NVENC preset
  av_opt_set(encCtx->priv_data, "tune", "ll", 0);   // Low latency

  if (outFmt->oformat->flags & AVFMT_GLOBALHEADER)
    encCtx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;

  if (avcodec_open2(encCtx, encoder, nullptr) < 0) {
    avcodec_free_context(&decCtx);
    avcodec_free_context(&encCtx);
    avformat_close_input(&inFmt);
    avformat_free_context(outFmt);
    return false;
  }

  avcodec_parameters_from_context(outStream->codecpar, encCtx);

  if (!(outFmt->oformat->flags & AVFMT_NOFILE)) {
    if (avio_open(&outFmt->pb, outputPath.toStdString().c_str(),
                  AVIO_FLAG_WRITE) < 0) {
      avcodec_free_context(&decCtx);
      avcodec_free_context(&encCtx);
      avformat_close_input(&inFmt);
      avformat_free_context(outFmt);
      return false;
    }
  }

  int headerRes = avformat_write_header(outFmt, nullptr);
  if (headerRes < 0) {
    avcodec_free_context(&decCtx);
    avcodec_free_context(&encCtx);
    avformat_close_input(&inFmt);
    if (!(outFmt->oformat->flags & AVFMT_NOFILE))
      avio_closep(&outFmt->pb);
    avformat_free_context(outFmt);
    return false;
  }

  AVPacket *inPkt = av_packet_alloc();
  AVPacket *outPkt = av_packet_alloc();
  AVFrame *decFrame = av_frame_alloc();
  AVFrame *nv12Frame = av_frame_alloc();

  nv12Frame->width = encCtx->width;
  nv12Frame->height = encCtx->height;
  nv12Frame->format = AV_PIX_FMT_NV12;
  av_frame_get_buffer(nv12Frame, 32);

  SwsContext *swsCtx = nullptr;

  while (av_read_frame(inFmt, inPkt) >= 0) {
    if (inPkt->stream_index == videoIdx) {
      if (avcodec_send_packet(decCtx, inPkt) == 0) {
        while (avcodec_receive_frame(decCtx, decFrame) == 0) {
          // Repack frame format to NV12 for NVENC
          swsCtx = sws_getCachedContext(
              swsCtx, decCtx->width, decCtx->height,
              static_cast<AVPixelFormat>(decFrame->format), encCtx->width,
              encCtx->height, AV_PIX_FMT_NV12, SWS_POINT, nullptr, nullptr,
              nullptr);

          if (swsCtx) {
            sws_scale(swsCtx, decFrame->data, decFrame->linesize, 0,
                      decCtx->height, nv12Frame->data, nv12Frame->linesize);
            nv12Frame->pts = decFrame->best_effort_timestamp;

            if (avcodec_send_frame(encCtx, nv12Frame) == 0) {
              while (avcodec_receive_packet(encCtx, outPkt) == 0) {
                av_packet_rescale_ts(outPkt, encCtx->time_base,
                                     outStream->time_base);
                outPkt->stream_index = outStream->index;
                av_interleaved_write_frame(outFmt, outPkt);
                av_packet_unref(outPkt);
              }
            }
          }
        }
      }
    }
    av_packet_unref(inPkt);
  }

  // Flush encoder
  avcodec_send_frame(encCtx, nullptr);
  while (avcodec_receive_packet(encCtx, outPkt) == 0) {
    av_packet_rescale_ts(outPkt, encCtx->time_base, outStream->time_base);
    outPkt->stream_index = outStream->index;
    av_interleaved_write_frame(outFmt, outPkt);
    av_packet_unref(outPkt);
  }

  av_write_trailer(outFmt);

  if (swsCtx)
    sws_freeContext(swsCtx);

  av_frame_free(&decFrame);
  av_frame_free(&nv12Frame);
  av_packet_free(&inPkt);
  av_packet_free(&outPkt);
  avcodec_free_context(&decCtx);
  avcodec_free_context(&encCtx);
  avformat_close_input(&inFmt);
  if (!(outFmt->oformat->flags & AVFMT_NOFILE))
    avio_closep(&outFmt->pb);
  avformat_free_context(outFmt);

  return true;
}

} // namespace xyla
