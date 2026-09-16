#include "guideController.hpp"
#include <QJsonArray>
#include <algorithm>
#include <cmath>

namespace xyla {

// construction and lifecycle

GuideController::GuideController(QObject *parent) : QObject(parent) {}

// rulers and guides

bool GuideController::getRulersEnabled() const noexcept {
  return m_rulersEnabled;
}

void GuideController::setRulersEnabled(bool enabled) {
  if (m_rulersEnabled != enabled) {
    m_rulersEnabled = enabled;
    emit rulersChanged();
  }
}

bool GuideController::getGuidesEnabled() const noexcept {
  return m_guidesEnabled;
}

void GuideController::setGuidesEnabled(bool enabled) {
  if (m_guidesEnabled != enabled) {
    m_guidesEnabled = enabled;
    emit guidesChanged();
  }
}

bool GuideController::getGuidesLocked() const noexcept {
  return m_guidesLocked;
}

void GuideController::setGuidesLocked(bool locked) {
  if (m_guidesLocked != locked) {
    m_guidesLocked = locked;
    emit guidesChanged();
  }
}

QVariantList GuideController::getHorizontalGuides() const {
  return m_horizontalGuides;
}

QVariantList GuideController::getVerticalGuides() const {
  return m_verticalGuides;
}

void GuideController::addGuide(const QString &orientation, double pos) {
  if (orientation == "horizontal") {
    m_horizontalGuides.append(pos);
  } else if (orientation == "vertical") {
    m_verticalGuides.append(pos);
  }
  emit guidesChanged();
}

void GuideController::updateGuide(const QString &orientation, int index,
                                  double newPos) {
  if (orientation == "horizontal" && index >= 0 &&
      index < m_horizontalGuides.size()) {
    m_horizontalGuides[index] = newPos;
    emit guidesChanged();
  } else if (orientation == "vertical" && index >= 0 &&
             index < m_verticalGuides.size()) {
    m_verticalGuides[index] = newPos;
    emit guidesChanged();
  }
}

void GuideController::removeGuide(const QString &orientation, int index) {
  if (orientation == "horizontal" && index >= 0 &&
      index < m_horizontalGuides.size()) {
    m_horizontalGuides.removeAt(index);
    emit guidesChanged();
  } else if (orientation == "vertical" && index >= 0 &&
             index < m_verticalGuides.size()) {
    m_verticalGuides.removeAt(index);
    emit guidesChanged();
  }
}

void GuideController::clearAllGuides() {
  if (!m_horizontalGuides.isEmpty() || !m_verticalGuides.isEmpty()) {
    m_horizontalGuides.clear();
    m_verticalGuides.clear();
    emit guidesChanged();
  }
}

// safe margins

bool GuideController::getActionSafeEnabled() const noexcept {
  return m_actionSafeEnabled;
}

void GuideController::setActionSafeEnabled(bool enabled) {
  if (m_actionSafeEnabled != enabled) {
    m_actionSafeEnabled = enabled;
    emit safeMarginsChanged();
  }
}

bool GuideController::getTitleSafeEnabled() const noexcept {
  return m_titleSafeEnabled;
}

void GuideController::setTitleSafeEnabled(bool enabled) {
  if (m_titleSafeEnabled != enabled) {
    m_titleSafeEnabled = enabled;
    emit safeMarginsChanged();
  }
}

double GuideController::getActionSafePercent() const noexcept {
  return m_actionSafePercent;
}

void GuideController::setActionSafePercent(double percent) {
  percent = std::clamp(percent, 50.0, 99.0);
  if (std::abs(m_actionSafePercent - percent) > 0.01) {
    m_actionSafePercent = percent;
    emit safeMarginsChanged();
  }
}

double GuideController::getTitleSafePercent() const noexcept {
  return m_titleSafePercent;
}

void GuideController::setTitleSafePercent(double percent) {
  percent = std::clamp(percent, 40.0, 95.0);
  if (std::abs(m_titleSafePercent - percent) > 0.01) {
    m_titleSafePercent = percent;
    emit safeMarginsChanged();
  }
}

// serialization

QJsonObject GuideController::serialize() const {
  QJsonObject obj;
  obj["rulersEnabled"] = m_rulersEnabled;
  obj["guidesEnabled"] = m_guidesEnabled;
  obj["guidesLocked"] = m_guidesLocked;
  obj["horizontalGuides"] = QJsonArray::fromVariantList(m_horizontalGuides);
  obj["verticalGuides"] = QJsonArray::fromVariantList(m_verticalGuides);
  obj["actionSafeEnabled"] = m_actionSafeEnabled;
  obj["titleSafeEnabled"] = m_titleSafeEnabled;
  obj["actionSafePercent"] = m_actionSafePercent;
  obj["titleSafePercent"] = m_titleSafePercent;
  return obj;
}

void GuideController::deserialize(const QJsonObject &obj) {
  m_rulersEnabled = obj.value("rulersEnabled").toBool(false);
  m_guidesEnabled = obj.value("guidesEnabled").toBool(true);
  m_guidesLocked = obj.value("guidesLocked").toBool(false);
  m_horizontalGuides = obj.value("horizontalGuides").toArray().toVariantList();
  m_verticalGuides = obj.value("verticalGuides").toArray().toVariantList();
  m_actionSafeEnabled = obj.value("actionSafeEnabled").toBool(false);
  m_titleSafeEnabled = obj.value("titleSafeEnabled").toBool(false);
  m_actionSafePercent = obj.value("actionSafePercent").toDouble(90.0);
  m_titleSafePercent = obj.value("titleSafePercent").toDouble(80.0);

  emit rulersChanged();
  emit guidesChanged();
  emit safeMarginsChanged();
}

} // namespace xyla
