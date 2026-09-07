#include "ui/menu/xylaMenuManager.hpp"

namespace xyla {
void MenuManager::setupToolsActions() {
  registerMenuItem("Tools", {"tools.selection",
                             {"Selection Tool", "Activate selection tool", ""},
                             "V",
                             "V",
                             "qrc:/assets/icons/cursor.svg",
                             true,
                             [this]() { emit requestSelectionTool(); }});

  registerMenuItem("Tools", {"tools.razor",
                             {"Razor Tool", "Activate blade/razor tool", ""},
                             "C",
                             "C",
                             "qrc:/assets/icons/cut.svg",
                             true,
                             [this]() { emit requestRazorTool(); }});

  registerMenuItem("Tools", {"tools.roll",
                             {"Roll Tool", "Activate roll trim tool", ""},
                             "N",
                             "N",
                             "qrc:/assets/icons/arrows-horizontal.svg",
                             true,
                             [this]() { emit requestRollTool(); }});

  registerMenuItem("Tools", {"tools.ripple",
                             {"Ripple Tool", "Activate ripple trim tool", ""},
                             "B",
                             "B",
                             "qrc:/assets/icons/resize.svg",
                             true,
                             [this]() { emit requestRippleTool(); }});

  registerMenuItem("Tools", {"tools.slip",
                             {"Slip Tool", "Activate slip tool", ""},
                             "Y",
                             "Y",
                             "qrc:/assets/icons/arrows-move-horizontal.svg",
                             true,
                             [this]() { emit requestSlipTool(); }});

  registerMenuItem("Tools", {"tools.slide",
                             {"Slide Tool", "Activate slide tool", ""},
                             "U",
                             "U",
                             "qrc:/assets/icons/arrows-move.svg",
                             true,
                             [this]() { emit requestSlideTool(); }});

  registerMenuItem("Tools", {"tools.pen",
                             {"Pen Tool", "Activate pen drawing tool", ""},
                             "P",
                             "P",
                             "qrc:/assets/icons/pen.svg",
                             true,
                             [this]() { emit requestPenTool(); }});

  registerMenuItem("Tools", {"tools.hand",
                             {"Hand Tool", "Activate panning hand tool", ""},
                             "H",
                             "H",
                             "qrc:/assets/icons/hand-stop.svg",
                             true,
                             [this]() { emit requestHandTool(); }});

  registerMenuItem("Tools", {"tools.zoom",
                             {"Zoom Tool", "Activate zoom tool", ""},
                             "Z",
                             "Z",
                             "qrc:/assets/icons/zoom-in.svg",
                             true,
                             [this]() { emit requestZoomTool(); }});

  registerMenuItem("Tools", {"tools.crop",
                             {"Crop Tool", "Activate crop tool", ""},
                             "",
                             "",
                             "qrc:/assets/icons/crop.svg",
                             true,
                             [this]() { emit requestCropTool(); }});

  registerMenuItem("Tools", {"tools.mask",
                             {"Mask Tool", "Activate mask tool", ""},
                             "",
                             "",
                             "qrc:/assets/icons/mask.svg",
                             true,
                             [this]() { emit requestMaskTool(); }});

  registerMenuItem("Tools", {"tools.text",
                             {"Text Tool", "Activate text tool", ""},
                             "T",
                             "T",
                             "qrc:/assets/icons/text-size.svg",
                             true,
                             [this]() { emit requestTextTool(); }});
}
} // namespace xyla
