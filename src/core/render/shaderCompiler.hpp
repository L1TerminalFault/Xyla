#pragma once

#include <QString>
#include <cstdint>
#include <vector>

namespace xyla::render {

class ShaderCompiler {
public:
  // Compiles GLSL Compute Shader string into SPIR-V binary bytecode
  static std::vector<uint32_t>
  compileGlslToSpirv(const QString &glslSource,
                     const QString &shaderName = "FusedCompute");
};

} // namespace xyla::render
