#include "ui/menu/xylaMenuManager.hpp"

namespace xyla {
void MenuManager::setupColorActions() {
  registerMenuItem(
      "Color",
      {"color.primary",
       {"Primary Correction", "Adjust primary correction controls", ""},
       "",
       "",
       "qrc:/assets/icons/color-filter.svg",
       true,
       [this]() { emit requestColorPrimaryCorrection(); }});

  registerMenuItem(
      "Color", {"color.secondary",
                {"Secondary Correction", "Adjust secondary corrections", ""},
                "",
                "",
                "qrc:/assets/icons/color-swatch.svg",
                true,
                [this]() { emit requestColorSecondaryCorrection(); }});

  registerMenuItem("Color", {"color.wheels",
                             {"Color Wheels", "Open color wheels", ""},
                             "",
                             "",
                             "qrc:/assets/icons/palette.svg",
                             true,
                             [this]() { emit requestColorWheels(); }});

  registerMenuItem("Color", {"color.curves",
                             {"Color Curves", "Open curve controls", ""},
                             "",
                             "",
                             "qrc:/assets/icons/chart-line.svg",
                             true,
                             [this]() { emit requestColorCurves(); }});

  registerMenuItem("Color",
                   {"color.lut",
                    {"Color LUT...", "Apply LUT in color workspace", ""},
                    "",
                    "",
                    "qrc:/assets/icons/table.svg",
                    true,
                    [this]() { emit requestColorLUT(); }});

  registerMenuItem("Color", {"color.keyer",
                             {"Color Keyer", "Open color keyer tools", ""},
                             "",
                             "",
                             "qrc:/assets/icons/eyedropper.svg",
                             true,
                             [this]() { emit requestColorKeyer(); }});

  registerMenuItem("Color", {"color.qualifier",
                             {"Color Qualifier", "Open color qualifier", ""},
                             "",
                             "",
                             "qrc:/assets/icons/filter.svg",
                             true,
                             [this]() { emit requestColorQualifier(); }});

  registerMenuItem("Color", {"color.window",
                             {"Color Window", "Add color window mask", ""},
                             "",
                             "",
                             "qrc:/assets/icons/square.svg",
                             true,
                             [this]() { emit requestColorWindow(); }});

  registerMenuItem("Color", {"color.power_window",
                             {"Power Window", "Edit power window controls", ""},
                             "",
                             "",
                             "qrc:/assets/icons/octagon.svg",
                             true,
                             [this]() { emit requestColorPowerWindow(); }});

  registerMenuItem("Color",
                   {"color.tracker",
                    {"Color Tracker", "Track color window/qualifier", ""},
                    "",
                    "",
                    "qrc:/assets/icons/target.svg",
                    true,
                    [this]() { emit requestColorTracker(); }});

  registerMenuItem("Color",
                   {"color.stabilizer",
                    {"Color Stabilizer", "Stabilize image for grading", ""},
                    "",
                    "",
                    "qrc:/assets/icons/anchor.svg",
                    true,
                    [this]() { emit requestColorStabilizer(); }});

  registerMenuItem("Color",
                   {"color.render",
                    {"Render Color Cache", "Render color previews/cache", ""},
                    "",
                    "",
                    "qrc:/assets/icons/player-play.svg",
                    true,
                    [this]() { emit requestColorRender(); }});

  registerMenuItem("Color",
                   {"color.snapshot",
                    {"Take Color Snapshot", "Capture grading snapshot", ""},
                    "",
                    "",
                    "qrc:/assets/icons/camera.svg",
                    true,
                    [this]() { emit requestColorSnapshot(); }});

  registerMenuItem("Color", {"color.match",
                             {"Color Match", "Match grade between shots", ""},
                             "",
                             "",
                             "qrc:/assets/icons/arrows-left-right.svg",
                             true,
                             [this]() { emit requestColorMatch(); }});

  registerSeparator("Color/Adjustments");

  registerMenuItem("Color/Adjustments",
                   {"color.balance",
                    {"Color Balance", "Adjust color balance", ""},
                    "",
                    "",
                    "qrc:/assets/icons/balance.svg",
                    true,
                    [this]() { emit requestColorBalance(); }});

  registerMenuItem("Color/Adjustments",
                   {"color.temperature",
                    {"Temperature", "Adjust white balance temperature", ""},
                    "",
                    "",
                    "qrc:/assets/icons/thermometer.svg",
                    true,
                    [this]() { emit requestColorTemperature(); }});

  registerMenuItem("Color/Adjustments",
                   {"color.tint",
                    {"Tint", "Adjust green-magenta tint", ""},
                    "",
                    "",
                    "qrc:/assets/icons/droplet.svg",
                    true,
                    [this]() { emit requestColorTint(); }});

  registerMenuItem("Color/Adjustments",
                   {"color.saturation",
                    {"Saturation", "Adjust color saturation", ""},
                    "",
                    "",
                    "qrc:/assets/icons/sun.svg",
                    true,
                    [this]() { emit requestColorSaturation(); }});

  registerMenuItem("Color/Adjustments",
                   {"color.contrast",
                    {"Contrast", "Adjust image contrast", ""},
                    "",
                    "",
                    "qrc:/assets/icons/contrast.svg",
                    true,
                    [this]() { emit requestColorContrast(); }});

  registerMenuItem("Color/Adjustments",
                   {"color.shadows",
                    {"Shadows", "Adjust shadow tones", ""},
                    "",
                    "",
                    "qrc:/assets/icons/moon.svg",
                    true,
                    [this]() { emit requestColorShadows(); }});

  registerMenuItem("Color/Adjustments",
                   {"color.midtones",
                    {"Midtones", "Adjust midtone range", ""},
                    "",
                    "",
                    "qrc:/assets/icons/circle-half.svg",
                    true,
                    [this]() { emit requestColorMidtones(); }});

  registerMenuItem("Color/Adjustments",
                   {"color.highlights",
                    {"Highlights", "Adjust highlight range", ""},
                    "",
                    "",
                    "qrc:/assets/icons/sun.svg",
                    true,
                    [this]() { emit requestColorHighlights(); }});

  registerMenuItem("Color/Adjustments",
                   {"color.log",
                    {"Log Controls", "Adjust log wheels/controls", ""},
                    "",
                    "",
                    "qrc:/assets/icons/chart-dots.svg",
                    true,
                    [this]() { emit requestColorLog(); }});

  registerMenuItem("Color/Adjustments",
                   {"color.hdr",
                    {"HDR Controls", "Adjust HDR grading controls", ""},
                    "",
                    "",
                    "qrc:/assets/icons/sparkles.svg",
                    true,
                    [this]() { emit requestColorHDR(); }});
}
} // namespace xyla
