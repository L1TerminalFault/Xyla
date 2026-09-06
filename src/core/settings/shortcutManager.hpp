#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <unordered_map>
#include <vector>

namespace xyla {

struct ShortcutAction {
  QString id;
  QString name;
  QString category;
  QString description;
  QString defaultKey;
  QString currentKey;

  [[nodiscard]] QVariantMap toVariantMap() const {
    return {{"id", id},
            {"name", name},
            {"category", category},
            {"description", description},
            {"defaultKey", defaultKey},
            {"currentKey", currentKey}};
  }
};

class ShortcutManager : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString activePresetName READ activePresetName WRITE
                 setActivePresetName NOTIFY activePresetNameChanged)
  Q_PROPERTY(QStringList availablePresets READ availablePresets NOTIFY
                 availablePresetsChanged)
  Q_PROPERTY(QVariantList allActions READ getAllActions NOTIFY shortcutsChanged)

public:
  explicit ShortcutManager(QObject *parent = nullptr);
  ~ShortcutManager() override = default;

  // Key Query (used by ActionManager and QML)
  [[nodiscard]] QString getShortcut(const QString &actionId) const;
  [[nodiscard]] QVariantMap shortcutMap() const;
  [[nodiscard]] QVariantList getAllActions() const;

  // Preset operations
  [[nodiscard]] QString activePresetName() const { return m_activePresetName; }
  Q_INVOKABLE void setActivePresetName(const QString &presetName);
  [[nodiscard]] QStringList availablePresets() const;

  Q_INVOKABLE bool createCustomPreset(const QString &newPresetName,
                                      const QString &basePresetName);
  Q_INVOKABLE bool deleteCustomPreset(const QString &presetName);

  // Key modifications
  Q_INVOKABLE bool setKeySequence(const QString &actionId,
                                  const QString &keySequence);
  Q_INVOKABLE bool resetActionToDefault(const QString &actionId);
  Q_INVOKABLE void resetAllToDefault();

  Q_INVOKABLE QString findConflictingAction(const QString &actionId,
                                            const QString &keySequence) const;

signals:
  void activePresetNameChanged(const QString &presetName);
  void availablePresetsChanged();
  void shortcutsChanged();
  void presetApplied();

private:
  void buildPresetRegistry();
  void applyPreset(const QString &presetName);
  [[nodiscard]] QString getCustomShortcutsFilePath() const;
  void loadCustomShortcuts();
  void saveCustomShortcuts() const;

  QString m_activePresetName{"Xyla Default"};
  std::vector<QString> m_actionOrder;
  std::unordered_map<QString, ShortcutAction> m_actions;
  std::unordered_map<QString, std::unordered_map<QString, QString>> m_presets;
};

