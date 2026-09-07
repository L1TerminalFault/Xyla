#include "ui/menu/xylaMenuManager.hpp"

namespace xyla {
void MenuManager::setupHelpActions() {
  registerMenuItem("Help", {"help.documentation",
                            {"Documentation", "Open Xyla documentation",
                             "https://docs.xyla.dev"},
                            "F1",
                            "F1",
                            "qrc:/assets/icons/book.svg",
                            true,
                            [this]() { emit requestDocumentation(); }});

  registerMenuItem("Help", {"help.tutorials",
                            {"Tutorials", "Open getting started tutorials", ""},
                            "",
                            "",
                            "qrc:/assets/icons/video.svg",
                            true,
                            [this]() { emit requestTutorials(); }});

  registerMenuItem("Help",
                   {"help.shortcuts",
                    {"Keyboard Shortcuts Help", "View shortcut reference", ""},
                    "",
                    "",
                    "qrc:/assets/icons/keyboard.svg",
                    true,
                    [this]() { emit requestKeyboardShortcutsHelp(); }});

  registerMenuItem(
      "Help", {"help.community",
               {"Community Forums", "Open community discussion forums", ""},
               "",
               "",
               "qrc:/assets/icons/users.svg",
               true,
               [this]() { emit requestCommunityForums(); }});

  registerSeparator("Help");

  registerMenuItem("Help",
                   {"help.report_issue",
                    {"Report Issue", "Report a bug or unexpected behavior", ""},
                    "",
                    "",
                    "qrc:/assets/icons/bug.svg",
                    true,
                    [this]() { emit requestReportIssue(); }});

  registerMenuItem("Help", {"help.feature_request",
                            {"Feature Request", "Suggest a new feature", ""},
                            "",
                            "",
                            "qrc:/assets/icons/bulb.svg",
                            true,
                            [this]() { emit requestFeatureRequest(); }});

  registerMenuItem("Help", {"help.check_updates",
                            {"Check for Updates",
                             "Check for latest application updates", ""},
                            "",
                            "",
                            "qrc:/assets/icons/refresh.svg",
                            true,
                            [this]() { emit requestCheckForUpdates(); }});

  registerSeparator("Help");

  registerMenuItem("Help",
                   {"help.about",
                    {"About Xyla", "Show app and version information", ""},
                    "",
                    "",
                    "qrc:/assets/icons/info-circle.svg",
                    true,
                    [this]() { emit requestAbout(); }});

  registerMenuItem("Help",
                   {"help.system_info",
                    {"System Info", "Show runtime/system diagnostics", ""},
                    "",
                    "",
                    "qrc:/assets/icons/cpu.svg",
                    true,
                    [this]() { emit requestSystemInfo(); }});
}
} // namespace xyla
