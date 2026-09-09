#include "ui/menu/xylaMenuManager.hpp"

namespace xyla {
void MenuManager::setupEditActions() {
  registerMenuItem("Edit", {"edit.undo",
                            {"Undo", "Revert last action",
                             "https://docs.xyla.dev/manual/undo-redo"},
                            "Ctrl+Z",
                            "Ctrl+Z",
                            "qrc:/assets/icons/arrow-left.svg",
                            true,
                            nullptr});

  registerMenuItem("Edit", {"edit.redo",
                            {"Redo", "Re-apply last undone action",
                             "https://docs.xyla.dev/manual/undo-redo"},
                            "Ctrl+Y",
                            "Ctrl+Y",
                            "qrc:/assets/icons/arrow-right.svg",
                            true,
                            nullptr});

  registerSeparator("Edit");

  registerMenuItem("Edit", {"edit.cut",
                            {"Cut", "Cut selected items to clipboard", ""},
                            "Ctrl+X",
                            "Ctrl+X",
                            "qrc:/assets/icons/scissors.svg",
                            true,
                            [this]() { emit requestCut(); }});

  registerMenuItem("Edit", {"edit.copy",
                            {"Copy", "Copy selected items to clipboard", ""},
                            "Ctrl+C",
                            "Ctrl+C",
                            "qrc:/assets/icons/copy.svg",
                            true,
                            [this]() { emit requestCopy(); }});

  registerMenuItem("Edit", {"edit.paste",
                            {"Paste", "Paste items from clipboard", ""},
                            "Ctrl+V",
                            "Ctrl+V",
                            "qrc:/assets/icons/clipboard.svg",
                            true,
                            [this]() { emit requestPaste(); }});

  registerMenuItem("Edit",
                   {"edit.paste_insert",
                    {"Paste Insert", "Insert pasted item at playhead", ""},
                    "Ctrl+Shift+V",
                    "Ctrl+Shift+V",
                    "qrc:/assets/icons/clipboard-plus.svg",
                    true,
                    [this]() { emit requestPasteInsert(); }});

  registerMenuItem("Edit",
                   {"edit.paste_overwrite",
                    {"Paste Overwrite", "Overwrite with pasted item", ""},
                    "Ctrl+Alt+V",
                    "Ctrl+Alt+V",
                    "qrc:/assets/icons/clipboard-check.svg",
                    true,
                    [this]() { emit requestPasteOverwrite(); }});

  registerMenuItem("Edit", {"edit.duplicate",
                            {"Duplicate", "Duplicate selected item(s)", ""},
                            "Ctrl+D",
                            "Ctrl+D",
                            "qrc:/assets/icons/copy-plus.svg",
                            true,
                            [this]() { emit requestDuplicate(); }});

  registerMenuItem("Edit", {"edit.delete",
                            {"Delete", "Delete selected item(s)", ""},
                            "Delete",
                            "Delete",
                            "qrc:/assets/icons/trash.svg",
                            true,
                            [this]() { emit requestDelete(); }});

  registerMenuItem("Edit",
                   {"edit.ripple_delete",
                    {"Ripple Delete", "Delete and close resulting gap", ""},
                    "Shift+Delete",
                    "Shift+Delete",
                    "qrc:/assets/icons/trash-x.svg",
                    true,
                    [this]() { emit requestRippleDelete(); }});

  registerSeparator("Edit");

  registerMenuItem("Edit/Select", {"edit.select_all",
                                   {"Select All", "Select all elements", ""},
                                   "Ctrl+A",
                                   "Ctrl+A",
                                   "qrc:/assets/icons/select-all.svg",
                                   true,
                                   [this]() { emit requestSelectAll(); }});

  registerMenuItem("Edit/Select",
                   {"edit.deselect_all",
                    {"Deselect All", "Clear active selection", ""},
                    "Ctrl+Shift+A",
                    "Ctrl+Shift+A",
                                   "qrc:/assets/icons/deselect-all.svg",
                    true,
                    [this]() { emit requestDeselectAll(); }});

  registerMenuItem("Edit/Select",
                   {"edit.invert_selection",
                    {"Invert Selection", "Invert current selection", ""},
                    "",
                    "",
                    "qrc:/assets/icons/invert.svg",
                    true,
                    [this]() { emit requestInvertSelection(); }});

  registerMenuItem(
      "Edit/Select",
      {"edit.filter_selection",
       {"Filter Selection", "Filter from a selection with criteria", ""},
       "",
       "",
                    "qrc:/assets/icons/filter.svg",
       true,
       [this]() { emit requestSelectTimeline(); }});

  registerMenuItem("Edit/Select",
                   {"edit.select_tracks",
                    {"Select Tracks", "Select timeline tracks", ""},
                    "",
                    "",
                    "qrc:/assets/icons/stack.svg",
                    true,
                    [this]() { emit requestSelectTracks(); }});

  registerSeparator("Edit");

  registerMenuItem("Edit", {"edit.find",
                            {"Find...", "Find items in project/timeline", ""},
                            "Ctrl+F",
                            "Ctrl+F",
                            "qrc:/assets/icons/search.svg",
                            true,
                            [this]() { emit requestFind(); }});

  registerMenuItem("Edit",
                   {"edit.find_replace",
                    {"Find and Replace...", "Find and replace values/text", ""},
                    "Ctrl+H",
                    "Ctrl+H",
                    "qrc:/assets/icons/replace.svg",
                    true,
                    [this]() { emit requestFindAndReplace(); }});

  registerSeparator("Edit");

  registerMenuItem("Edit", {"edit.shortcuts",
                            {"Keyboard Shortcuts...",
                             "Customize keyboard shortcuts and presets", ""},
                            "Ctrl+Alt+K",
                            "Ctrl+Alt+K",
                            "qrc:/assets/icons/keyboard.svg",
                            true,
                            [this]() { emit requestKeyboardShortcuts(); }});

  registerMenuItem("Edit",
                   {"edit.preferences",
                    {"Preferences...", "Open workspace preferences", ""},
                    "Ctrl+,",
                    "Ctrl+,",
                    "qrc:/assets/icons/settings.svg",
                    true,
                    [this]() { emit requestPreferences(); }});
}
} // namespace xyla
