#include "vectorTessellator.hpp"
#include <algorithm>
#include <cmath>

namespace xyla::vector {

namespace {

bool isPointInTriangle(Vec2 p, Vec2 a, Vec2 b, Vec2 c) {
  Vec2 v0 = c - a;
  Vec2 v1 = b - a;
  Vec2 v2 = p - a;

  float dot00 = v0.dot(v0);
  float dot01 = v0.dot(v1);
  float dot02 = v0.dot(v2);
  float dot11 = v1.dot(v1);
  float dot12 = v1.dot(v2);

  float invDenom = 1.0f / (dot00 * dot11 - dot01 * dot01);
  float u = (dot11 * dot02 - dot01 * dot12) * invDenom;
  float v = (dot00 * dot12 - dot01 * dot02) * invDenom;

  return (u >= 0.0f) && (v >= 0.0f) && (u + v <= 1.0f);
}

float polygonSignedArea(const std::vector<Vec2> &pts) {
  float area = 0.0f;
  size_t n = pts.size();
  for (size_t i = 0; i < n; ++i) {
    size_t j = (i + 1) % n;
    area += pts[i].x * pts[j].y - pts[j].x * pts[i].y;
  }
  return area * 0.5f;
}

void triangulatePolygonEarcut(const std::vector<Vec2> &pts,
                              std::vector<uint32_t> &indices) {
  size_t n = pts.size();
  if (n < 3)
    return;

  std::vector<uint32_t> vList(n);
  for (size_t i = 0; i < n; ++i)
    vList[i] = static_cast<uint32_t>(i);

  if (polygonSignedArea(pts) < 0.0f) {
    std::reverse(vList.begin(), vList.end());
  }

  size_t count = n;
  size_t iteration = 0;
  size_t maxIterations = n * 5;

  while (count > 2 && iteration++ < maxIterations) {
    bool earFound = false;

    for (size_t i = 0; i < count; ++i) {
      size_t prevIdx = (i + count - 1) % count;
      size_t nextIdx = (i + 1) % count;

      uint32_t i0 = vList[prevIdx];
      uint32_t i1 = vList[i];
      uint32_t i2 = vList[nextIdx];

      Vec2 a = pts[i0];
      Vec2 b = pts[i1];
      Vec2 c = pts[i2];

      Vec2 ab = b - a;
      Vec2 bc = c - b;
      if (ab.x * bc.y - ab.y * bc.x <= 0.0f)
        continue;

      bool hasInnerPoint = false;
      for (size_t j = 0; j < count; ++j) {
        if (j == prevIdx || j == i || j == nextIdx)
          continue;
        if (isPointInTriangle(pts[vList[j]], a, b, c)) {
          hasInnerPoint = true;
          break;
        }
      }

      if (!hasInnerPoint) {
        indices.push_back(i0);
        indices.push_back(i1);
        indices.push_back(i2);
        vList.erase(vList.begin() + i);
        --count;
        earFound = true;
        break;
      }
    }

    if (!earFound)
      break;
  }
}

} // namespace

void VectorTessellator::tessellatePath(const VectorPath &path,
                                       VectorMesh &outMesh) {
  if (path.hasFill()) {
    generateFill(path, outMesh);
  }
  if (path.hasStroke()) {
    generateStroke(path, outMesh);
  }
}

void VectorTessellator::generateFill(const VectorPath &path,
                                     VectorMesh &outMesh) {
  for (const auto &contour : path.contours()) {
    std::vector<Vec2> polyPoints;

    for (const auto &seg : contour.segments()) {
      if (seg.type == SegmentType::Line) {
        polyPoints.push_back(seg.p0);
      } else if (seg.type == SegmentType::Quadratic) {
        polyPoints.push_back(seg.p0);

        uint32_t baseIdx = static_cast<uint32_t>(outMesh.fillVertices.size());
        outMesh.fillVertices.push_back({seg.p0, {0.0f, 0.0f}, 1.0f});
        outMesh.fillVertices.push_back({seg.p1, {0.5f, 0.0f}, 1.0f});
        outMesh.fillVertices.push_back({seg.p2, {1.0f, 1.0f}, 1.0f});

        Vec2 e1 = seg.p1 - seg.p0;
        Vec2 e2 = seg.p2 - seg.p1;
        float cross = e1.x * e2.y - e1.y * e2.x;

        if (cross < 0.0f) {
          outMesh.fillIndices.push_back(baseIdx);
          outMesh.fillIndices.push_back(baseIdx + 1);
          outMesh.fillIndices.push_back(baseIdx + 2);
        } else {
          outMesh.fillIndices.push_back(baseIdx);
          outMesh.fillIndices.push_back(baseIdx + 2);
          outMesh.fillIndices.push_back(baseIdx + 1);
        }
      } else if (seg.type == SegmentType::Cubic) {
        std::vector<BezierSegment> quads;
        seg.subdivideCubicToQuadratic(0.5f, quads);
        for (const auto &q : quads) {
          polyPoints.push_back(q.p0);
          uint32_t baseIdx = static_cast<uint32_t>(outMesh.fillVertices.size());
          outMesh.fillVertices.push_back({q.p0, {0.0f, 0.0f}, 1.0f});
          outMesh.fillVertices.push_back({q.p1, {0.5f, 0.0f}, 1.0f});
          outMesh.fillVertices.push_back({q.p2, {1.0f, 1.0f}, 1.0f});

          Vec2 e1 = q.p1 - q.p0;
          Vec2 e2 = q.p2 - q.p1;
          float cross = e1.x * e2.y - e1.y * e2.x;

          if (cross < 0.0f) {
            outMesh.fillIndices.push_back(baseIdx);
            outMesh.fillIndices.push_back(baseIdx + 1);
            outMesh.fillIndices.push_back(baseIdx + 2);
          } else {
            outMesh.fillIndices.push_back(baseIdx);
            outMesh.fillIndices.push_back(baseIdx + 2);
            outMesh.fillIndices.push_back(baseIdx + 1);
          }
        }
      }
    }

    if (polyPoints.size() >= 3) {
      uint32_t interiorBase =
          static_cast<uint32_t>(outMesh.fillVertices.size());
      for (const auto &pt : polyPoints) {
        outMesh.fillVertices.push_back({pt, {0.0f, 0.0f}, 0.0f});
      }

      std::vector<uint32_t> polyIndices;
      triangulatePolygonEarcut(polyPoints, polyIndices);
      for (uint32_t idx : polyIndices) {
        outMesh.fillIndices.push_back(interiorBase + idx);
      }
    }
  }
}

void VectorTessellator::generateStroke(const VectorPath &path,
                                       VectorMesh &outMesh) {
  for (const auto &contour : path.contours()) {
    tessellateContourStroke(contour, path.stroke(), outMesh);
  }
}

void VectorTessellator::tessellateContourStroke(const VectorContour &contour,
                                                const StrokeStyle &style,
                                                VectorMesh &outMesh) {
  float totalLen = contour.totalLength();
  if (totalLen <= 1e-5f)
    return;

  float step = std::max(1.0f, style.width * 0.25f);
  size_t stepCount = static_cast<size_t>(std::ceil(totalLen / step));
  stepCount = std::max<size_t>(stepCount, 4);

  float halfWidth = style.width * 0.5f;
  uint32_t baseIdx = static_cast<uint32_t>(outMesh.strokeVertices.size());

  for (size_t i = 0; i <= stepCount; ++i) {
    float s =
        (static_cast<float>(i) / static_cast<float>(stepCount)) * totalLen;
    Vec2 pos = contour.samplePositionAtLength(s);
    Vec2 normal = contour.sampleNormalAtLength(s);

    Vec2 pLeft = pos + normal * halfWidth;
    Vec2 pRight = pos - normal * halfWidth;

    outMesh.strokeVertices.push_back({pLeft, s, totalLen, 1.0f});
    outMesh.strokeVertices.push_back({pRight, s, totalLen, -1.0f});
  }

  for (size_t i = 0; i < stepCount; ++i) {
    uint32_t i0 = baseIdx + static_cast<uint32_t>(i * 2);
    uint32_t i1 = i0 + 1;
    uint32_t i2 = i0 + 2;
    uint32_t i3 = i0 + 3;

    outMesh.strokeIndices.push_back(i0);
    outMesh.strokeIndices.push_back(i1);
    outMesh.strokeIndices.push_back(i2);

    outMesh.strokeIndices.push_back(i2);
    outMesh.strokeIndices.push_back(i1);
    outMesh.strokeIndices.push_back(i3);
  }
}

} // namespace xyla::vector
