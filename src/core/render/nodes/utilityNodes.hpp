#pragma once
#include "core/render/nodeGraph.hpp"


/* =============================================================================
 * XYLA SPECIAL NODES (REROUTE, COMMENT, GROUP)
 * -----------------------------------------------------------------------------
 * WHAT THIS FILE DOES:
 * 1. RerouteNode: Lightweight 1-in / 1-out dot for wire organization. Passes
 *    through video color in GLSL: `vec4 v_out = v_in;`.
 * 2. CommentNode: Backdrop / sticky note with editable text, width, and height.
 * 3. GroupNode: Container grouping a list of node IDs. Can be collapsed into a
 *    compact single card or expanded into a boundary box enclosing members.
 * ============================================================================= */

#include "core/render/node.hpp"
#include "core/render/nodeSocket.hpp"
#include <QStringList>

namespace xyla::render {

// =============================================================================
// 1. Reroute Node (Lightweight Passthrough Dot)
// =============================================================================
class RerouteNode : public Node {
public:
  RerouteNode(QString id, QString name = "Reroute")
      : Node(std::move(id), std::move(name), "Reroute") {
    addInput("in", "In", SocketDataType::Image);
    addOutput("out", "Out", SocketDataType::Image);
  }

  [[nodiscard]] QString generateGlslCode(
      const std::unordered_map<QString, QString> &inputVars,
      const QString &outputVar) const override {
    auto it = inputVars.find("in");
    QString src = (it != inputVars.end()) ? it->second : "vec4(0.0)";
    return QString("  vec4 %1 = %2;\n").arg(outputVar, src);
  }
};

// =============================================================================
// 2. Comment Node (Sticky Note / Canvas Backdrop)
// =============================================================================
class CommentNode : public Node {
public:
  CommentNode(QString id, QString text = "Notes", double w = 300.0, double h = 200.0)
      : Node(std::move(id), "Comment", "CommentNode"), m_text(std::move(text)),
        m_width(w), m_height(h) {}

  [[nodiscard]] const QString &text() const noexcept { return m_text; }
  void setText(const QString &text) { m_text = text; }

  [[nodiscard]] double width() const noexcept { return m_width; }
  [[nodiscard]] double height() const noexcept { return m_height; }
  void setDimensions(double w, double h) noexcept { m_width = w; m_height = h; }

  [[nodiscard]] QString generateGlslCode(
      const std::unordered_map<QString, QString> &,
      const QString &) const override {
    return ""; // UI visual metadata, no GPU execution
  }

  [[nodiscard]] QVariantMap toVariantMap() const override {
    QVariantMap map = Node::toVariantMap();
    map["commentText"] = m_text;
    map["boxWidth"] = m_width;
    map["boxHeight"] = m_height;
    return map;
  }

private:
  QString m_text;
  double m_width{300.0};
  double m_height{200.0};
};

// =============================================================================
// 3. Group Container Node
// =============================================================================
// class GroupNode : public Node {
// public:
//   GroupNode(QString id, QString title = "New Group")
//       : Node(std::move(id), title, "GroupNode"), m_collapsed(false) {}
//
//   [[nodiscard]] bool isCollapsed() const noexcept { return m_collapsed; }
//   void setCollapsed(bool collapsed) noexcept { m_collapsed = collapsed; }
//
//   [[nodiscard]] const QStringList &memberNodeIds() const noexcept { return m_memberNodeIds; }
//   void setMemberNodeIds(const QStringList &ids) { m_memberNodeIds = ids; }
//   void addMemberNode(const QString &id) {
//     if (!m_memberNodeIds.contains(id)) m_memberNodeIds.append(id);
//   }
//   void removeMemberNode(const QString &id) { m_memberNodeIds.removeAll(id); }
//
//   [[nodiscard]] QString generateGlslCode(
//       const std::unordered_map<QString, QString> &,
//       const QString &) const override {
//     return "";
//   }
//
//   [[nodiscard]] QVariantMap toVariantMap() const override {
//     QVariantMap map = Node::toVariantMap();
//     map["isCollapsed"] = m_collapsed;
//     map["memberNodeIds"] = m_memberNodeIds;
//     return map;
//   }
//
// private:
//   bool m_collapsed{false};
//   QStringList m_memberNodeIds;
// };



// =============================================================================
// Internal Proxy: Group Input Node
// Exposes OUTPUTS that mirror the Group Node's external INPUTS
// =============================================================================
class GroupInputNode : public Node {
public:
  GroupInputNode(const QString &id = "group_in", const QString &name = "Group Inputs")
      : Node(id, name, "GroupInputNode") {}

