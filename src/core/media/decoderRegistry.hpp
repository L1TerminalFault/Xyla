#pragma once

#include "mediaData.hpp"
#include <QString>
#include <memory>
#include <vector>

namespace xyla {

struct DecoderScore {
  int rank{0};
  bool isZeroCopyGPU{false};
  bool supportsAsyncSeek{false};
  QString decoderName{"Invalid Decoder"};

  [[nodiscard]] constexpr bool isValid() const noexcept { return rank > 0; }

  [[nodiscard]] static const DecoderScore &invalid() noexcept {
    static const DecoderScore kInvalidScore{0, false, false,
                                            "Invalid Media Metadata"};
    return kInvalidScore;
  }
};

class IDecoder {
public:
  virtual ~IDecoder() = default;
  virtual bool open(const QString &filePath) = 0;
  virtual bool decodeNextFrame() = 0;
  virtual bool seekToFrame(int64_t frameIndex, double fps = 30.0) = 0;
  virtual void close() = 0;
  virtual double nativeFps() const noexcept = 0;
  virtual int64_t currentFrameIndex() const noexcept = 0;
};

class IDecoderFactory {
public:
  virtual ~IDecoderFactory() = default;
  virtual DecoderScore evaluate(const MediaMetadata &meta) = 0;
  virtual std::unique_ptr<IDecoder>
  createDecoder(const MediaMetadata &meta) = 0;
};

class DecoderRegistry {
public:
  static DecoderRegistry &instance() {
    static DecoderRegistry reg;
    return reg;
  }

  // Registers decoder factory into registry
  void registerFactory(std::unique_ptr<IDecoderFactory> factory) {
    m_factories.push_back(std::move(factory));
  }

  // Evaluates registered factories and returns optimal decoder instance
  std::unique_ptr<IDecoder>
  selectBestDecoder(const MediaMetadata &meta,
                    DecoderScore *outScore = nullptr) {
    IDecoderFactory *bestFactory = nullptr;
    DecoderScore highestScore;

    for (const auto &factory : m_factories) {
      DecoderScore score = factory->evaluate(meta);
      if (score.rank > highestScore.rank) {
        highestScore = score;
        bestFactory = factory.get();
      }
    }

    if (outScore)
      *outScore = highestScore;
    return bestFactory ? bestFactory->createDecoder(meta) : nullptr;
  }

private:
  DecoderRegistry() = default;
  std::vector<std::unique_ptr<IDecoderFactory>> m_factories;
};

} // namespace xyla
