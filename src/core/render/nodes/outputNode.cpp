#include "outputNode.hpp"

namespace xyla::render {

OutputNode::OutputNode(QString id, QString name)
    : Node(std::move(id), std::move(name), "OutputNode") {
  addInput("tex_in", "Texture In", SocketDataType::Image);
  addOutput("tex_out", "Texture Out", SocketDataType::Image);
}

QString OutputNode::generateGlslUniforms() const { return ""; }

QString OutputNode::generateGlslCode(
    const std::unordered_map<QString, QString> &inputVars,
    const QString &outputVar) const {

  auto texIt = inputVars.find("tex_in");
  QString texVar = (texIt != inputVars.end()) ? texIt->second : "vec4(0.0)";

  return QString("  vec4 %1 = %2;\n").arg(outputVar).arg(texVar);
}

} // namespace xyla::render
