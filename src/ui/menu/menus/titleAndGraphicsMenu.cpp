#include "ui/menu/xylaMenuManager.hpp"

namespace xyla {

void MenuManager::setupTitleGraphicsActions() {
  registerMenuItem("Title & Graphics", {"title.new",
                                        {"New Title", "Create a new title", ""},
                                        "",
                                        "",
                                        "qrc:/assets/icons/typography.svg",
                                        true,
                                        [this]() { emit requestNewTitle(); }});

  registerMenuItem("Title & Graphics",
                   {"title.edit",
                    {"Edit Title", "Edit selected title", ""},
                    "",
                    "",
                    "qrc:/assets/icons/edit.svg",
                    true,
                    [this]() { emit requestEditTitle(); }});

  registerMenuItem("Title & Graphics",
                   {"title.duplicate",
                    {"Duplicate Title", "Duplicate selected title", ""},
                    "",
                    "",
                    "qrc:/assets/icons/copy-plus.svg",
                    true,
                    [this]() { emit requestDuplicateTitle(); }});

  registerMenuItem("Title & Graphics",
                   {"title.delete",
                    {"Delete Title", "Delete selected title", ""},
                    "",
                    "",
                    "qrc:/assets/icons/trash.svg",
                    true,
                    [this]() { emit requestDeleteTitle(); }});

  registerMenuItem("Title & Graphics",
                   {"title.import_template",
                    {"Import Title Template...", "Import title template", ""},
                    "",
                    "",
                    "qrc:/assets/icons/file-import.svg",
                    true,
                    [this]() { emit requestImportTitleTemplate(); }});

  registerMenuItem("Title & Graphics",
                   {"title.export_template",
                    {"Export Title Template...", "Export title template", ""},
                    "",
                    "",
                    "qrc:/assets/icons/file-export.svg",
                    true,
                    [this]() { emit requestExportTitleTemplate(); }});

  registerSeparator("Title & Graphics/Layers");

  registerMenuItem("Title & Graphics/Layers",
                   {"title.add_text_layer",
                    {"Add Text Layer", "Add text layer", ""},
                    "",
                    "",
                    "qrc:/assets/icons/text-plus.svg",
                    true,
                    [this]() { emit requestAddTextLayer(); }});

  registerMenuItem("Title & Graphics/Layers",
                   {"title.add_shape_layer",
                    {"Add Shape Layer", "Add shape layer", ""},
                    "",
                    "",
                    "qrc:/assets/icons/shape.svg",
                    true,
                    [this]() { emit requestAddShapeLayer(); }});

  registerMenuItem("Title & Graphics/Layers",
                   {"title.add_image_layer",
                    {"Add Image Layer", "Add image layer", ""},
                    "",
                    "",
                    "qrc:/assets/icons/photo.svg",
                    true,
                    [this]() { emit requestAddImageLayer(); }});

  registerMenuItem("Title & Graphics/Layers",
                   {"title.add_vector_layer",
                    {"Add Vector Layer", "Add vector layer", ""},
                    "",
                    "",
                    "qrc:/assets/icons/vector.svg",
                    true,
                    [this]() { emit requestAddVectorLayer(); }});

  registerSeparator("Title & Graphics/Arrange");

  registerMenuItem("Title & Graphics/Arrange",
                   {"title.bring_to_front",
                    {"Bring to Front", "Bring selected layer to front", ""},
                    "",
                    "",
                    "qrc:/assets/icons/layers-intersect.svg",
                    true,
                    [this]() { emit requestBringToFront(); }});

  registerMenuItem("Title & Graphics/Arrange",
                   {"title.send_to_back",
                    {"Send to Back", "Send selected layer to back", ""},
                    "",
                    "",
                    "qrc:/assets/icons/layers-subtract.svg",
                    true,
                    [this]() { emit requestSendToBack(); }});

  registerMenuItem("Title & Graphics/Arrange",
                   {"title.bring_forward",
                    {"Bring Forward", "Move layer one step forward", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrow-up.svg",
                    true,
                    [this]() { emit requestBringForward(); }});

  registerMenuItem("Title & Graphics/Arrange",
                   {"title.send_backward",
                    {"Send Backward", "Move layer one step backward", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrow-down.svg",
                    true,
                    [this]() { emit requestSendBackward(); }});

  registerSeparator("Title & Graphics/Align");

  registerMenuItem("Title & Graphics/Align",
                   {"title.align_left",
                    {"Align Left", "Align layers to left edge", ""},
                    "",
                    "",
                    "qrc:/assets/icons/align-left.svg",
                    true,
                    [this]() { emit requestAlignLeft(); }});

  registerMenuItem("Title & Graphics/Align",
                   {"title.align_right",
                    {"Align Right", "Align layers to right edge", ""},
                    "",
                    "",
                    "qrc:/assets/icons/align-right.svg",
                    true,
                    [this]() { emit requestAlignRight(); }});

  registerMenuItem("Title & Graphics/Align",
                   {"title.align_center",
                    {"Align Center", "Align layers horizontally centered", ""},
                    "",
                    "",
                    "qrc:/assets/icons/align-center.svg",
                    true,
                    [this]() { emit requestAlignCenter(); }});

  registerMenuItem("Title & Graphics/Align",
                   {"title.align_top",
                    {"Align Top", "Align layers to top edge", ""},
                    "",
                    "",
                    "qrc:/assets/icons/align-top.svg",
                    true,
                    [this]() { emit requestAlignTop(); }});

  registerMenuItem("Title & Graphics/Align",
                   {"title.align_bottom",
                    {"Align Bottom", "Align layers to bottom edge", ""},
                    "",
                    "",
                    "qrc:/assets/icons/align-bottom.svg",
                    true,
                    [this]() { emit requestAlignBottom(); }});

  registerMenuItem("Title & Graphics/Align",
                   {"title.align_middle",
                    {"Align Middle", "Align layers vertically centered", ""},
                    "",
                    "",
                    "qrc:/assets/icons/align-middle.svg",
                    true,
                    [this]() { emit requestAlignMiddle(); }});

  registerMenuItem(
      "Title & Graphics/Align",
      {"title.distribute_horizontal",
       {"Distribute Horizontal", "Distribute layers horizontally", ""},
       "",
       "",
       "qrc:/assets/icons/distribute-horizontal.svg",
       true,
       [this]() { emit requestDistributeHorizontal(); }});

  registerMenuItem("Title & Graphics/Align",
                   {"title.distribute_vertical",
                    {"Distribute Vertical", "Distribute layers vertically", ""},
                    "",
                    "",
                    "qrc:/assets/icons/distribute-vertical.svg",
                    true,
                    [this]() { emit requestDistributeVertical(); }});

  registerSeparator("Title & Graphics/Match");

  registerMenuItem("Title & Graphics/Match",
                   {"title.match_position",
                    {"Match Position", "Match layer position", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrows-move.svg",
                    true,
                    [this]() { emit requestMatchPosition(); }});

  registerMenuItem("Title & Graphics/Match",
                   {"title.match_scale",
                    {"Match Scale", "Match layer scale", ""},
                    "",
                    "",
                    "qrc:/assets/icons/resize.svg",
                    true,
                    [this]() { emit requestMatchScale(); }});

  registerMenuItem("Title & Graphics/Match",
                   {"title.match_rotation",
                    {"Match Rotation", "Match layer rotation", ""},
                    "",
                    "",
                    "qrc:/assets/icons/rotate.svg",
                    true,
                    [this]() { emit requestMatchRotation(); }});

  registerMenuItem("Title & Graphics/Match",
                   {"title.match_opacity",
                    {"Match Opacity", "Match layer opacity", ""},
                    "",
                    "",
                    "qrc:/assets/icons/droplet.svg",
                    true,
                    [this]() { emit requestMatchOpacity(); }});

  registerSeparator("Title & Graphics/Layer Ops");

  registerMenuItem("Title & Graphics/Layer Ops",
                   {"title.group_layers",
                    {"Group Layers", "Group selected layers", ""},
                    "Ctrl+G",
                    "Ctrl+G",
                    "qrc:/assets/icons/folder-plus.svg",
                    true,
                    [this]() { emit requestGroupLayers(); }});

  registerMenuItem("Title & Graphics/Layer Ops",
                   {"title.ungroup_layers",
                    {"Ungroup Layers", "Ungroup selected layers", ""},
                    "Ctrl+Shift+G",
                    "Ctrl+Shift+G",
                    "qrc:/assets/icons/folder-minus.svg",
                    true,
                    [this]() { emit requestUngroupLayers(); }});

  registerMenuItem("Title & Graphics/Layer Ops",
                   {"title.lock_layer",
                    {"Lock Layer", "Lock selected layer", ""},
                    "",
                    "",
                    "qrc:/assets/icons/lock.svg",
                    true,
                    [this]() { emit requestLockLayer(); }});

  registerMenuItem("Title & Graphics/Layer Ops",
                   {"title.unlock_layer",
                    {"Unlock Layer", "Unlock selected layer", ""},
                    "",
                    "",
                    "qrc:/assets/icons/lock-open.svg",
                    true,
                    [this]() { emit requestUnlockLayer(); }});

  registerMenuItem("Title & Graphics/Layer Ops",
                   {"title.hide_layer",
                    {"Hide Layer", "Hide selected layer", ""},
                    "",
                    "",
                    "qrc:/assets/icons/eye-off.svg",
                    true,
                    [this]() { emit requestHideLayer(); }});

  registerMenuItem("Title & Graphics/Layer Ops",
                   {"title.show_layer",
                    {"Show Layer", "Show selected layer", ""},
                    "",
                    "",
                    "qrc:/assets/icons/eye.svg",
                    true,
                    [this]() { emit requestShowLayer(); }});
}
} // namespace xyla
