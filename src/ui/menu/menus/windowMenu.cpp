#include "ui/menu/xylaMenuManager.hpp"

namespace xyla {
void MenuManager::setupWindowActions() {
  registerMenuItem("Window",
                   {"window.new",
                    {"New Window", "Open a new application window", ""},
                    "Ctrl+Shift+N",
                    "Ctrl+Shift+N",
                    "qrc:/assets/icons/window.svg",
                    true,
                    [this]() { emit requestNewWindow(); }});

  registerMenuItem("Window",
                   {"window.close",
                    {"Close Window", "Close current application window", ""},
                    "Ctrl+Shift+W",
                    "Ctrl+Shift+W",
                    "qrc:/assets/icons/x.svg",
                    true,
                    [this]() { emit requestCloseWindow(); }});

  registerMenuItem("Window", {"window.toggle_dock",
                              {"Toggle Dock", "Show/hide dock areas", ""},
                              "",
                              "",
                              "qrc:/assets/icons/layout-sidebar.svg",
                              true,
                              [this]() { emit requestToggleDock(); }});

  registerMenuItem("Window",
                   {"window.reset_layout",
                    {"Reset Window Layout", "Reset dock/window layout", ""},
                    "",
                    "",
                    "qrc:/assets/icons/layout-grid.svg",
                    true,
                    [this]() { emit requestResetWindowLayout(); }});

  registerMenuItem("Window", {"window.fullscreen",
                              {"Fullscreen Window",
                               "Toggle fullscreen for active window", ""},
                              "F11",
                              "F11",
                              "qrc:/assets/icons/maximize.svg",
                              true,
                              [this]() { emit requestFullScreenWindow(); }});

  registerMenuItem("Window",
                   {"window.minimize",
                    {"Minimize Window", "Minimize application window", ""},
                    "",
                    "",
                    "qrc:/assets/icons/minus.svg",
                    true,
                    [this]() { emit requestMinimizeWindow(); }});

  registerMenuItem("Window",
                   {"window.maximize",
                    {"Maximize Window", "Maximize application window", ""},
                    "",
                    "",
                    "qrc:/assets/icons/maximize.svg",
                    true,
                    [this]() { emit requestMaximizeWindow(); }});
}
} // namespace xyla
