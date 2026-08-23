#include "thumbnailGenerator.hpp"

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
}

namespace xyla {

QImage ThumbnailGenerator::extractThumbnail(const QString &filePath,
                                            int targetWidth,
                                            double timePositionSec) {
  AVFormatContext *fmtCtx = nullptr;
  if (avformat_open_input(&fmtCtx, filePath.toUtf8().constData(), nullptr,
                          nullptr) < 0) {
    return {};
  }

  if (avformat_find_stream_info(fmtCtx, nullptr) < 0) {
    avformat_close_input(&fmtCtx);
    return {};
  }

  int videoStream =
      av_find_best_stream(fmtCtx, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
  if (videoStream < 0) {
    avformat_close_input(&fmtCtx);
    return {};
  }

  AVStream *stream = fmtCtx->streams[videoStream];
  AVCodecParameters *codecPar = stream->codecpar;
  const AVCodec *codec = avcodec_find_decoder(codecPar->codec_id);
  if (!codec) {
    avformat_close_input(&fmtCtx);
    return {};
  }

  AVCodecContext *codecCtx = avcodec_alloc_context3(codec);
  avcodec_parameters_to_context(codecCtx, codecPar);
  if (avcodec_open2(codecCtx, codec, nullptr) < 0) {
    avcodec_free_context(&codecCtx);
    avformat_close_input(&fmtCtx);
    return {};
  }

  // Seek to 10% into the stream if position isn't specified
  int64_t targetPts = 0;
  if (timePositionSec < 0.0 && stream->duration > 0) {
    targetPts = stream->duration / 10;
  } else if (timePositionSec > 0.0) {
    targetPts =
        static_cast<int64_t>(timePositionSec / av_q2d(stream->time_base));
  }

  av_seek_frame(fmtCtx, videoStream, targetPts, AVSEEK_FLAG_BACKWARD);

  AVPacket *packet = av_packet_alloc();
  AVFrame *frame = av_frame_alloc();
  AVFrame *rgbFrame = av_frame_alloc();

  int targetHeight = (codecCtx->height * targetWidth) / codecCtx->width;
  int numBytes =
      av_image_get_buffer_size(AV_PIX_FMT_RGB24, targetWidth, targetHeight, 1);
  auto *buffer = static_cast<uint8_t *>(av_malloc(numBytes * sizeof(uint8_t)));

  av_image_fill_arrays(rgbFrame->data, rgbFrame->linesize, buffer,
                       AV_PIX_FMT_RGB24, targetWidth, targetHeight, 1);

  SwsContext *swsCtx = sws_getContext(
      codecCtx->width, codecCtx->height, codecCtx->pix_fmt, targetWidth,
      targetHeight, AV_PIX_FMT_RGB24, SWS_BILINEAR, nullptr, nullptr, nullptr);

  QImage resultImage;

  while (av_read_frame(fmtCtx, packet) >= 0) {
    if (packet->stream_index == videoStream) {
      if (avcodec_send_packet(codecCtx, packet) == 0) {
        if (avcodec_receive_frame(codecCtx, frame) == 0) {
          sws_scale(swsCtx, frame->data, frame->linesize, 0, codecCtx->height,
                    rgbFrame->data, rgbFrame->linesize);

          // Deep copy QImage before releasing FFmpeg buffers
          resultImage = QImage(rgbFrame->data[0], targetWidth, targetHeight,
                               rgbFrame->linesize[0], QImage::Format_RGB888)
                            .copy();
          av_packet_unref(packet);
          break;
        }
      }
    }
    av_packet_unref(packet);
  }

  // Cleanup
  av_free(buffer);
  sws_freeContext(swsCtx);
  av_frame_free(&rgbFrame);
  av_frame_free(&frame);
  av_packet_free(&packet);
  avcodec_free_context(&codecCtx);
  avformat_close_input(&fmtCtx);

  return resultImage;
}

} // namespace xyla
