#pragma once

#include "core/actions/xylaActionManager.hpp"
#include "core/actions/xylaMenuItemData.hpp"
#include <QHash>
#include <QObject>
#include <QVariantList>
#include <functional>
#include <vector>

namespace xyla {

class MenuManager : public QObject {
  Q_OBJECT
  Q_PROPERTY(QVariantList menuTree READ menuTree NOTIFY menuTreeChanged)

public:
  explicit MenuManager(XylaActionManager *actionManager,
                       QObject *parent = nullptr);
  ~MenuManager() override = default;

  void registerMenuItem(const QString &menuPath, const XylaActionData &action);
  void registerSeparator(const QString &menuPath);

  Q_INVOKABLE void triggerAction(const QString &actionId);

  QVariantList menuTree() const { return m_cachedMenuTree; }

public slots:
  void rebuildMenuTree();
  void updateMenuTreeState();

signals:
  void menuTreeChanged();

  // --- FILE SIGNALS ---
  void requestNewProject();
  void requestOpenProject();
  void requestOpenRecent();
  void requestCloseProject();
  void requestSaveProject();
  void requestSaveProjectAs();
  void requestRevertToSaved();
  void requestImport();
  void requestExport();
  void requestExportTimeline();
  void requestExportFrame();
  void requestExportAudio();
  void requestExportXML();
  void requestExportOMF();
  void requestExportPNGSequence();
  void requestExportTIFFSequence();
  void requestExportEXRSequence();
  void requestExportMarkersCSV();
  void requestExportAAF();
  void requestExportEDL();
  void requestExportSubtitle();
  void requestBatchExport();
  void requestProjectSettings();
  void requestProjectMetadata();
  void requestGenerateProxy();
  void requestReconnectMedia();
  void requestConsolidateMedia();
  void requestClearCache();
  void requestQuit();

  // --- EDIT SIGNALS ---
  void requestUndo();
  void requestRedo();
  void requestCut();
  void requestCopy();
  void requestPaste();
  void requestPasteInsert();
  void requestPasteOverwrite();
  void requestDuplicate();
  void requestDelete();
  void requestRippleDelete();
  void requestLift();
  void requestExtract();
  void requestSelectAll();
  void requestDeselectAll();
  void requestInvertSelection();
  void requestSelectTimeline();
  void requestSelectClips();
  void requestSelectTracks();
  void requestFind();
  void requestFindAndReplace();
  void requestKeyboardShortcuts();
  void requestPreferences();

  // --- VIEW SIGNALS ---
  void requestToggleFullscreen();
  void requestToggleTimelineVisibility();
  void requestToggleProjectPanel();
  void requestToggleEffectsPanel();
  void requestTogglePropertiesPanel();
  void requestToggleAudioPanel();
  void requestToggleColorPanel();
  void requestToggleMetadataPanel();
  void requestZoomIn();
  void requestZoomOut();
  void requestZoomToFit();
  void requestZoomToSelection();
  void requestResetView();
  void requestLoadWorkspaceLayout();
  void requestSaveWorkspaceLayout();
  void requestManageLayoutPresets();
  void requestIncreaseInterfaceScale();
  void requestDecreaseInterfaceScale();
  void requestResetInterfaceScale();
  void requestThemeSettings();
  void requestGotoTimecode();
  void requestShowGrid();
  void requestShowRulers();
  void requestShowSafeAreas();
  void requestShowMarkers();
  void requestShowWaveforms();
  void requestShowThumbnails();
  void requestShowKeyframes();

