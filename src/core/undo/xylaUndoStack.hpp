#pragma once

#include "xylaCommand.hpp"
#include <QObject>
#include <memory>
#include <vector>

namespace xyla {

class XylaUndoStack : public QObject {
  Q_OBJECT
  Q_PROPERTY(bool canUndo READ canUndo NOTIFY canUndoChanged)
  Q_PROPERTY(bool canRedo READ canRedo NOTIFY canRedoChanged)
  Q_PROPERTY(QString undoText READ undoText NOTIFY canUndoChanged)
  Q_PROPERTY(QString redoText READ redoText NOTIFY canRedoChanged)

public:
  explicit XylaUndoStack(QObject *parent = nullptr);
  ~XylaUndoStack() override;

  static XylaUndoStack *instance() noexcept { return s_instance; }

  void push(std::unique_ptr<XylaCommand> command);

  Q_INVOKABLE bool undo();
  Q_INVOKABLE bool redo();
  Q_INVOKABLE void clear();

  bool canUndo() const;
  bool canRedo() const;
  QString undoText() const;
  QString redoText() const;

signals:
  void canUndoChanged(bool canUndo);
  void canRedoChanged(bool canRedo);
  void indexChanged();

private:
  inline static XylaUndoStack *s_instance{nullptr};

  std::vector<std::unique_ptr<XylaCommand>> m_stack;
  int m_index{0};
  size_t m_maxUndoSteps{100};
};

} // namespace xyla
