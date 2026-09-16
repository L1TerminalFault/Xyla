#pragma once

#include <QJsonObject>
#include <QString>
#include <QStringList>
#include <unordered_map>
#include <utility>
#include <vector>

namespace xyla {

class TimelineLinkGraph {
public:
  TimelineLinkGraph() = default;

  [[nodiscard]] QString getGroupId(const QString &clipId) const;
  [[nodiscard]] QStringList getLinkedClipIds(const QString &clipId) const;
  [[nodiscard]] bool areLinked(const QString &clipIdA,
                               const QString &clipIdB) const;
  [[nodiscard]] bool hasLink(const QString &clipId) const;

  void link(const QStringList &clipIds, const QString &groupId = QString());
  void unlink(const QStringList &clipIds);

  void registerClip(const QString &clipId, const QString &groupId);
  void unregisterClip(const QString &clipId);

  void
  splitLink(const std::vector<std::pair<QString, QString>> &oldToNewClipIds);
  void restoreLinkGroups(
      const std::vector<std::pair<QString, QString>> &previousGroups);

  [[nodiscard]] QJsonObject serialize() const;
  void deserialize(const QJsonObject &obj);
  void clear() noexcept;

private:
  void removeClipFromMultimap(const QString &groupId, const QString &clipId);

  std::unordered_map<QString, QString> m_clipToGroup;
  std::unordered_multimap<QString, QString> m_groupToClips;
};

} // namespace xyla
