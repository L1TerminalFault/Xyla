#pragma once

#include <QString>

namespace xyla {

class XylaCommand {
public:
  virtual ~XylaCommand() = default;

  virtual void redo() = 0;
  virtual void undo() = 0;

  virtual QString text() const = 0;

  virtual bool mergeWith(const XylaCommand *other) {
    Q_UNUSED(other);
    return false;
  }
};

} // namespace xyla
