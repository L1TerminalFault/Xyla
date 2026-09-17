#pragma once

#include "vectorPath.hpp"
#include <cstdint>
#include <vector>

namespace xyla::vector {

struct FillVertex {
  Vec2 position{0.0f, 0.0f};
  Vec2 uvLoopBlinn{0.0f, 0.0f};
  float sign{0.0f};
};

struct StrokeVertex {
  Vec2 position{0.0f, 0.0f};
  float arcLength{0.0f};
  float totalLength{0.0f};
  float normalDistance{0.0f};
};

struct VectorMesh {
  std::vector<FillVertex> fillVertices;
  std::vector<uint32_t> fillIndices;

  std::vector<StrokeVertex> strokeVertices;
  std::vector<uint32_t> strokeIndices;

  void clear() noexcept {
    fillVertices.clear();
    fillIndices.clear();
    strokeVertices.clear();
    strokeIndices.clear();
  }
};

class VectorTessellator {
public:
  static void tessellatePath(const VectorPath &path, VectorMesh &outMesh);
  static void generateFill(const VectorPath &path, VectorMesh &outMesh);
  static void generateStroke(const VectorPath &path, VectorMesh &outMesh);

private:
  static void tessellateContourStroke(const VectorContour &contour,
                                      const StrokeStyle &style,
                                      VectorMesh &outMesh);
};

} // namespace xyla::vector
