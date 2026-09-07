#include "ui/menu/xylaMenuManager.hpp"

namespace xyla {
void MenuManager::setupAudioActions() {
  registerMenuItem("Audio", {"audio.gain",
                             {"Audio Gain...", "Adjust clip gain", ""},
                             "G",
                             "G",
                             "qrc:/assets/icons/volume.svg",
                             true,
                             [this]() { emit requestAudioGain(); }});

  registerMenuItem("Audio",
                   {"audio.normalize",
                    {"Normalize Audio", "Normalize selected audio levels", ""},
                    "",
                    "",
                    "qrc:/assets/icons/wave-sine.svg",
                    true,
                    [this]() { emit requestAudioNormalize(); }});

  registerMenuItem("Audio", {"audio.levels",
                             {"Audio Levels...", "Adjust audio levels", ""},
                             "",
                             "",
                             "qrc:/assets/icons/sliders.svg",
                             true,
                             [this]() { emit requestAudioLevels(); }});

  registerMenuItem("Audio", {"audio.pan",
                             {"Audio Pan", "Adjust stereo pan", ""},
                             "",
                             "",
                             "qrc:/assets/icons/arrows-left-right.svg",
                             true,
                             [this]() { emit requestAudioPan(); }});

  registerMenuItem("Audio", {"audio.balance",
                             {"Audio Balance", "Adjust channel balance", ""},
                             "",
                             "",
                             "qrc:/assets/icons/balance.svg",
                             true,
                             [this]() { emit requestAudioBalance(); }});

  registerMenuItem("Audio",
                   {"audio.track_color",
                    {"Audio Track Color...", "Set audio track color", ""},
                    "",
                    "",
                    "qrc:/assets/icons/palette.svg",
                    true,
                    [this]() { emit requestAudioTrackColor(); }});

  registerMenuItem("Audio", {"audio.render",
                             {"Render Audio", "Render audio previews", ""},
                             "",
                             "",
                             "qrc:/assets/icons/player-play.svg",
                             true,
                             [this]() { emit requestAudioRender(); }});

  registerMenuItem("Audio",
                   {"audio.replace",
                    {"Replace Audio...", "Replace selected audio source", ""},
                    "",
                    "",
                    "qrc:/assets/icons/replace.svg",
                    true,
                    [this]() { emit requestAudioReplace(); }});

  registerMenuItem("Audio", {"audio.sync",
                             {"Sync Audio", "Synchronize audio with video", ""},
                             "",
                             "",
                             "qrc:/assets/icons/clock.svg",
                             true,
                             [this]() { emit requestAudioSync(); }});

  registerMenuItem(
      "Audio", {"audio.scene_detection",
                {"Audio Scene Detection", "Detect scene changes via audio", ""},
                "",
                "",
                "qrc:/assets/icons/activity.svg",
                true,
                [this]() { emit requestAudioSceneDetection(); }});
}
} // namespace xyla
