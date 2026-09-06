#include "ui/menu/xylaMenuManager.hpp"

namespace xyla {
void MenuManager::setupEffectsActions() {
  registerMenuItem("Effects/Color",
                   {"effects.color_correction",
                    {"Color Correction", "Apply primary color correction", ""},
                    "",
                    "",
                    "qrc:/assets/icons/color-filter.svg",
                    true,
                    [this]() { emit requestApplyColorCorrection(); }});

  registerMenuItem("Effects/Color", {"effects.lut",
                                     {"Apply LUT...", "Apply lookup table", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/palette.svg",
                                     true,
                                     [this]() { emit requestApplyLUT(); }});

  registerMenuItem("Effects/Color",
                   {"effects.hdr_tools",
                    {"HDR Tools", "Apply HDR processing tools", ""},
                    "",
                    "",
                    "qrc:/assets/icons/sun.svg",
                    true,
                    [this]() { emit requestApplyHDRTools(); }});

  registerMenuItem("Effects/Color", {"effects.scopes",
                                     {"Scopes", "Open video scopes", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/chart-line.svg",
                                     true,
                                     [this]() { emit requestApplyScopes(); }});

  registerSeparator("Effects/Video");

  registerMenuItem("Effects/Video", {"effects.keyer",
                                     {"Keyer", "Apply keyer effect", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/eyedropper.svg",
                                     true,
                                     [this]() { emit requestApplyKeyer(); }});

  registerMenuItem("Effects/Video",
                   {"effects.spill_suppressor",
                    {"Spill Suppressor", "Suppress chroma spill", ""},
                    "",
                    "",
                    "qrc:/assets/icons/droplet-off.svg",
                    true,
                    [this]() { emit requestApplySpillSuppressor(); }});

  registerMenuItem("Effects/Video", {"effects.tracker",
                                     {"Tracker", "Apply tracking effect", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/target.svg",
                                     true,
                                     [this]() { emit requestApplyTracker(); }});

  registerMenuItem("Effects/Video",
                   {"effects.stabilizer",
                    {"Stabilizer", "Apply stabilization", ""},
                    "",
                    "",
                    "qrc:/assets/icons/anchor.svg",
                    true,
                    [this]() { emit requestApplyStabilizer(); }});

  registerMenuItem("Effects/Video",
                   {"effects.transform",
                    {"Transform", "Apply transform controls", ""},
                    "",
                    "",
                    "qrc:/assets/icons/transform.svg",
                    true,
                    [this]() { emit requestApplyTransform(); }});

  registerMenuItem("Effects/Video", {"effects.crop",
                                     {"Crop", "Apply crop effect", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/crop.svg",
                                     true,
                                     [this]() { emit requestApplyCrop(); }});

  registerMenuItem("Effects/Video", {"effects.blur",
                                     {"Blur", "Apply blur effect", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/blur.svg",
                                     true,
                                     [this]() { emit requestApplyBlur(); }});

  registerMenuItem("Effects/Video", {"effects.sharpen",
                                     {"Sharpen", "Apply sharpen effect", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/adjustments.svg",
                                     true,
                                     [this]() { emit requestApplySharpen(); }});

  registerMenuItem("Effects/Video", {"effects.glow",
                                     {"Glow", "Apply glow effect", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/sparkles.svg",
                                     true,
                                     [this]() { emit requestApplyGlow(); }});

  registerSeparator("Effects/Transitions");

  registerMenuItem("Effects/Transitions",
                   {"effects.fade",
                    {"Fade", "Apply fade transition", ""},
                    "",
                    "",
                    "qrc:/assets/icons/transition.svg",
                    true,
                    [this]() { emit requestApplyFade(); }});

  registerMenuItem("Effects/Transitions",
                   {"effects.wipe",
                    {"Wipe", "Apply wipe transition", ""},
                    "",
                    "",
                    "qrc:/assets/icons/rectangle.svg",
                    true,
                    [this]() { emit requestApplyWipe(); }});

  registerMenuItem("Effects/Transitions",
                   {"effects.slide",
                    {"Slide", "Apply slide transition", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrows-right-left.svg",
                    true,
                    [this]() { emit requestApplySlide(); }});

  registerMenuItem("Effects/Transitions",
                   {"effects.push",
                    {"Push", "Apply push transition", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrows-left-right.svg",
                    true,
                    [this]() { emit requestApplyPush(); }});

  registerMenuItem("Effects/Transitions",
                   {"effects.cross_dissolve",
                    {"Cross Dissolve", "Apply cross dissolve transition", ""},
                    "",
                    "",
                    "qrc:/assets/icons/transition.svg",
                    true,
                    [this]() { emit requestApplyCrossDissolve(); }});

  registerMenuItem("Effects/Transitions",
                   {"effects.dip_to_black",
                    {"Dip to Black", "Apply dip-to-black transition", ""},
                    "",
                    "",
                    "qrc:/assets/icons/moon.svg",
                    true,
                    [this]() { emit requestApplyDipToBlack(); }});

  registerMenuItem("Effects/Transitions",
                   {"effects.dip_to_white",
                    {"Dip to White", "Apply dip-to-white transition", ""},
                    "",
                    "",
                    "qrc:/assets/icons/sun.svg",
                    true,
                    [this]() { emit requestApplyDipToWhite(); }});

  registerMenuItem("Effects/Transitions",
                   {"effects.film_dissolve",
                    {"Film Dissolve", "Apply film dissolve transition", ""},
                    "",
                    "",
                    "qrc:/assets/icons/camera.svg",
                    true,
                    [this]() { emit requestApplyFilmDissolve(); }});

  registerMenuItem("Effects/Transitions",
                   {"effects.audio_transition",
                    {"Audio Transition", "Apply audio transition", ""},
                    "",
                    "",
                    "qrc:/assets/icons/wave-sine.svg",
                    true,
                    [this]() { emit requestApplyAudioTransition(); }});

  registerSeparator("Effects/Audio");

  registerMenuItem("Effects/Audio",
                   {"effects.audio_fade_in",
                    {"Audio Fade In", "Apply audio fade in", ""},
                    "",
                    "",
                    "qrc:/assets/icons/volume.svg",
                    true,
                    [this]() { emit requestApplyAudioFadeIn(); }});

  registerMenuItem("Effects/Audio",
                   {"effects.audio_fade_out",
                    {"Audio Fade Out", "Apply audio fade out", ""},
                    "",
                    "",
                    "qrc:/assets/icons/volume-off.svg",
                    true,
                    [this]() { emit requestApplyAudioFadeOut(); }});

  registerMenuItem("Effects/Audio",
                   {"effects.audio_crossfade",
                    {"Audio Crossfade", "Apply audio crossfade", ""},
                    "",
                    "",
                    "qrc:/assets/icons/arrows-left-right.svg",
                    true,
                    [this]() { emit requestApplyAudioCrossfade(); }});

  registerMenuItem(
      "Effects/Audio",
      {"effects.audio_ducking",
       {"Audio Ducking", "Automatically duck background audio", ""},
       "",
       "",
       "qrc:/assets/icons/wave-square.svg",
       true,
       [this]() { emit requestApplyAudioDucking(); }});

  registerMenuItem("Effects/Audio",
                   {"effects.noise_reduction",
                    {"Noise Reduction", "Reduce background noise", ""},
                    "",
                    "",
                    "qrc:/assets/icons/noise.svg",
                    true,
                    [this]() { emit requestApplyNoiseReduction(); }});

  registerMenuItem("Effects/Audio", {"effects.eq",
                                     {"EQ", "Apply equalizer", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/sliders.svg",
                                     true,
                                     [this]() { emit requestApplyEQ(); }});

  registerMenuItem("Effects/Audio",
                   {"effects.compressor",
                    {"Compressor", "Apply dynamic compression", ""},
                    "",
                    "",
                    "qrc:/assets/icons/compress.svg",
                    true,
                    [this]() { emit requestApplyCompressor(); }});

  registerMenuItem("Effects/Audio", {"effects.limiter",
                                     {"Limiter", "Apply limiter", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/gauge.svg",
                                     true,
                                     [this]() { emit requestApplyLimiter(); }});

  registerMenuItem("Effects/Audio", {"effects.reverb",
                                     {"Reverb", "Apply reverberation", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/wave-triangle.svg",
                                     true,
                                     [this]() { emit requestApplyReverb(); }});

  registerMenuItem("Effects/Audio", {"effects.delay",
                                     {"Delay", "Apply delay effect", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/history.svg",
                                     true,
                                     [this]() { emit requestApplyDelay(); }});

  registerMenuItem("Effects/Audio", {"effects.chorus",
                                     {"Chorus", "Apply chorus effect", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/waves.svg",
                                     true,
                                     [this]() { emit requestApplyChorus(); }});

  registerMenuItem("Effects/Audio", {"effects.flanger",
                                     {"Flanger", "Apply flanger effect", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/wave-sine.svg",
                                     true,
                                     [this]() { emit requestApplyFlanger(); }});

  registerMenuItem("Effects/Audio", {"effects.phaser",
                                     {"Phaser", "Apply phaser effect", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/rotate.svg",
                                     true,
                                     [this]() { emit requestApplyPhaser(); }});

  registerMenuItem("Effects/Audio",
                   {"effects.distortion",
                    {"Distortion", "Apply distortion effect", ""},
                    "",
                    "",
                    "qrc:/assets/icons/alert-triangle.svg",
                    true,
                    [this]() { emit requestApplyDistortion(); }});

  registerMenuItem("Effects/Audio",
                   {"effects.pitch_shift",
                    {"Pitch Shift", "Shift pitch of audio", ""},
                    "",
                    "",
                    "qrc:/assets/icons/music-note.svg",
                    true,
                    [this]() { emit requestApplyPitchShift(); }});

  registerMenuItem("Effects/Audio",
                   {"effects.time_stretch",
                    {"Time Stretch", "Stretch audio duration", ""},
                    "",
                    "",
                    "qrc:/assets/icons/resize.svg",
                    true,
                    [this]() { emit requestApplyTimeStretch(); }});

  registerMenuItem("Effects/Audio",
                   {"effects.vocal_remover",
                    {"Vocal Remover", "Reduce centered vocals", ""},
                    "",
                    "",
                    "qrc:/assets/icons/microphone-off.svg",
                    true,
                    [this]() { emit requestApplyVocalRemover(); }});

  registerMenuItem("Effects/Audio", {"effects.panning",
                                     {"Panning", "Apply stereo panning", ""},
                                     "",
                                     "",
                                     "qrc:/assets/icons/arrows-left-right.svg",
                                     true,
                                     [this]() { emit requestApplyPanning(); }});

  registerMenuItem("Effects/Audio",
                   {"effects.stereo_width",
                    {"Stereo Width", "Adjust stereo image width", ""},
                    "",
                    "",
                    "qrc:/assets/icons/rectangle-wide.svg",
                    true,
                    [this]() { emit requestApplyStereoWidth(); }});

  registerSeparator("Effects/Advanced");

  registerMenuItem(
      "Effects/Advanced",
      {"effects.keyframe_animation",
       {"Keyframe Animation", "Apply keyframe animation preset", ""},
       "",
       "",
       "qrc:/assets/icons/keyframe.svg",
       true,
       [this]() { emit requestApplyKeyframeAnimation(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.motion_blur",
                    {"Motion Blur", "Apply motion blur effect", ""},
                    "",
                    "",
                    "qrc:/assets/icons/blur.svg",
                    true,
                    [this]() { emit requestApplyMotionBlur(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.optical_flow",
                    {"Optical Flow", "Apply optical flow interpolation", ""},
                    "",
                    "",
                    "qrc:/assets/icons/activity.svg",
                    true,
                    [this]() { emit requestApplyOpticalFlow(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.neural_enhance",
                    {"Neural Enhance", "Apply AI enhancement", ""},
                    "",
                    "",
                    "qrc:/assets/icons/brain.svg",
                    true,
                    [this]() { emit requestApplyNeuralEnhance(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.noise",
                    {"Noise", "Add procedural noise", ""},
                    "",
                    "",
                    "qrc:/assets/icons/noise.svg",
                    true,
                    [this]() { emit requestApplyNoise(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.grain",
                    {"Film Grain", "Add film grain texture", ""},
                    "",
                    "",
                    "qrc:/assets/icons/grain.svg",
                    true,
                    [this]() { emit requestApplyGrain(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.vignette",
                    {"Vignette", "Apply vignette shading", ""},
                    "",
                    "",
                    "qrc:/assets/icons/circle.svg",
                    true,
                    [this]() { emit requestApplyVignette(); }});

  registerMenuItem(
      "Effects/Advanced",
      {"effects.chromatic_aberration",
       {"Chromatic Aberration", "Apply lens chromatic aberration", ""},
       "",
       "",
       "qrc:/assets/icons/rainbow.svg",
       true,
       [this]() { emit requestApplyChromaticAberration(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.lens_distortion",
                    {"Lens Distortion", "Apply lens distortion effect", ""},
                    "",
                    "",
                    "qrc:/assets/icons/lens.svg",
                    true,
                    [this]() { emit requestApplyLensDistortion(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.depth_of_field",
                    {"Depth of Field", "Simulate depth of field", ""},
                    "",
                    "",
                    "qrc:/assets/icons/focus.svg",
                    true,
                    [this]() { emit requestApplyDepthOfField(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.color_grading",
                    {"Color Grading", "Apply grading workflow preset", ""},
                    "",
                    "",
                    "qrc:/assets/icons/palette.svg",
                    true,
                    [this]() { emit requestApplyColorGrading(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.look_table",
                    {"Look Table", "Apply look table style", ""},
                    "",
                    "",
                    "qrc:/assets/icons/table.svg",
                    true,
                    [this]() { emit requestApplyLookTable(); }});

  registerMenuItem("Effects/Advanced",
                   {"effects.custom_shader",
                    {"Custom Shader...", "Apply custom shader effect", ""},
                    "",
                    "",
                    "qrc:/assets/icons/code.svg",
                    true,
                    [this]() { emit requestApplyCustomShader(); }});
}
} // namespace xyla