  // --- CLIP SIGNALS ---
  void requestAddVideoClip();
  void requestAddAudioClip();
  void requestAddImageClip();
  void requestAddTextClip();
  void requestAddVectorClip();
  void requestAddSubtitleClip();
  void requestAddAdjustmentClip();
  void requestAddColorMatte();
  void requestAddTitleTemplate();
  void requestAddLowerThird();
  void requestAddOverlay();
  void requestAddEffect();
  void requestAddTransition();
  void requestAddKeyframe();
  void requestSplitClip();
  void requestSplitSample();
  void requestSliceClip();
  void requestTrimStart();
  void requestTrimEnd();
  void requestRippleTrim();
  void requestRollTrim();
  void requestSlipTrim();
  void requestSlideTrim();
  void requestExtendToPlayhead();
  void requestShrinkToPlayhead();
  void requestSnapToPlayhead();
  void requestTranscodeClip();
  void requestReplaceClip();
  void requestReplaceSource();
  void requestReconnectClip();
  void requestOpenClipInAssetManager();
  void requestOpenClipInNewTimeline();
  void requestOpenInSourceMonitor();
  void requestReplaceSelectedClips();
  void requestRippleReplaceClipOccurrences();
  void requestSelectAllOccurrences();
  void requestSelectMatching();
  void requestCheckerDeselect();
  void requestSelectFirst();
  void requestSelectLast();
  void requestSelectFirstAndLast();
  void requestSelectPrevious();
  void requestSelectNext();
  void requestSelectLeftEdge();
  void requestSelectRightEdge();
  void requestClipProperties();
  void requestDeleteClip();
  void requestRenameClip();
  void requestDuplicateClip();
  void requestReverseClip();
  void requestFreezeFrame();
  void requestSpeedDuration();
  void requestTimeRemapping();
  void requestNestSequence();
  void requestUnnestSequence();

  // --- TIMELINE SIGNALS ---
  void requestAddTrack();
  void requestAddVideoTrack();
  void requestAddAudioTrack();
  void requestDeleteTrack();
  void requestDeleteVideoTrack();
  void requestDeleteAudioTrack();
  void requestMoveTrackUp();
  void requestMoveTrackDown();
  void requestMergeTracks();
  void requestLockTrack();
  void requestUnlockTrack();
  void requestMuteTrack();
  void requestUnmuteTrack();
  void requestSoloTrack();
  void requestUnsoloTrack();
  void requestSetTrackColor();
  void requestSetTrackName();
  void requestSyncTracks();
  void requestToggleTrackLinking();
  void requestInsertGap();
  void requestDeleteGap();
  void requestRippleDeleteGap();
  void requestCloseGap();
  void requestSnapToGrid();
  void requestSnapToFrames();
  void requestSnapToMarkers();
  void requestSnapToClips();
  void requestSetInPoint();
  void requestSetOutPoint();
  void requestClearInPoint();
  void requestClearOutPoint();
  void requestClearInOutPoints();
  void requestGoToInPoint();
  void requestGoToOutPoint();
  void requestSelectInOutPoints();
  void requestRippleSelectInOutPoints();
  void requestZoomToInOutPoints();

  // --- EFFECTS SIGNALS ---
  void requestApplyColorCorrection();
  void requestApplyLUT();
  void requestApplyHDRTools();
  void requestApplyScopes();
  void requestApplyKeyer();
  void requestApplySpillSuppressor();
  void requestApplyTracker();
  void requestApplyStabilizer();
  void requestApplyTransform();
  void requestApplyCrop();
  void requestApplyBlur();
  void requestApplySharpen();
  void requestApplyGlow();
  void requestApplyFade();
  void requestApplyWipe();
  void requestApplySlide();
  void requestApplyPush();
  void requestApplyCrossDissolve();
  void requestApplyDipToBlack();
  void requestApplyDipToWhite();
  void requestApplyFilmDissolve();
  void requestApplyAudioTransition();
  void requestApplyAudioFadeIn();
  void requestApplyAudioFadeOut();
  void requestApplyAudioCrossfade();
  void requestApplyAudioDucking();
  void requestApplyNoiseReduction();
  void requestApplyEQ();
  void requestApplyCompressor();
  void requestApplyLimiter();
  void requestApplyReverb();
  void requestApplyDelay();
  void requestApplyChorus();
  void requestApplyFlanger();
  void requestApplyPhaser();
  void requestApplyDistortion();
  void requestApplyPitchShift();
  void requestApplyTimeStretch();
  void requestApplyVocalRemover();
  void requestApplyPanning();
  void requestApplyStereoWidth();
  void requestApplyKeyframeAnimation();
  void requestApplyMotionBlur();
  void requestApplyOpticalFlow();
  void requestApplyNeuralEnhance();
  void requestApplyNoise();
  void requestApplyGrain();
  void requestApplyVignette();
  void requestApplyChromaticAberration();
  void requestApplyLensDistortion();
  void requestApplyDepthOfField();
  void requestApplyColorGrading();
  void requestApplyLookTable();
  void requestApplyCustomShader();

