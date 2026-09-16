#include "core/audio/timeline/audioTimelineManager.hpp"
#include "core/audio/timeline/waveformGenerator.hpp"
#include "project/projectManager.hpp"
#include "timelineModel.hpp"

#include <QDebug>
#include <QJSValue>
#include <QPointF>
#include <QUuid>
#include <QVector2D>
#include <algorithm>

namespace xyla {

QVariantList TimelineModel::getClipWaveformPeaks(const QString &assetId,
                                                 int64_t startFrame,
                                                 int64_t durationFrames,
                                                 int targetPixels) const {
  QVariantList peaksList;
  if (assetId.isEmpty() || durationFrames <= 0 || targetPixels <= 0)
    return peaksList;

  const std::string assetKey = assetId.toStdString();
  auto clipBuffer =
      audio::AudioTimelineManager::instance().getClipBuffer(assetKey);
  if (!clipBuffer)
    return peaksList;

  auto pyramid =
      audio::WaveformGenerator::instance().getOrGenerate(assetKey, clipBuffer);
  if (!pyramid || !pyramid->isGenerated())
    return peaksList;

  double fps = 30.0;
  if (m_projectManager && m_projectManager->hasActiveProject()) {
    if (const auto *proj = m_projectManager->activeProject()) {
      if (proj->fps() > 0.0)
        fps = proj->fps();
    }
  }

  double sampleRate = 48000.0;
  const int64_t startSample = static_cast<int64_t>(
      (static_cast<double>(startFrame) / fps) * sampleRate);
  const size_t sampleCount = static_cast<size_t>(
      std::max(0.0, (static_cast<double>(durationFrames) / fps) * sampleRate));
  if (sampleCount == 0)
    return peaksList;

  const size_t pixels = static_cast<size_t>(std::clamp(targetPixels, 1, 8192));
  auto peaks = pyramid->getPeaks(0, startSample, sampleCount, pixels);

  peaksList.reserve(static_cast<int>(peaks.size()));
  for (const auto &p : peaks) {
    QVariantMap map;
    map.insert(QStringLiteral("min"), p.min);
    map.insert(QStringLiteral("max"), p.max);
    peaksList.append(std::move(map));
  }
  return peaksList;
}

} // namespace xyla
