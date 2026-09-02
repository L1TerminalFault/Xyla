#include "xylaUndoStack.hpp"
#include "core/log/logger.hpp"

namespace xyla {

XylaUndoStack::XylaUndoStack(QObject *parent) : QObject(parent) {
  s_instance = this;
}

XylaUndoStack::~XylaUndoStack() {
  if (s_instance == this) {
    s_instance = nullptr;
  }
}

void XylaUndoStack::push(std::unique_ptr<XylaCommand> command) {
  if (!command)
    return;

  if (m_index < static_cast<int>(m_stack.size())) {
    m_stack.erase(m_stack.begin() + m_index, m_stack.end());
  }

  if (!m_stack.empty() && m_stack.back()->mergeWith(command.get())) {
    m_stack.back()->redo();
    emit indexChanged();
    return;
  }

  command->redo();
  m_stack.push_back(std::move(command));
  m_index = static_cast<int>(m_stack.size());

  if (m_stack.size() > m_maxUndoSteps) {
    m_stack.erase(m_stack.begin());
    m_index--;
  }

  emit canUndoChanged(canUndo());
  emit canRedoChanged(canRedo());
  emit indexChanged();
}

bool XylaUndoStack::undo() {
  if (!canUndo())
    return false;

  m_index--;
  m_stack[m_index]->undo();

  XYLA_LOG_INFO("UndoStack",
                "Undid action: " + m_stack[m_index]->text().toStdString());

  emit canUndoChanged(canUndo());
  emit canRedoChanged(canRedo());
  emit indexChanged();
  return true;
}

bool XylaUndoStack::redo() {
  if (!canRedo())
    return false;

  m_stack[m_index]->redo();
  XYLA_LOG_INFO("UndoStack",
                "Redid action: " + m_stack[m_index]->text().toStdString());
  m_index++;

  emit canUndoChanged(canUndo());
  emit canRedoChanged(canRedo());
  emit indexChanged();
  return true;
}

void XylaUndoStack::clear() {
  m_stack.clear();
  m_index = 0;
  emit canUndoChanged(false);
  emit canRedoChanged(false);
  emit indexChanged();
}

bool XylaUndoStack::canUndo() const { return m_index > 0; }

bool XylaUndoStack::canRedo() const {
  return m_index < static_cast<int>(m_stack.size());
}

QString XylaUndoStack::undoText() const {
  return canUndo() ? m_stack[m_index - 1]->text() : QString();
}

QString XylaUndoStack::redoText() const {
  return canRedo() ? m_stack[m_index]->text() : QString();
}

} // namespace xyla
