#pragma once

#include "AnimationPropertyTable.hpp"

#include <QObject>
#include <QString>
#include <QVariant>
#include <QVariantList>
#include <memory>

namespace xyla {
class XylaUndoStack;
}

namespace xyla::anim {

class AnimationManager : public QObject {
  Q_OBJECT

public:
  explicit AnimationManager(XylaUndoStack *undoStack = nullptr,
                            QObject *parent = nullptr);
  ~AnimationManager() override = default;

  void setActiveTable(std::shared_ptr<AnimationPropertyTable> table) noexcept;
  [[nodiscard]] std::shared_ptr<AnimationPropertyTable>
  activeTable() const noexcept;
  [[nodiscard]] AnimationPropertyTable *table() noexcept;
  [[nodiscard]] const AnimationPropertyTable *table() const noexcept;

  void setUndoStack(XylaUndoStack *undoStack) noexcept;

  PropertyHandle registerFloatProperty(const QString &clipId,
                                       const QString &address,
                                       float defaultValue,
                                       const QString &displayName = "",
                                       const QString &group = "");

  PropertyHandle registerStaticProperty(const QString &clipId,
                                        const QString &address,
                                        const QVariant &defaultValue,
                                        const QString &displayName = "");

  [[nodiscard]] PropertyHandle
  findHandle(const QString &address) const noexcept;

  [[nodiscard]] float evaluateFloat(PropertyHandle handle,
                                    FrameIndex localFrame) const noexcept;

  [[nodiscard]] QVariant evaluateValue(PropertyHandle handle,
                                       FrameIndex localFrame) const;

  [[nodiscard]] float evaluateFloatByAddress(const QString &address,
                                             FrameIndex localFrame) const;

  [[nodiscard]] QVariant evaluateValueByAddress(const QString &address,
                                                FrameIndex localFrame) const;

  bool setProperty(PropertyHandle handle, const QVariant &value,
                   FrameIndex localFrame);
  bool setProperty(const QString &address, const QVariant &value,
                   FrameIndex localFrame);

  [[nodiscard]] bool hasKeyframe(PropertyHandle handle,
                                 FrameIndex localFrame) const noexcept;
  [[nodiscard]] bool hasKeyframe(const QString &address,
                                 FrameIndex localFrame) const noexcept;

  void toggleKeyframe(const QString &address, FrameIndex localFrame,
                      const QVariant &currentValue);

  void removeKeyframe(const QString &address, FrameIndex localFrame);

  [[nodiscard]] QVariantList getClipAnimChannels(const QString &clipId,
                                                 int64_t currentFrame) const;

signals:
  void propertyChanged(const QString &address);
  void keyframesChanged(const QString &clipId);
  void channelsInvalidated();
  void tableSwapped();

private:
  std::shared_ptr<AnimationPropertyTable> m_activeTable;
  XylaUndoStack *m_undoStack{nullptr};
};

} // namespace xyla::anim
