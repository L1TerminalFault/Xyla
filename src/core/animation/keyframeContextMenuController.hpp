#pragma once

#include "core/animation/animProperty.hpp"
#include "core/animation/clipboardKeyframe.hpp"

#include <QObject>
#include <QString>
#include <QVariantList>

namespace xyla::anim {

class KeyframeContextMenuController : public QObject {
  Q_OBJECT

  Q_PROPERTY(bool hasClipboard READ hasClipboard NOTIFY clipboardChanged)
  Q_PROPERTY(
      int clipboardKeyCount READ clipboardKeyCount NOTIFY clipboardChanged)

public:
  explicit KeyframeContextMenuController(QObject *parent = nullptr);
  ~KeyframeContextMenuController() override = default;

  [[nodiscard]] bool hasClipboard() const noexcept {
    return !m_clipboard.isEmpty();
  }
  [[nodiscard]] int clipboardKeyCount() const noexcept {
    return static_cast<int>(m_clipboard.keys.size());
  }

  Q_INVOKABLE void copy(QObject *modelObj, const QVariantList &selectedKeys);
  Q_INVOKABLE void paste(QObject *modelObj, int64_t playheadFrame);
  Q_INVOKABLE void pasteNoOffset(QObject *modelObj);
  Q_INVOKABLE void pasteOverwriteRange(QObject *modelObj,
                                       int64_t playheadFrame);
  Q_INVOKABLE void pasteOverwriteAll(QObject *modelObj, int64_t playheadFrame);

  Q_INVOKABLE void setInterpolation(QObject *modelObj,
                                    const QVariantList &selectedKeys,
                                    int interpMode);

  Q_INVOKABLE void setHandleType(QObject *modelObj,
                                 const QVariantList &selectedKeys,
                                 int handleTypeInt);

  Q_INVOKABLE void setEasing(QObject *modelObj,
                             const QVariantList &selectedKeys,
                             int easingTypeInt);

  Q_INVOKABLE void cleanKeys(QObject *modelObj,
                             const QVariantList &selectedKeys,
                             float tolerance = 0.001f);

  Q_INVOKABLE void sampleKeys(QObject *modelObj,
                              const QVariantList &selectedKeys);

  Q_INVOKABLE void bakeCurve(QObject *modelObj, const QString &clipId,
                             const QString &propId);

  Q_INVOKABLE void deleteKeys(QObject *modelObj,
                              const QVariantList &selectedKeys);

  Q_INVOKABLE void setExtrapolation(QObject *modelObj, const QString &clipId,
                                    const QString &propId, int modeInt);

  Q_INVOKABLE void muteChannel(QObject *modelObj, const QString &clipId,
                               const QString &propId, bool mute);

  Q_INVOKABLE void lockChannel(QObject *modelObj, const QString &clipId,
                               const QString &propId, bool lock);

signals:
  void clipboardChanged();

private:
  ClipboardKeyframe m_clipboard;
};

} // namespace xyla::anim
