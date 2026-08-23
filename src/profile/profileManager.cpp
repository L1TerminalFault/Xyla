#include "profileManager.hpp"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

ProfileManager::ProfileManager(QObject *parent)
    : QObject(parent), m_model(new QStandardItemModel(this)) {
  QHash<int, QByteArray> roles;
  roles[Qt::DisplayRole] = "profileName";
  roles[IsCategoryRole] = "isCategory";
  roles[WidthRole] = "width";
  roles[HeightRole] = "height";
  roles[DisplayAspectNumRole] = "displayAspectNum";
  roles[DisplayAspectDenRole] = "displayAspectDen";
  roles[PixelAspectNumRole] = "pixelAspectNum";
  roles[PixelAspectDenRole] = "pixelAspectDen";
  roles[FrameRateNumRole] = "frameRateNum";
  roles[FrameRateDenRole] = "frameRateDen";
  roles[ColorspaceRole] = "colorspace";
  roles[ScanningRole] = "scanning";
  roles[FieldOrderRole] = "videoFieldOrder";

  m_model->setItemRoleNames(roles);
}

void ProfileManager::init() { loadProfiles(); }

QString ProfileManager::getOrInitProfilePath() {
  QString configDir =
      QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
  QDir().mkpath(configDir);

  QString userProfilePath = configDir + "/profiles.json";

  if (!QFile::exists(userProfilePath)) {
    // Corrected QRC path reflecting your build system tree
    QString resourcePath = ":/assets/profiles.json";

    if (!QFile::exists(resourcePath)) {
      qWarning() << "[ProfileManager] Resource asset DOES NOT EXIST at:"
                 << resourcePath;
      return QString();
    }

    QFile defaultFile(resourcePath);
    if (defaultFile.copy(userProfilePath)) {
      QFile::setPermissions(
          userProfilePath, QFileDevice::ReadOwner | QFileDevice::WriteOwner |
                               QFileDevice::ReadGroup | QFileDevice::ReadOther);
      qDebug() << "[ProfileManager] Successfully created:" << userProfilePath;
    } else {
      qWarning() << "[ProfileManager] Failed to copy resource to:"
                 << userProfilePath << "Error:" << defaultFile.errorString();
      return resourcePath;
    }
  }

  return userProfilePath;
}

bool ProfileManager::loadProfiles() {
  QString path = getOrInitProfilePath();
  QFile file(path);

  if (!file.open(QIODevice::ReadOnly)) {
    return false;
  }

  QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
  file.close();

  if (!doc.isObject()) {
    return false;
  }

  m_model->clear();
  QJsonObject rootObj = doc.object();
  QJsonArray categories = rootObj["categories"].toArray();

  for (const QJsonValue &catVal : categories) {
    QJsonObject catObj = catVal.toObject();
    QStandardItem *catItem = new QStandardItem(catObj["name"].toString());
    catItem->setData(true, IsCategoryRole);

    QJsonArray profiles = catObj["profiles"].toArray();
    for (const QJsonValue &profVal : profiles) {
      QJsonObject profObj = profVal.toObject();
      QStandardItem *profItem = new QStandardItem(profObj["name"].toString());

      profItem->setData(false, IsCategoryRole);
      profItem->setData(profObj["width"].toInt(), WidthRole);
      profItem->setData(profObj["height"].toInt(), HeightRole);
      profItem->setData(profObj["displayAspectNum"].toInt(),
                        DisplayAspectNumRole);
      profItem->setData(profObj["displayAspectDen"].toInt(),
                        DisplayAspectDenRole);
      profItem->setData(profObj["pixelAspectNum"].toInt(), PixelAspectNumRole);
      profItem->setData(profObj["pixelAspectDen"].toInt(), PixelAspectDenRole);
      profItem->setData(profObj["frameRateNum"].toInt(), FrameRateNumRole);
      profItem->setData(profObj["frameRateDen"].toInt(), FrameRateDenRole);
      profItem->setData(profObj["colorspace"].toString(), ColorspaceRole);
      profItem->setData(profObj["scanning"].toString(), ScanningRole);
      profItem->setData(profObj["fieldOrder"].toString(), FieldOrderRole);

      catItem->appendRow(profItem);
    }
    m_model->appendRow(catItem);
  }

  emit modelChanged();
  return true;
}
