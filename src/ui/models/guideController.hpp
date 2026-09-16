#pragma once

#include <QJsonObject>
#include <QObject>
#include <QVariantList>

namespace xyla {

class GuideController : public QObject {
  Q_OBJECT

  // properties
  Q_PROPERTY(bool rulersEnabled READ getRulersEnabled WRITE setRulersEnabled
                 NOTIFY rulersChanged)
  Q_PROPERTY(bool guidesEnabled READ getGuidesEnabled WRITE setGuidesEnabled
                 NOTIFY guidesChanged)
  Q_PROPERTY(bool guidesLocked READ getGuidesLocked WRITE setGuidesLocked NOTIFY
                 guidesChanged)
  Q_PROPERTY(QVariantList horizontalGuides READ getHorizontalGuides NOTIFY
                 guidesChanged)
  Q_PROPERTY(
      QVariantList verticalGuides READ getVerticalGuides NOTIFY guidesChanged)
  Q_PROPERTY(bool actionSafeEnabled READ getActionSafeEnabled WRITE
                 setActionSafeEnabled NOTIFY safeMarginsChanged)
  Q_PROPERTY(bool titleSafeEnabled READ getTitleSafeEnabled WRITE
                 setTitleSafeEnabled NOTIFY safeMarginsChanged)
  Q_PROPERTY(double actionSafePercent READ getActionSafePercent WRITE
                 setActionSafePercent NOTIFY safeMarginsChanged)
  Q_PROPERTY(double titleSafePercent READ getTitleSafePercent WRITE
                 setTitleSafePercent NOTIFY safeMarginsChanged)

public:
  // construction and lifecycle
  explicit GuideController(QObject *parent = nullptr);
  ~GuideController() override = default;

  // rulers and guides
  [[nodiscard]] bool getRulersEnabled() const noexcept;
  void setRulersEnabled(bool enabled);

  [[nodiscard]] bool getGuidesEnabled() const noexcept;
  void setGuidesEnabled(bool enabled);

  [[nodiscard]] bool getGuidesLocked() const noexcept;
  void setGuidesLocked(bool locked);

  [[nodiscard]] QVariantList getHorizontalGuides() const;
  [[nodiscard]] QVariantList getVerticalGuides() const;

  Q_INVOKABLE void addGuide(const QString &orientation, double pos);
  Q_INVOKABLE void updateGuide(const QString &orientation, int index,
                               double newPos);
  Q_INVOKABLE void removeGuide(const QString &orientation, int index);
  Q_INVOKABLE void clearAllGuides();

  // safe margins
  [[nodiscard]] bool getActionSafeEnabled() const noexcept;
  void setActionSafeEnabled(bool enabled);

  [[nodiscard]] bool getTitleSafeEnabled() const noexcept;
  void setTitleSafeEnabled(bool enabled);

  [[nodiscard]] double getActionSafePercent() const noexcept;
  void setActionSafePercent(double percent);

  [[nodiscard]] double getTitleSafePercent() const noexcept;
  void setTitleSafePercent(double percent);

  // serialization
  [[nodiscard]] QJsonObject serialize() const;
  void deserialize(const QJsonObject &obj);

signals:
  void rulersChanged();
  void guidesChanged();
  void safeMarginsChanged();

private:
  bool m_rulersEnabled{false};
  bool m_guidesEnabled{true};
  bool m_guidesLocked{false};
  QVariantList m_horizontalGuides;
  QVariantList m_verticalGuides;

  bool m_actionSafeEnabled{false};
  bool m_titleSafeEnabled{false};
  double m_actionSafePercent{90.0};
  double m_titleSafePercent{80.0};
};

} // namespace xyla