  // --- TITLE & GRAPHICS SIGNALS ---
  void requestNewTitle();
  void requestEditTitle();
  void requestDuplicateTitle();
  void requestDeleteTitle();
  void requestImportTitleTemplate();
  void requestExportTitleTemplate();
  void requestAddTextLayer();
  void requestAddShapeLayer();
  void requestAddImageLayer();
  void requestAddVectorLayer();
  void requestBringToFront();
  void requestSendToBack();
  void requestBringForward();
  void requestSendBackward();
  void requestAlignLeft();
  void requestAlignRight();
  void requestAlignCenter();
  void requestAlignTop();
  void requestAlignBottom();
  void requestAlignMiddle();
  void requestDistributeHorizontal();
  void requestDistributeVertical();
  void requestMatchPosition();
  void requestMatchScale();
  void requestMatchRotation();
  void requestMatchOpacity();
  void requestGroupLayers();
  void requestUngroupLayers();
  void requestLockLayer();
  void requestUnlockLayer();
  void requestHideLayer();
  void requestShowLayer();

  // --- AUDIO SIGNALS ---
  void requestAudioGain();
  void requestAudioNormalize();
  void requestAudioLevels();
  void requestAudioPan();
  void requestAudioBalance();
  void requestAudioTrackColor();
  void requestAudioRender();
  void requestAudioReplace();
  void requestAudioSync();
  void requestAudioSceneDetection();

  // --- COLOR SIGNALS ---
  void requestColorPrimaryCorrection();
  void requestColorSecondaryCorrection();
  void requestColorWheels();
  void requestColorCurves();
  void requestColorLUT();
  void requestColorKeyer();
  void requestColorQualifier();
  void requestColorWindow();
  void requestColorPowerWindow();
  void requestColorTracker();
  void requestColorStabilizer();
  void requestColorRender();
  void requestColorSnapshot();
  void requestColorMatch();
  void requestColorBalance();
  void requestColorTemperature();
  void requestColorTint();
  void requestColorSaturation();
  void requestColorContrast();
  void requestColorShadows();
  void requestColorMidtones();
  void requestColorHighlights();
  void requestColorLog();
  void requestColorHDR();

  // --- REVIEW SIGNALS ---
  void requestAddMarker();
  void requestDeleteMarker();
  void requestGotoMarker();
  void requestAddComment();
  void requestAddNote();
  void requestAddToDo();
  void requestSubmitFeedback();
  void requestExportFeedback();
  void requestReviewMode();
  void requestComparisonView();
  void requestSplitView();

  // --- TOOLS SIGNALS ---
  void requestSelectionTool();
  void requestRazorTool();
  void requestRollTool();
  void requestRippleTool();
  void requestSlipTool();
  void requestSlideTool();
  void requestPenTool();
  void requestHandTool();
  void requestZoomTool();
  void requestCropTool();
  void requestMaskTool();
  void requestTextTool();

  // --- WINDOW SIGNALS ---
  void requestNewWindow();
  void requestCloseWindow();
  void requestToggleDock();
  void requestResetWindowLayout();
  void requestFullScreenWindow();
  void requestMinimizeWindow();
  void requestMaximizeWindow();

  // --- HELP SIGNALS ---
  void requestDocumentation();
  void requestTutorials();
  void requestKeyboardShortcutsHelp();
  void requestCommunityForums();
  void requestReportIssue();
  void requestFeatureRequest();
  void requestCheckForUpdates();
  void requestAbout();
  void requestSystemInfo();

private:
  void setupDefaultActions();
  void setupFileActions();
  void setupEditActions();
  void setupViewActions();
  void setupClipActions();
  void setupTimelineActions();
  void setupEffectsActions();
  void setupTitleGraphicsActions();
  void setupAudioActions();
  void setupColorActions();
  void setupReviewActions();
  void setupToolsActions();
  void setupWindowActions();
  void setupHelpActions();
  void registerSubmenuMeta(const QString &menuPath, const QString &icon,
                           const QString &description, const QString &shortcut,
                           bool enabled);

  XylaActionManager *m_actionManager{nullptr};
  std::vector<XylaMenuItemData> m_menuStructure;
  QHash<QString, std::function<void()>> m_actionCallbacks;
  QVariantList m_cachedMenuTree;
  QHash<QString, QVariantMap> m_submenuMeta;
};

} // namespace xyla
