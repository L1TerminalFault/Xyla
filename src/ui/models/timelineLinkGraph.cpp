#include "timelineLinkGraph.hpp"

#include <QJsonArray>
#include <QUuid>

namespace xyla {

QString TimelineLinkGraph::getGroupId(const QString &clipId) const {
  auto it = m_clipToGroup.find(clipId);
  if (it != m_clipToGroup.end()) {
    return it->second;
  }
  return {};
}

QStringList TimelineLinkGraph::getLinkedClipIds(const QString &clipId) const {
  if (clipId.isEmpty()) {
    return {};
  }

  auto it = m_clipToGroup.find(clipId);
  if (it == m_clipToGroup.end() || it->second.isEmpty()) {
    return {clipId};
  }

  const QString &groupId = it->second;
  QStringList result;
  auto range = m_groupToClips.equal_range(groupId);
  for (auto git = range.first; git != range.second; ++git) {
    result.append(git->second);
  }

  return result.isEmpty() ? QStringList{clipId} : result;
}

bool TimelineLinkGraph::areLinked(const QString &clipIdA,
                                  const QString &clipIdB) const {
  if (clipIdA.isEmpty() || clipIdB.isEmpty() || clipIdA == clipIdB) {
    return false;
  }

  auto itA = m_clipToGroup.find(clipIdA);
  auto itB = m_clipToGroup.find(clipIdB);

  if (itA == m_clipToGroup.end() || itB == m_clipToGroup.end()) {
    return false;
  }

  if (itA->second.isEmpty() || itB->second.isEmpty()) {
    return false;
  }

  return itA->second == itB->second;
}

bool TimelineLinkGraph::hasLink(const QString &clipId) const {
  auto it = m_clipToGroup.find(clipId);
  return it != m_clipToGroup.end() && !it->second.isEmpty();
}

void TimelineLinkGraph::link(const QStringList &clipIds,
                             const QString &groupId) {
  if (clipIds.size() < 2 && groupId.isEmpty()) {
    return;
  }

  QString resolvedGroupId =
      groupId.isEmpty() ? QUuid::createUuid().toString(QUuid::WithoutBraces)
                        : groupId;

  for (const auto &id : clipIds) {
    unregisterClip(id);
    m_clipToGroup[id] = resolvedGroupId;
    m_groupToClips.emplace(resolvedGroupId, id);
  }
}

void TimelineLinkGraph::unlink(const QStringList &clipIds) {
  for (const auto &id : clipIds) {
    unregisterClip(id);
  }
}

void TimelineLinkGraph::registerClip(const QString &clipId,
                                     const QString &groupId) {
  if (clipId.isEmpty()) {
    return;
  }

  unregisterClip(clipId);

  if (!groupId.isEmpty()) {
    m_clipToGroup[clipId] = groupId;
    m_groupToClips.emplace(groupId, clipId);
  }
}

void TimelineLinkGraph::unregisterClip(const QString &clipId) {
  auto it = m_clipToGroup.find(clipId);
  if (it == m_clipToGroup.end()) {
    return;
  }

  const QString groupId = it->second;
  m_clipToGroup.erase(it);

  if (!groupId.isEmpty()) {
    removeClipFromMultimap(groupId, clipId);
  }
}

void TimelineLinkGraph::removeClipFromMultimap(const QString &groupId,
                                               const QString &clipId) {
  auto range = m_groupToClips.equal_range(groupId);
  for (auto it = range.first; it != range.second;) {
    if (it->second == clipId) {
      it = m_groupToClips.erase(it);
    } else {
      ++it;
    }
  }
}

void TimelineLinkGraph::splitLink(
    const std::vector<std::pair<QString, QString>> &oldToNewClipIds) {
  std::unordered_map<QString, QString> oldGroupToNewGroup;

  for (const auto &[oldId, newId] : oldToNewClipIds) {
    auto it = m_clipToGroup.find(oldId);
    if (it == m_clipToGroup.end() || it->second.isEmpty()) {
      continue;
    }

    const QString &oldGroup = it->second;
    if (!oldGroupToNewGroup.count(oldGroup)) {
      oldGroupToNewGroup[oldGroup] =
          QUuid::createUuid().toString(QUuid::WithoutBraces);
    }

    const QString &newGroup = oldGroupToNewGroup[oldGroup];
    registerClip(newId, newGroup);
  }
}

void TimelineLinkGraph::restoreLinkGroups(
    const std::vector<std::pair<QString, QString>> &previousGroups) {
  for (const auto &[clipId, groupId] : previousGroups) {
    registerClip(clipId, groupId);
  }
}

QJsonObject TimelineLinkGraph::serialize() const {
  QJsonObject root;
  QJsonArray linksArray;

  std::unordered_map<QString, QStringList> grouped;
  for (const auto &[clipId, groupId] : m_clipToGroup) {
    if (!groupId.isEmpty()) {
      grouped[groupId].append(clipId);
    }
  }

  for (const auto &[groupId, clips] : grouped) {
    QJsonObject groupObj;
    groupObj["groupId"] = groupId;
    QJsonArray clipsArray;
    for (const auto &cId : clips) {
      clipsArray.append(cId);
    }
    groupObj["clipIds"] = clipsArray;
    linksArray.append(groupObj);
  }

  root["linkGroups"] = linksArray;
  return root;
}

void TimelineLinkGraph::deserialize(const QJsonObject &obj) {
  clear();

  if (!obj.contains("linkGroups")) {
    return;
  }

  QJsonArray linksArray = obj["linkGroups"].toArray();
  for (const auto &val : linksArray) {
    QJsonObject groupObj = val.toObject();
    QString groupId = groupObj["groupId"].toString();
    QJsonArray clipsArray = groupObj["clipIds"].toArray();

    QStringList clipIds;
    for (const auto &cVal : clipsArray) {
      clipIds.append(cVal.toString());
    }

    if (!groupId.isEmpty() && !clipIds.isEmpty()) {
      link(clipIds, groupId);
    }
  }
}

void TimelineLinkGraph::clear() noexcept {
  m_clipToGroup.clear();
  m_groupToClips.clear();
}

} // namespace xyla