inline std::vector<ShortcutAction> getMasterActionCatalog() {
  return {
      {"playback.togglePlay", "Play / Pause", "Playback",
       "Toggle forward playback", "Space", "Space"},
      {"playback.playReverse", "Shuttle Reverse (J)", "Playback",
       "Play timeline backwards", "J", "J"},
      {"playback.pause", "Shuttle Pause (K)", "Playback", "Pause playback", "K",
       "K"},
      {"playback.playForward", "Shuttle Forward (L)", "Playback",
       "Play timeline forward", "L", "L"},
      {"playback.stepForward", "Step 1 Frame Forward", "Playback",
       "Move playhead 1 frame right", "Right", "Right"},
      {"playback.stepBackward", "Step 1 Frame Backward", "Playback",
       "Move playhead 1 frame left", "Left", "Left"},
      {"playback.stepLargeFwd", "Step 1 Second Forward", "Playback",
       "Move playhead 1 second right", "Shift+Right", "Shift+Right"},
      {"playback.stepLargeBack", "Step 1 Second Backward", "Playback",
       "Move playhead 1 second left", "Shift+Left", "Shift+Left"},
      {"playback.jumpStart", "Go to Start / Home", "Playback",
       "Move playhead to timeline start", "Home", "Home"},
      {"playback.jumpEnd", "Go to End", "Playback",
       "Move playhead to timeline end", "End", "End"},
      {"playback.jumpNextEdit", "Next Edit / Clip Cut", "Playback",
       "Jump to next clip boundary", "Down", "Down"},
      {"playback.jumpPrevEdit", "Previous Edit / Clip Cut", "Playback",
       "Jump to previous clip boundary", "Up", "Up"},
      {"playback.loopToggle", "Loop Playback", "Playback",
       "Toggle loop playback mode", "Ctrl+/", "Ctrl+/"},

      // --- TIMELINE EDITING & TOOLS ---
      {"timeline.splitClip", "Split / Razor Blade", "Timeline",
       "Cut selected clips at playhead", "C", "C"},
      {"timeline.selectionTool", "Selection Tool (Arrow)", "Timeline",
       "Activate standard selection tool", "V", "V"},
      {"timeline.bladeTool", "Blade / Razor Tool", "Timeline",
       "Activate razor blade tool", "C", "C"},
      {"timeline.rippleTrimIn", "Ripple Trim Start (Top)", "Timeline",
       "Ripple trim from clip in to playhead", "Q", "Q"},
      {"timeline.rippleTrimOut", "Ripple Trim End (Tail)", "Timeline",
       "Ripple trim from playhead to out", "W", "W"},
      {"timeline.markIn", "Mark In Point", "Timeline", "Set timeline In point",
       "I", "I"},
      {"timeline.markOut", "Mark Out Point", "Timeline",
       "Set timeline Out point", "O", "O"},
      {"timeline.clearInOut", "Clear In and Out", "Timeline",
       "Clear marked In/Out range", "Alt+X", "Alt+X"},
      {"timeline.rippleDelete", "Ripple Delete", "Timeline",
       "Delete clip and close gap", "Shift+Delete", "Shift+Delete"},
      {"timeline.delete", "Delete / Lift", "Timeline",
       "Remove clip leaving empty gap", "Delete", "Delete"},
      {"timeline.linkClips", "Link Clips", "Timeline",
       "Link selected clips together", "Ctrl+L", "Ctrl+L"},
      {"timeline.unlinkClips", "Unlink Clips", "Timeline",
       "Unlink selected clips", "Ctrl+Shift+L", "Ctrl+Shift+L"},
      {"timeline.toggleClipLock", "Lock / Unlock Selected Clip", "Timeline",
       "Toggle lock state for selected clips", "Ctrl+Alt+L", "Ctrl+Alt+L"},
      {"timeline.toggleSnapping", "Toggle Snapping", "Timeline",
       "Enable or disable timeline snapping", "N", "N"},
      {"timeline.duplicate", "Duplicate Clip", "Timeline",
       "Duplicate selected clip", "Ctrl+D", "Ctrl+D"},

      // --- TIMELINE ZOOM & PAN ---
      {"timeline.zoomIn", "Zoom In", "Zoom & View", "Zoom in on timeline", "=",
       "="},
      {"timeline.zoomOut", "Zoom Out", "Zoom & View", "Zoom out on timeline",
       "-", "-"},
      {"timeline.zoomFit", "Zoom to Fit", "Zoom & View",
       "Fit entire timeline in view", "Shift+Z", "Shift+Z"},

      // --- NODE GRAPH & GRADING ---
      {"nodegraph.addNode", "Add Node Search Palette", "Node Graph",
       "Open node creation popup", "Tab", "Tab"},
      {"nodegraph.resetView", "Reset Graph View", "Node Graph",
       "Reset node graph zoom and pan", "Home", "Home"},
      {"nodegraph.deleteNode", "Delete Selected Nodes", "Node Graph",
       "Remove active node from graph", "Delete", "Delete"},
      {"nodegraph.bypassGrade", "Bypass All Color / Effects", "Node Graph",
       "Toggle master color bypass", "Shift+D", "Shift+D"},

      // --- APPLICATION & PROJECT ---
      {"edit.undo", "Undo", "Application", "Undo last operation", "Ctrl+Z",
       "Ctrl+Z"},
      {"edit.redo", "Redo", "Application", "Redo last undone operation",
       "Ctrl+Shift+Z", "Ctrl+Shift+Z"},
      {"app.save", "Save Project", "Application", "Save project to disk",
       "Ctrl+S", "Ctrl+S"},
      {"app.saveAs", "Save Project As", "Application",
       "Save project under new name", "Ctrl+Shift+S", "Ctrl+Shift+S"},
      {"app.importMedia", "Import Media", "Application",
       "Import video/audio files", "Ctrl+I", "Ctrl+I"},
      {"app.fullscreen", "Toggle Fullscreen", "Application",
       "Maximize viewport to full screen", "Ctrl+F", "Ctrl+F"},
      {"app.shortcuts", "Keyboard Shortcuts...", "Application",
       "Open the keyboard shortcuts visualizer", "Ctrl+Alt+K", "Ctrl+Alt+K"},
      {"app.preferences", "Preferences...", "Application",
       "Open workspace preferences", "Ctrl+,", "Ctrl+,"},
  };
}
} // namespace xyla
