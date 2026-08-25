#include "shaderCompiler.hpp"
#include "core/log/logger.hpp"
#include <shaderc/shaderc.hpp>

namespace xyla::render {

// Compiles GLSL source string into Vulkan SPIR-V bytecode with detailed logging
std::vector<uint32_t>
ShaderCompiler::compileGlslToSpirv(const QString &glslSource,
                                   const QString &shaderName) {
  shaderc::Compiler compiler;
  shaderc::CompileOptions options;

  options.SetOptimizationLevel(shaderc_optimization_level_performance);
  options.SetTargetEnvironment(shaderc_target_env_vulkan,
                               shaderc_env_version_vulkan_1_3);

  std::string sourceStd = glslSource.toStdString();
  std::string nameStd = shaderName.toStdString();

  XYLA_LOG_INFO("ShaderCompiler",
                "Compiling GLSL Shader [" + nameStd + "]:\n" + sourceStd);

  shaderc::SpvCompilationResult module = compiler.CompileGlslToSpv(
      sourceStd, shaderc_compute_shader, nameStd.c_str(), options);

  if (module.GetCompilationStatus() != shaderc_compilation_status_success) {
    XYLA_LOG_ERROR("ShaderCompiler", "GLSL to SPIR-V Compilation Failed:\n" +
                                         module.GetErrorMessage());
    return {};
  }

  XYLA_LOG_INFO("ShaderCompiler", "GLSL to SPIR-V Compilation Succeeded.");
  return {module.cbegin(), module.cend()};
}

} // namespace xyla::render
