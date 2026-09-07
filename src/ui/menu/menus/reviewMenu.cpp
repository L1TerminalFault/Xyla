#include "ui/menu/xylaMenuManager.hpp"

namespace xyla {
void MenuManager::setupReviewActions() {
  registerMenuItem("Review", {"review.add_marker",
                              {"Add Marker", "Add timeline marker", ""},
                              "M",
                              "M",
                              "qrc:/assets/icons/bookmark.svg",
                              true,
                              [this]() { emit requestAddMarker(); }});

  registerMenuItem("Review", {"review.delete_marker",
                              {"Delete Marker", "Delete selected marker", ""},
                              "",
                              "",
                              "qrc:/assets/icons/bookmark-off.svg",
                              true,
                              [this]() { emit requestDeleteMarker(); }});

  registerMenuItem("Review", {"review.goto_marker",
                              {"Go to Marker", "Jump to marker", ""},
                              "",
                              "",
                              "qrc:/assets/icons/map-pin.svg",
                              true,
                              [this]() { emit requestGotoMarker(); }});

  registerSeparator("Review");

  registerMenuItem("Review", {"review.add_comment",
                              {"Add Comment", "Add review comment", ""},
                              "",
                              "",
                              "qrc:/assets/icons/message.svg",
                              true,
                              [this]() { emit requestAddComment(); }});

  registerMenuItem("Review", {"review.add_note",
                              {"Add Note", "Add note annotation", ""},
                              "",
                              "",
                              "qrc:/assets/icons/note.svg",
                              true,
                              [this]() { emit requestAddNote(); }});

  registerMenuItem("Review", {"review.add_todo",
                              {"Add To-Do", "Add task marker/to-do", ""},
                              "",
                              "",
                              "qrc:/assets/icons/checklist.svg",
                              true,
                              [this]() { emit requestAddToDo(); }});

  registerMenuItem("Review", {"review.submit_feedback",
                              {"Submit Feedback", "Submit review feedback", ""},
                              "",
                              "",
                              "qrc:/assets/icons/send.svg",
                              true,
                              [this]() { emit requestSubmitFeedback(); }});

  registerMenuItem("Review",
                   {"review.export_feedback",
                    {"Export Feedback...", "Export review/feedback report", ""},
                    "",
                    "",
                    "qrc:/assets/icons/file-export.svg",
                    true,
                    [this]() { emit requestExportFeedback(); }});

  registerSeparator("Review");

  registerMenuItem("Review", {"review.mode",
                              {"Review Mode", "Toggle review mode", ""},
                              "",
                              "",
                              "qrc:/assets/icons/eye.svg",
                              true,
                              [this]() { emit requestReviewMode(); }});

  registerMenuItem("Review",
                   {"review.comparison_view",
                    {"Comparison View", "Open before/after comparison", ""},
                    "",
                    "",
                    "qrc:/assets/icons/columns.svg",
                    true,
                    [this]() { emit requestComparisonView(); }});

  registerMenuItem("Review",
                   {"review.split_view",
                    {"Split View", "Split viewer for side-by-side", ""},
                    "",
                    "",
                    "qrc:/assets/icons/layout-split.svg",
                    true,
                    [this]() { emit requestSplitView(); }});
}
} // namespace xyla