  void syncFromGroupInputs(const std::vector<NodeSocket> &groupInputs) {
    m_outputs.clear();
    for (const auto &s : groupInputs) {
      addOutput(s.id, s.name, s.dataType);
    }
  }

  [[nodiscard]] QString generateGlslCode(
      const std::unordered_map<QString, QString> &,
      const QString &) const override {
    return "";
  }
};

// =============================================================================
// Internal Proxy: Group Output Node
// Exposes INPUTS that mirror the Group Node's external OUTPUTS
// =============================================================================
class GroupOutputNode : public Node {
public:
  GroupOutputNode(const QString &id = "group_out", const QString &name = "Group Outputs")
      : Node(id, name, "GroupOutputNode") {}

  void syncFromGroupOutputs(const std::vector<NodeSocket> &groupOutputs) {
    m_inputs.clear();
    for (const auto &s : groupOutputs) {
      addInput(s.id, s.name, s.dataType, s.defaultValue);
    }
  }

  [[nodiscard]] QString generateGlslCode(
      const std::unordered_map<QString, QString> &,
      const QString &) const override {
    return "";
  }
};

// =============================================================================
// 3. Encapsulated Group Node (Flat DAG Architecture)
// =============================================================================
class GroupNode : public Node {
public:
  GroupNode(const QString &id, const QString &name = "Group")
      : Node(id, name, "GroupNode"), m_collapsed(false) {}

  [[nodiscard]] bool isCollapsed() const noexcept { return m_collapsed; }
  void setCollapsed(bool collapsed) noexcept { m_collapsed = collapsed; }

  [[nodiscard]] const QStringList &memberNodeIds() const noexcept { return m_memberNodeIds; }
  void setMemberNodeIds(const QStringList &ids) { m_memberNodeIds = ids; }
  void addMemberNode(const QString &id) {
    if (!m_memberNodeIds.contains(id)) m_memberNodeIds.append(id);
  }
  void removeMemberNode(const QString &id) { m_memberNodeIds.removeAll(id); }

  // --- Dynamic Public Interface Editing ---

  void addInterfaceInput(const QString &id, const QString &name, SocketDataType type, const SocketValue &defaultVal) {
    addInput(id, name, type, defaultVal);
  }

  void removeInterfaceInput(const QString &socketId) {
    auto it = std::remove_if(m_inputs.begin(), m_inputs.end(), [&](const NodeSocket &s) {
      return s.id == socketId;
    });
    m_inputs.erase(it, m_inputs.end());
  }

  void addInterfaceOutput(const QString &id, const QString &name, SocketDataType type) {
    addOutput(id, name, type);
  }

  void removeInterfaceOutput(const QString &socketId) {
    auto it = std::remove_if(m_outputs.begin(), m_outputs.end(), [&](const NodeSocket &s) {
      return s.id == socketId;
    });
    m_outputs.erase(it, m_outputs.end());
  }

  [[nodiscard]] QString generateGlslCode(
      const std::unordered_map<QString, QString> &,
      const QString &) const override {
    return "";
  }

  [[nodiscard]] QVariantMap toVariantMap() const override {
    QVariantMap map = Node::toVariantMap();
    map["isCollapsed"] = m_collapsed;
    map["memberNodeIds"] = m_memberNodeIds;
    return map;
  }

private:
  bool m_collapsed{false};
  QStringList m_memberNodeIds;
};

} // namespace xyla::render
