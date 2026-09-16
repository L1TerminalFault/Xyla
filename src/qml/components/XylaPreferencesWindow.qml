import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: settingsWindow
    width: 1300
    height: 900
    visible: false
    title: "Xyla Preferences"
    color: "#121212"

    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowSystemMenuHint | Qt.WindowMinimizeButtonHint | Qt.WindowCloseButtonHint

    property int selectedPage: 0
    property int activeCategoryIndex: 0

    readonly property var settingsList: [
        {
            name: "General",
            icon: "clear-all.svg",
            sections: [
                {
                    title: "Application Behavior & Lifecycle",
                    items: [
                        { type: "select", label: "Application Language", description: "Select the display language for the application interface.", value: "System Default", options: ["System Default", "English", "Spanish", "Japanese", "German"], callback: function(val) { console.log("Language changed to:", val) } },
                        { type: "select", label: "Startup Behavior", description: "Choose what action to take immediately when launching the application.", value: "Open Last Project", options: ["Open Project Manager", "Open Last Project", "Create New Project", "Show Dashboard"], callback: function(val) { console.log("Startup behavior set to:", val) } },
                        { type: "input", label: "Default Project Location", description: "Directory path where new projects will be created by default.", value: "/home/user/XylaProjects", callback: function(val) { console.log("Default project location set to:", val) } },
                        { type: "select", label: "Auto-Save Frequency", description: "Interval at which project progress snapshots are automatically saved to disk.", value: "5 minutes", options: ["Disabled", "1 minute", "5 minutes", "15 minutes", "30 minutes", "60 minutes"], callback: function(val) { console.log("Auto-save frequency set to:", val) } },
                        { type: "select", label: "Auto-Save History Limit", description: "Maximum number of retained auto-save backup files per project.", value: "20 snapshots", options: ["5 snapshots", "10 snapshots", "20 snapshots", "50 snapshots", "100 snapshots"], callback: function(val) { console.log("Auto-save limit set to:", val) } },
                        { type: "input", label: "Auto-Save Backup Location", description: "Storage location for auto-save files relative to project or system.", value: "Default Project Folder", callback: function(val) { console.log("Auto-save backup location set to:", val) } },
                        { type: "select", label: "Maximum Undo Levels", description: "Number of previous actions retained in the undo stack history.", value: "100 steps", options: ["10 steps", "50 steps", "100 steps", "250 steps", "500 steps"], callback: function(val) { console.log("Max undo levels set to:", val) } },
                        { type: "select", label: "Undo Memory Cache Limit", description: "Maximum RAM allocated to storing edit undo states.", value: "2048 MB", options: ["512 MB", "1024 MB", "2048 MB", "4096 MB", "8192 MB"], callback: function(val) { console.log("Undo cache limit set to:", val) } },
                        { type: "select", label: "Timecode Display Format", description: "Primary timecode representation system across monitors and timelines.", value: "Timecode (HH:MM:SS:FF)", options: ["Timecode (HH:MM:SS:FF)", "Frames", "Feet + Frames (35mm/16mm)"], callback: function(val) { console.log("Timecode format set to:", val) } },
                        { type: "toggle", label: "Drop-Frame Timecode Support", description: "Enable drop-frame adjustments for standard NTSC frame rates (29.97 / 59.94 fps).", value: false, callback: function(val) { console.log("Drop-frame support set to:", val) } },
                        { type: "select", label: "Double-Click Project Item Action", description: "Action triggered when double-clicking assets in the project bin.", value: "Open in Source Monitor", options: ["Open in Source Monitor", "Open in Timeline", "Open in New Window"], callback: function(val) { console.log("Double-click action set to:", val) } },
                        { type: "select", label: "Timeline Clip Selection Rule", description: "Determines whether video and linked audio clips are selected together.", value: "Select Audio/Video Linked", options: ["Select Track Independently"], callback: function(val) { console.log("Clip selection rule set to:", val) } },
                        { type: "select", label: "Mouse Wheel Zoom Anchor", description: "Focal point reference used when zooming in or out on the timeline.", value: "Mouse Pointer Position", options: ["Playhead Position", "Mouse Pointer Position", "Timeline Center"], callback: function(val) { console.log("Zoom anchor set to:", val) } },
                        { type: "select", label: "Background Rendering Throttle", description: "Resource priority reserved for background rendering tasks.", value: "Normal", options: ["Low (Background)", "Normal", "High (Aggressive)", "Unlimited"], callback: function(val) { console.log("Background rendering throttle set to:", val) } },
                        { type: "toggle", label: "Telemetry & Crash Reporting", description: "Send anonymous crash reports and operational usage metrics to help improve stability.", value: false, callback: function(val) { console.log("Telemetry enabled:", val) } },
                        { type: "toggle", label: "Check for Updates on Startup", description: "Automatically verify if a new version of the application is available on launch.", value: true, callback: function(val) { console.log("Check for updates enabled:", val) } },
                        { type: "toggle", label: "Clear Cache on Exit", description: "Automatically purge temporary render and thumbnail caches upon application close.", value: false, callback: function(val) { console.log("Clear cache on exit enabled:", val) } }
                    ]
                }
            ]
        },
        {
            name: "User Interface",
            icon: "palette.svg",
            sections: [
                {
                    title: "Appearance & Layout",
                    items: [
                        { type: "select", label: "Global Theme / Skin", description: "Visual color palette and component styling scheme.", value: "Dark Modern", options: ["Dark Modern", "Classic Gray", "Midnight Blue", "High Contrast"], callback: function(val) { console.log("Theme changed to:", val) } },
                        { type: "input", label: "Accent & Highlight Color", description: "Primary visual color used for selection states, playheads, and active controls.", value: "#007ACC", callback: function(val) { console.log("Accent color changed to:", val) } },
                        { type: "select", label: "Interface Scaling / DPI", description: "Global scale factor multiplier for high-density display displays.", value: "Auto-detect", options: ["100%", "125%", "150%", "200%", "Auto-detect"], callback: function(val) { console.log("Interface scaling set to:", val) } },
                        { type: "select", label: "Panel Snapping Distance", description: "Proximity threshold in pixels for docking panels to align.", value: "10px", options: ["5px", "10px", "15px", "20px", "30px"], callback: function(val) { console.log("Panel snapping distance set to:", val) } },
                        { type: "toggle", label: "Lock Workspace Layout", description: "Prevent accidental dragging, floating, or closing of dockable ui panels.", value: false, callback: function(val) { console.log("Lock workspace set to:", val) } },
                        { type: "input", label: "Tooltip Hover Delay", description: "Hover time before displaying operational button tooltips.", value: "500ms", callback: function(val) { console.log("Tooltip hover delay set to:", val) } },
                        { type: "select", label: "Timeline Waveform Style", description: "Rendering style for audio track waveforms on timeline clips.", value: "Standard Filled", options: ["Standard Filled", "Rectified", "Logarithmic", "Solid Line"], callback: function(val) { console.log("Waveform style set to:", val) } }
                    ]
                },
                {
                    title: "Monitors & Overlays",
                    items: [
                        { type: "select", label: "Viewport Background Color", description: "Canvas background behind letterboxed video footage in monitors.", value: "Dark Gray", options: ["Black", "Dark Gray", "Checkerboard Transparency", "Custom"], callback: function(val) { console.log("Viewport background color set to:", val) } },
                        { type: "toggle", label: "Show Dropped Frame Indicator", description: "Display a visual warning when real-time video playback drops frames.", value: true, callback: function(val) { console.log("Show dropped frame indicator set to:", val) } },
                        { type: "select", label: "Title Safe Area Guide", description: "Overlay margin guides to ensure text remains inside TV display bounds.", value: "80% / 90%", options: ["Disabled", "80% / 90%", "85% / 93%", "Custom Ratio"], callback: function(val) { console.log("Title safe guide set to:", val) } }
                    ]
                }
            ]
        },
        {
            name: "Media & Cache",
            icon: "folder.svg",
            sections: [
                {
                    title: "Storage & Ingestion",
                    items: [
                        { type: "input", label: "Primary Cache / Scratch Disk", description: "Storage location for rendered timeline previews, peak files, and conform data.", value: "/home/user/.cache/xyla", callback: function(val) { console.log("Primary cache path set to:", val) } },
                        { type: "toggle", label: "Auto-Proxy Generation Rule", description: "Automatically create low-resolution lightweight proxies upon media import.", value: false, callback: function(val) { console.log("Auto-proxy generation set to:", val) } },
                        { type: "select", label: "Media Cache Size Threshold", description: "Storage limit for cache directory before triggering cleanup warnings.", value: "100 GB", options: ["10 GB", "50 GB", "100 GB", "500 GB", "1000 GB"], callback: function(val) { console.log("Cache size threshold set to:", val) } },
                        { type: "select", label: "Auto-Purge Cache Age Limit", description: "Unused cache files older than this duration are automatically deleted.", value: "30 days", options: ["Never", "1 day", "7 days", "30 days", "90 days", "365 days"], callback: function(val) { console.log("Auto-purge age limit set to:", val) } },
                        { type: "input", label: "Still Image Default Duration", description: "Default timeline clip length applied when importing still graphics.", value: "5.0s", callback: function(val) { console.log("Still image default duration set to:", val) } },
                        { type: "select", label: "Relink Search Depth", description: "Search directory recursion level when attempting to locate missing media files.", value: "Subfolders Only", options: ["Exact Match Only", "Subfolders Only", "Deep Recursive Search"], callback: function(val) { console.log("Relink search depth set to:", val) } }
                    ]
                },
                {
                    title: "Proxy Defaults",
                    items: [
                        { type: "select", label: "Proxy Resolution Format", description: "Scaling target for automatically generated proxy media.", value: "1080p ProRes Proxy", options: ["720p H.264", "1080p H.264", "1080p ProRes Proxy", "Half Resolution Native"], callback: function(val) { console.log("Proxy resolution format set to:", val) } },
                        { type: "input", label: "Proxy Cache Directory", description: "Folder destination reserved specifically for generated proxy media files.", value: "/home/user/.cache/xyla/proxies", callback: function(val) { console.log("Proxy cache directory set to:", val) } }
                    ]
                }
            ]
        },
        {
            name: "Hardware & Performance",
            icon: "cpu.svg",
            sections: [
                {
                    title: "GPU & Playback",
                    items: [
                        { type: "select", label: "Hardware Acceleration Engine", description: "Graphics API used for timeline effects processing, transitions, and scaling.", value: "Auto", options: ["Auto", "CUDA", "Metal", "Vulkan", "OpenCL", "Software Only"], callback: function(val) { console.log("Hardware acceleration engine set to:", val) } },
                        { type: "select", label: "GPU Device Selection", description: "Select specific graphics hardware for intensive node rendering.", value: "Auto-select", options: ["GPU 0", "GPU 1", "All Available", "Auto-select"], callback: function(val) { console.log("GPU device selection set to:", val) } },
                        { type: "input", label: "RAM Allocation Reserve", description: "Amount of system RAM strictly reserved for background OS services.", value: "4 GB", callback: function(val) { console.log("RAM allocation reserve set to:", val) } },
                        { type: "toggle", label: "Dynamic Playback Resolution", description: "Lower real-time playback resolution automatically if frames begin dropping.", value: true, callback: function(val) { console.log("Dynamic playback resolution set to:", val) } },
                        { type: "select", label: "External Video Monitoring", description: "Route video preview output to a dedicated hardware display adapter.", value: "Disabled", options: ["Disabled", "Primary Screen", "Blackmagic/AJA DeckLink"], callback: function(val) { console.log("External video monitoring set to:", val) } },
                        { type: "toggle", label: "Audio Scrubbing During Drag", description: "Play short audio fragments while dragging the timeline playhead.", value: true, callback: function(val) { console.log("Audio scrubbing set to:", val) } },
                        { type: "input", label: "Pre-roll / Post-roll Duration", description: "Playback padding added before and after loop ranges or cut points.", value: "2.0s", callback: function(val) { console.log("Pre/post roll duration set to:", val) } }
                    ]
                },
                {
                    title: "Hardware Codecs & Decoding",
                    items: [
                        { type: "toggle", label: "Hardware Accelerated H.264/HEVC Decoding", description: "Utilize dedicated GPU media engines to decode compressed video formats.", value: true, callback: function(val) { console.log("Hardware decoding enabled:", val) } },
                        { type: "select", label: "Max Render Worker Threads", description: "Limit max CPU processing threads assigned to active tasks.", value: "Auto", options: ["Auto", "2 Threads", "4 Threads", "8 Threads", "16 Threads"], callback: function(val) { console.log("Max render worker threads set to:", val) } }
                    ]
                }
            ]
        },
        {
            name: "Timeline & Editing",
            icon: "timeline.svg",
            sections: [
                {
                    title: "Sequence Defaults",
                    items: [
                        { type: "select", label: "Default Sequence Frame Rate", description: "Standard frame rate assigned to newly created empty sequences.", value: "24", options: ["23.976", "24", "25", "29.97", "30", "50", "59.94", "60"], callback: function(val) { console.log("Default frame rate set to:", val) } },
                        { type: "select", label: "Default Sequence Resolution", description: "Canvas dimensions assigned to newly created empty sequences.", value: "1080p", options: ["720p", "1080p", "4K UHD", "4K DCI", "8K"], callback: function(val) { console.log("Default sequence resolution set to:", val) } },
                        { type: "select", label: "Timeline Snapping Magnetism", description: "Pixel distance threshold where edit points magnetize and snap.", value: "10px", options: ["5px", "10px", "15px", "20px", "25px"], callback: function(val) { console.log("Timeline snapping distance set to:", val) } },
                        { type: "input", label: "Default Transition Durations", description: "Length applied when adding standard video/audio crossfades.", value: "1.0s", callback: function(val) { console.log("Default transition duration set to:", val) } },
                        { type: "input", label: "Default Track Layout", description: "Track structure automatically populated in new timelines.", value: "V1-V3, A1-A6", callback: function(val) { console.log("Default track layout set to:", val) } },
                        { type: "toggle", label: "Ripple Edit Behavior", description: "Shift downstream clips automatically when trimming or deleting media.", value: true, callback: function(val) { console.log("Ripple edit behavior set to:", val) } }
                    ]
                },
                {
                    title: "Editing Operations",
                    items: [
                        { type: "select", label: "J-K-L Shuttle Speed Multiplier", description: "Speed stepping scale when using shuttle playback keybindings.", value: "2x / 4x / 8x / 16x", options: ["1.5x / 3x / 6x", "2x / 4x / 8x / 16x", "2x / 5x / 10x"], callback: function(val) { console.log("Shuttle speed multiplier set to:", val) } },
                        { type: "toggle", label: "Maintain Pitch During Fast Scrubbing", description: "Correct audio pitch shift when shuttling at accelerated speeds.", value: true, callback: function(val) { console.log("Maintain pitch set to:", val) } }
                    ]
                }
            ]
        },
        {
            name: "Color Management",
            icon: "color-filter.svg",
            sections: [
                {
                    title: "Color Workspaces & LUTs",
                    items: [
                        { type: "select", label: "Working Color Space", description: "Internal working color space for node tree calculations and composite operations.", value: "Rec.709", options: ["Rec.709", "Rec.2020", "ACEScg", "DaVinci Wide Gamut"], callback: function(val) { console.log("Working color space set to:", val) } },
                        { type: "select", label: "Display Color Profile", description: "Monitored display transform applied to software viewport windows.", value: "sRGB", options: ["sRGB", "Display P3", "Rec.709", "System ICC Profile"], callback: function(val) { console.log("Display color profile set to:", val) } },
                        { type: "input", label: "Custom 3D LUT Folder Location", description: "Search path directory for user-imported 3D LUT look-up table files.", value: "/home/user/.local/share/xyla/luts", callback: function(val) { console.log("Custom LUT directory set to:", val) } },
                        { type: "select", label: "Color Scope Precision", description: "Sampling rate precision for Video Scopes (Histogram, Vectorscope, Waveform).", value: "Medium", options: ["Low (Fast)", "Medium", "High (Accurate)", "Realtime Maximum"], callback: function(val) { console.log("Color scope precision set to:", val) } }
                    ]
                }
            ]
        },
        {
            name: "Audio",
            icon: "volume.svg",
            sections: [
                {
                    title: "Audio Routing & Engine",
                    items: [
                        { type: "select", label: "Audio Device Driver API", description: "Low-level audio platform subsystem layer for sound input and output.", value: "System Default", options: ["System Default", "CoreAudio (macOS)", "WASAPI/ASIO (Windows)", "PipeWire/ALSA"], callback: function(val) { console.log("Audio driver API set to:", val) } },
                        { type: "select", label: "Master Output Routing", description: "Primary hardware audio channel destination for timeline monitoring.", value: "System Default", options: ["System Default", "Headphone Jack", "Audio Interface 1/2"], callback: function(val) { console.log("Master output routing set to:", val) } },
                        { type: "select", label: "Microphone Input Routing", description: "Default input device assigned for voiceover track recordings.", value: "None", options: ["None", "Built-in Mic", "USB Interface Input"], callback: function(val) { console.log("Microphone input routing set to:", val) } },
                        { type: "select", label: "Sample Rate", description: "Audio engine operating frequency for mix processing and sampling.", value: "48 kHz", options: ["44.1 kHz", "48 kHz", "96 kHz"], callback: function(val) { console.log("Sample rate set to:", val) } },
                        { type: "select", label: "Audio Buffer Size / Latency", description: "Buffer frame size balancing hardware latency against processing stability.", value: "512", options: ["128", "256", "512", "1024", "2048"], callback: function(val) { console.log("Audio buffer size set to:", val) } }
                    ]
                },
                {
                    title: "Plugins & Processing",
                    items: [
                        { type: "input", label: "VST3 Plugin Search Path", description: "Directory location scanned for third-party audio processing plugins.", value: "/usr/lib/vst3", callback: function(val) { console.log("VST3 search path set to:", val) } },
                        { type: "button", label: "Rescan Audio Plugins", description: "Trigger an immediate scan to identify newly installed VST3/AudioUnit modules.", buttonText: "Run Plugin Scan", callback: function() { console.log("Triggering audio plugin scan...") } },
                        { type: "select", label: "Default Pan Law", description: "Attenuation compensation profile applied to center-panned mono channels.", value: "-3 dB Center", options: ["0 dB Flat", "-3 dB Center", "-4.5 dB Center", "-6 dB Center"], callback: function(val) { console.log("Default pan law set to:", val) } }
                    ]
                }
            ]
        },
        {
            name: "AI & Speech",
            icon: "sparkles.svg",
            sections: [
                {
                    title: "Transcription & Models",
                    items: [
                        { type: "select", label: "Speech-to-Text Model Precision", description: "Select neural network model complexity for offline automated subtitles.", value: "Base", options: ["Tiny (Fastest)", "Base", "Small", "Medium", "Large-v3 (Most Accurate)"], callback: function(val) { console.log("Speech-to-Text model precision set to:", val) } },
                        { type: "input", label: "ONNX / Whisper Model Directory", description: "Path where speech transcription model weights are saved.", value: "/home/user/.local/share/xyla/models", callback: function(val) { console.log("Whisper model directory set to:", val) } },
                        { type: "select", label: "AI Acceleration Execution Provider", description: "Hardware device driver utilized for local AI model inference.", value: "Auto", options: ["Auto", "CPU (OpenVINO)", "GPU (CUDA/TensorRT)", "DirectML"], callback: function(val) { console.log("AI execution provider set to:", val) } },
                        { type: "toggle", label: "Auto-Generate Speaker Markers", description: "Automatically classify and label distinct voices during text transcription.", value: true, callback: function(val) { console.log("Auto-generate speaker markers set to:", val) } }
                    ]
                }
            ]
        },
        {
            name: "Shortcuts",
            icon: "keyboard.svg",
            sections: [
                {
                    title: "Keybindings",
                    items: [
                        { type: "select", label: "Active Keymap Schema", description: "Preset keyboard layout mimicking common editing suites.", value: "Default Xyla", options: ["Default Xyla", "Premiere Pro Style", "DaVinci Resolve Style", "Final Cut Pro Style"], callback: function(val) { console.log("Active keymap schema set to:", val) } },
                        { type: "input", label: "Command Search Filter", description: "Type action names or keys to filter active application bindings.", value: "", callback: function(val) { console.log("Command search filter set to:", val) } },
                        { type: "button", label: "Custom Shortcut Import/Export", description: "Save or load customized keyboard shortcut configuration files.", buttonText: "Export JSON/XML", callback: function() { console.log("Triggering shortcut configuration export...") } }
                    ]
                }
            ]
        },
        {
            name: "Export",
            icon: "file-export.svg",
            sections: [
                {
                    title: "Rendering & Delivery",
                    items: [
                        { type: "input", label: "Default Export Destination", description: "Fallback output directory selected when opening export workflows.", value: "/home/user/Videos", callback: function(val) { console.log("Default export destination set to:", val) } },
                        { type: "select", label: "Default Render Format / Codec", description: "Preferred default file container and compression video format.", value: "MP4 (H.264)", options: ["MP4 (H.264)", "QuickTime (ProRes)", "WebM (VP9/AV1)"], callback: function(val) { console.log("Default render format set to:", val) } },
                        { type: "select", label: "Bitrate Encoding Strategy", description: "Default rate control strategy used during final render jobs.", value: "VBR 2-Pass", options: ["CBR (Constant)", "VBR 1-Pass", "VBR 2-Pass", "Constant Quality (CQ/CRF)"], callback: function(val) { console.log("Bitrate encoding strategy set to:", val) } },
                        { type: "select", label: "Post-Render Action", description: "Automatic action triggered upon finishing queued render exports.", value: "None", options: ["None", "Play File", "Open File Location", "Shut Down Computer"], callback: function(val) { console.log("Post-render action set to:", val) } },
                        { type: "select", label: "Render Conflict Behavior", description: "Action taken if an output file with the same name already exists.", value: "Auto-increment filename", options: ["Overwrite", "Auto-increment filename", "Prompt User"], callback: function(val) { console.log("Render conflict behavior set to:", val) } }
                    ]
                }
            ]
        }
    ]
    // readonly property var settingsList: [
    //     {
    //         name: "General",
    //         sections: [
    //             {
    //                 title: "Application Behavior & Lifecycle",
    //                 items: [
    //                     { type: "select", label: "Application Language", value: "System Default", options: ["System Default", "English", "Spanish", "Japanese", "German"] },
    //                     { type: "select", label: "Startup Behavior", value: "Open Last Project", options: ["Open Project Manager", "Open Last Project", "Create New Project", "Show Dashboard"] },
    //                     { type: "input", label: "Default Project Location", value: "/home/user/XylaProjects" },
    //                     { type: "select", label: "Auto-Save Frequency", value: "5 minutes", options: ["Disabled", "1 minute", "5 minutes", "15 minutes", "30 minutes", "60 minutes"] },
    //                     { type: "select", label: "Auto-Save History Limit", value: "20 snapshots", options: ["5 snapshots", "10 snapshots", "20 snapshots", "50 snapshots", "100 snapshots"] },
    //                     { type: "input", label: "Auto-Save Backup Location", value: "Default Project Folder" },
    //                     { type: "select", label: "Maximum Undo Levels", value: "100 steps", options: ["10 steps", "50 steps", "100 steps", "250 steps", "500 steps"] },
    //                     { type: "select", label: "Undo Memory Cache Limit", value: "2048 MB", options: ["512 MB", "1024 MB", "2048 MB", "4096 MB", "8192 MB"] },
    //                     { type: "select", label: "Timecode Display Format", value: "Timecode (HH:MM:SS:FF)", options: ["Timecode (HH:MM:SS:FF)", "Frames", "Feet + Frames (35mm/16mm)"] },
    //                     { type: "toggle", label: "Drop-Frame Timecode Support", value: false },
    //                     { type: "select", label: "Double-Click Project Item Action", value: "Open in Source Monitor", options: ["Open in Source Monitor", "Open in Timeline", "Open in New Window"] },
    //                     { type: "select", label: "Timeline Clip Selection Rule", value: "Select Audio/Video Linked", options: ["Select Audio/Video Linked", "Select Track Independently"] },
    //                     { type: "select", label: "Mouse Wheel Zoom Anchor", value: "Mouse Pointer Position", options: ["Playhead Position", "Mouse Pointer Position", "Timeline Center"] },
    //                     { type: "select", label: "Background Rendering Throttle", value: "Normal", options: ["Low (Background)", "Normal", "High (Aggressive)", "Unlimited"] },
    //                     { type: "toggle", label: "Telemetry & Crash Reporting", value: false },
    //                     { type: "toggle", label: "Check for Updates on Startup", value: true },
    //                     { type: "toggle", label: "Clear Cache on Exit", value: false }
    //                 ]
    //             }
    //         ]
    //     },
    //     {
    //         name: "User Interface",
    //         sections: [
    //             {
    //                 title: "Appearance & Layout",
    //                 items: [
    //                     { type: "select", label: "Global Theme / Skin", value: "Dark Modern", options: ["Dark Modern", "Classic Gray", "Midnight Blue", "High Contrast"] },
    //                     { type: "input", label: "Accent & Highlight Color", value: "#007ACC" },
    //                     { type: "select", label: "Interface Scaling / DPI", value: "Auto-detect", options: ["100%", "125%", "150%", "200%", "Auto-detect"] },
    //                     { type: "select", label: "Panel Snapping Distance", value: "10px", options: ["5px", "10px", "15px", "20px", "30px"] },
    //                     { type: "toggle", label: "Lock Workspace Layout", value: false },
    //                     { type: "input", label: "Tooltip Hover Delay", value: "500ms" },
    //                     { type: "select", label: "Timeline Waveform Style", value: "Standard Filled", options: ["Standard Filled", "Rectified", "Logarithmic", "Solid Line"] }
    //                 ]
    //             }
    //         ]
    //     },
    //     {
    //         name: "Media & Cache",
    //         sections: [
    //             {
    //                 title: "Storage & Ingestion",
    //                 items: [
    //                     { type: "input", label: "Primary Cache / Scratch Disk", value: "/home/user/.cache/xyla" },
    //                     { type: "toggle", label: "Auto-Proxy Generation Rule", value: false },
    //                     { type: "select", label: "Media Cache Size Threshold", value: "100 GB", options: ["10 GB", "50 GB", "100 GB", "500 GB", "1000 GB"] },
    //                     { type: "select", label: "Auto-Purge Cache Age Limit", value: "30 days", options: ["Never", "1 day", "7 days", "30 days", "90 days", "365 days"] },
    //                     { type: "input", label: "Still Image Default Duration", value: "5.0s" },
    //                     { type: "select", label: "Relink Search Depth", value: "Subfolders Only", options: ["Exact Match Only", "Subfolders Only", "Deep Recursive Search"] }
    //                 ]
    //             }
    //         ]
    //     },
    //     {
    //         name: "Hardware & Performance",
    //         sections: [
    //             {
    //                 title: "GPU & Playback",
    //                 items: [
    //                     { type: "select", label: "Hardware Acceleration Engine", value: "Auto", options: ["Auto", "CUDA", "Metal", "Vulkan", "OpenCL", "Software Only"] },
    //                     { type: "select", label: "GPU Device Selection", value: "Auto-select", options: ["GPU 0", "GPU 1", "All Available", "Auto-select"] },
    //                     { type: "input", label: "RAM Allocation Reserve", value: "4 GB" },
    //                     { type: "toggle", label: "Dynamic Playback Resolution", value: true },
    //                     { type: "select", label: "External Video Monitoring", value: "Disabled", options: ["Disabled", "Primary Screen", "Blackmagic/AJA DeckLink"] },
    //                     { type: "toggle", label: "Audio Scrubbing During Drag", value: true },
    //                     { type: "input", label: "Pre-roll / Post-roll Duration", value: "2.0s" }
    //                 ]
    //             }
    //         ]
    //     },
    //     {
    //         name: "Timeline & Editing",
    //         sections: [
    //             {
    //                 title: "Sequence Defaults",
    //                 items: [
    //                     { type: "select", label: "Default Sequence Frame Rate", value: "24", options: ["23.976", "24", "25", "29.97", "30", "50", "59.94", "60"] },
    //                     { type: "select", label: "Default Sequence Resolution", value: "1080p", options: ["720p", "1080p", "4K UHD", "4K DCI", "8K"] },
    //                     { type: "select", label: "Timeline Snapping Magnetism", value: "10px", options: ["5px", "10px", "15px", "20px", "25px"] },
    //                     { type: "input", label: "Default Transition Durations", value: "1.0s" },
    //                     { type: "input", label: "Default Track Layout", value: "V1-V3, A1-A6" },
    //                     { type: "toggle", label: "Ripple Edit Behavior", value: true }
    //                 ]
    //             }
    //         ]
    //     },
    //     {
    //         name: "Audio",
    //         sections: [
    //             {
    //                 title: "Audio Routing & Engine",
    //                 items: [
    //                     { type: "select", label: "Audio Device Driver API", value: "System Default", options: ["CoreAudio (macOS)", "WASAPI/ASIO (Windows)", "PipeWire/ALSA"] },
    //                     { type: "select", label: "Master Output Routing", value: "System Default", options: ["System Default", "Headphone Jack", "Audio Interface 1/2"] },
    //                     { type: "select", label: "Microphone Input Routing", value: "None", options: ["None", "Built-in Mic", "USB Interface Input"] },
    //                     { type: "select", label: "Sample Rate", value: "48 kHz", options: ["44.1 kHz", "48 kHz", "96 kHz"] },
    //                     { type: "select", label: "Audio Buffer Size / Latency", value: "512", options: ["128", "256", "512", "1024", "2048"] }
    //                 ]
    //             }
    //         ]
    //     },
    //     {
    //         name: "Shortcuts",
    //         sections: [
    //             {
    //                 title: "Keybindings",
    //                 items: [
    //                     { type: "select", label: "Active Keymap Schema", value: "Default Xyla", options: ["Default Xyla", "Premiere Pro Style", "DaVinci Resolve Style", "Final Cut Pro Style"] },
    //                     { type: "input", label: "Command Search Filter", value: "" },
    //                     { type: "button", label: "Custom Shortcut Import/Export", buttonText: "Export JSON/XML" }
    //                 ]
    //             }
    //         ]
    //     },
    //     {
    //         name: "Export",
    //         sections: [
    //             {
    //                 title: "Rendering & Delivery",
    //                 items: [
    //                     { type: "input", label: "Default Export Destination", value: "/home/user/Videos" },
    //                     { type: "select", label: "Default Render Format / Codec", value: "MP4 (H.264)", options: ["MP4 (H.264)", "QuickTime (ProRes)", "WebM (VP9/AV1)"] },
    //                     { type: "select", label: "Post-Render Action", value: "None", options: ["None", "Play File", "Open File Location", "Shut Down Computer"] },
    //                     { type: "select", label: "Render Conflict Behavior", value: "Auto-increment filename", options: ["Overwrite", "Auto-increment filename", "Prompt User"] }
    //                 ]
    //             }
    //         ]
    //     }
    // ]

    // ==========================================
    // Dynamic Control Components for SettingCard
    // ==========================================
    Component {
        id: selectComponent
        XylaSelect {
            // 1. Declare itemData on the component root
            property var itemData: null

            Layout.preferredWidth: 160
            implicitWidth: 160
            backgroundColor: "#252525"
            highlightedColor: "#2f2f2f"
            
            // 2. Guard property evaluations against initial null state
            model: itemData ? (itemData.options || []) : []
            tooltip: itemData ? (itemData.label || "") : ""
            currentIndex: (itemData && itemData.value !== undefined && model) 
                          ? Math.max(0, model.indexOf(itemData.value)) 
                          : 0

            onActivated: {
                if (itemData) {
                    itemData.value = model[currentIndex]
                }
            }
        }
    }

    Component {
        id: buttonComponent
        XylaTextButton {
            // 1. Declare itemData on the component root
            property var itemData: null

            // 2. Safe property access
            text: itemData ? (itemData.buttonText || "Action") : "Action"
            onClicked: {
                if (itemData && typeof itemData.onClicked === "function") {
                    itemData.onClicked()
                }
            }
        }
    }

Component {
        id: inputComponent
        Item {
            // Root Item container gets the size AND the itemData property
            width: 250
            height: 32

            property var itemData: null

            TextField {
                anchors.fill: parent

                text: parent.itemData ? (parent.itemData.value || "") : ""
                color: "#ffffff"
                font.pixelSize: 12
                leftPadding: 10
                rightPadding: 10
                selectByMouse: true
                
                background: Rectangle {
                    color: "#181818"
                    border.color: parent.activeFocus ? "#2555D3" : "#2d2d2d"
                    border.width: 1
                    radius: 6
                }

                onEditingFinished: {
                    if (parent.itemData) {
                        parent.itemData.value = text
                    }
                }
            }
        }
    }

    Component {
        id: switchComponent
        StyledSwitch {
            property var itemData: null
            checked: itemData ? Boolean(itemData.value) : false
            onToggled: {
                if (itemData) {
                    itemData.value = checked
                }
            }
        }
    }

    // ==========================================
    // Main UI Layout
    // ==========================================
    Rectangle {
        anchors.fill: parent
        color: "#121212"
        border.color: "#202020"
        border.width: 1
        radius: 10
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: "#ffffff"
        opacity: 0.08
    }

    Rectangle {
        id: titleBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 44
        color: "#181818"
        topLeftRadius: 10
        topRightRadius: 10
        border.color: "#202020"
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 8
            spacing: 10

            Image {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                source: "qrc:/assets/icons/settings.svg"
                sourceSize: Qt.size(18, 18)
                opacity: 0.92
            }

            Text {
                text: "Project Settings"
                color: "#ffffff"
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            Item {
                Layout.fillWidth: true
            }

            XylaIconButton {
                id: closeBtn
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 2
                tooltip: "Close"
                ghost: true
                iconSource: "qrc:/assets/icons/x.svg"
                onClicked: settingsWindow.close() 
            }
        }
    }

    Rectangle {
        anchors.top: titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "#202020"

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Navigation Sidebar
            Rectangle {
                Layout.preferredWidth: 246
                Layout.fillHeight: true
                color: "#1d1d1d"

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: "#303030"
                }

                Item {
                    anchors.fill: parent

                    ColumnLayout {
                        id: settingsNavColumn
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.topMargin: 18
                        anchors.bottomMargin: 16
                        spacing: 4

Text {
        id: preferencesTitle
        text: "Preferences"
        color: "#ffffff"
        font.pixelSize: 24
        font.weight: Font.DemiBold
        Layout.leftMargin: 12
        Layout.bottomMargin: 12

        opacity: 0.0

        Component.onCompleted: {
            fadeInAnimTitle.restart(); // Use restart() to guarantee it triggers
        }

        NumberAnimation {
            id: fadeInAnimTitle
            target: preferencesTitle
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

Repeater {
    id: settingsNavRepeater
    model: settingsWindow.settingsList

    delegate: Rectangle {
        id: navItem
        required property var modelData
        required property int index

        Layout.fillWidth: true
        Layout.preferredHeight: 40
        radius: 6

        // Set initial properties
        opacity: 0
        scale: 0.82
        transformOrigin: Item.Center
        transform: Translate { id: itemTranslation; y: 20 }

        // Helper function to reset properties and play animation
        function playEntry() {
            navItem.opacity = 0
            navItem.scale = 0.82
            itemTranslation.y = 20
            entryAnimation.restart()
        }

        // Trigger whenever settingsWindow becomes visible
        Connections {
            target: settingsWindow
            function onVisibleChanged() {
                if (settingsWindow.visible) {
                    navItem.playEntry()
                }
            }
        }

        // Optional: Trigger once on load in case the window is ALREADY visible on startup
        Component.onCompleted: {
            if (settingsWindow.visible) {
                navItem.playEntry()
            }
        }

        SequentialAnimation {
            id: entryAnimation

            // Stagger delay based on item index (35ms per item)
            PauseAnimation {
                duration: 120 + navItem.index * 55
            }

            // Animate opacity, Y-offset, and scale concurrently
            ParallelAnimation {
                NumberAnimation {
                    target: navItem
                    property: "opacity"
                    to: 1.0
                    duration: 280
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: navItem
                    property: "scale"
                    to: 1.0
                    duration: 350
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.3
                }

                NumberAnimation {
                    target: itemTranslation
                    property: "y"
                    to: 0
                    duration: 380
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.5 // Higher value gives a punchier upward overshoot recoil
                }
            }
        }

        color: settingsWindow.selectedPage === index ? "#2b2b2b" : navMouse.containsMouse ? "#252525" : "#1d1d1d"

        Behavior on color {
            ColorAnimation { duration: 100 }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 11

            Image {
                Layout.preferredWidth: 17
                Layout.preferredHeight: 17
                source: modelData.icon ? "qrc:/assets/icons/" + modelData.icon : "qrc:/assets/icons/settings.svg"
                sourceSize: Qt.size(17, 17)
                opacity: settingsWindow.selectedPage === index ? 1.0 : 0.72
            }

            Text {
                Layout.fillWidth: true
                text: modelData.name
                color: settingsWindow.selectedPage === index ? "#ffffff" : "#d0d0d0"
                font.pixelSize: 13
                font.weight: settingsWindow.selectedPage === index ? Font.Medium : Font.Normal
            }
        }

        MouseArea {
            id: navMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: settingsWindow.selectedPage = index
        }
    }
}

                        Item { Layout.fillHeight: true }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: "#303030"
                        }

                        Text {
                            Layout.leftMargin: 12
                            Layout.topMargin: 8
                            text: "Xyla Preferences"
                            color: "#777777"
                            font.pixelSize: 11
                        }
                    }

                    // Fluent-style Stretch Animating Pill
                    Rectangle {
                        id: selectionPill
                        width: 3
                        radius: 1.5
                        color: "#0078d4"
                        x: 12
                        z: 10

                        property Item targetItem: null
                        property real baseHeight: 16
                        property real pillY: 0
                        property real pillHeight: baseHeight

                        visible: targetItem !== null && opacity > 0
                        opacity: 0 // targetItem !== null ? 1.0 : 0.0
                        y: pillY
                        height: pillHeight

// onTargetItemChanged: {
//     if (targetItem !== null) {
//         fadeInAnim.restart();
//     } else {
//         opacity = 0; // Fade out instantly or normally when cleared
//     }
// }

Component.onCompleted: {
  fadeInAnim.start();
}

SequentialAnimation {
    id: fadeInAnim

    // Global delay before the pill starts appearing (e.g., 100ms)
    PauseAnimation { duration: 300 }

    NumberAnimation {
        target: selectionPill
        property: "opacity"
        to: 1.0
        duration: 120
        easing.type: Easing.OutCubic
    }
}

                        // Add this inside your selectionPill component
                        Connections {
                            target: selectionPill.targetItem
                            ignoreUnknownSignals: true

                            function onScaleChanged() {
                                if (selectionPill.targetItem) selectionPill.updatePosition(selectionPill.targetItem);
                            }
                            function onYChanged() {
                                if (selectionPill.targetItem) selectionPill.updatePosition(selectionPill.targetItem);
                            }
                        }

                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        SequentialAnimation {
                            id: pillAnim
                            property real startY: 0
                            property real targetY: 0
                            property real startHeight: selectionPill.baseHeight
                            property real distance: 0
                            property bool movingDown: true

                            onStarted: {
                                distance = Math.abs(targetY - startY);
                                movingDown = targetY > startY;
                            }

                            ParallelAnimation {
                                NumberAnimation {
                                    target: selectionPill
                                    property: "pillY"
                                    from: pillAnim.startY
                                    to: pillAnim.movingDown ? pillAnim.startY : pillAnim.targetY
                                    duration: 140
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: selectionPill
                                    property: "pillHeight"
                                    from: pillAnim.startHeight
                                    to: selectionPill.baseHeight + pillAnim.distance
                                    duration: 140
                                    easing.type: Easing.OutCubic
                                }
                            }

                            ParallelAnimation {
                                NumberAnimation {
                                    target: selectionPill
                                    property: "pillY"
                                    from: pillAnim.movingDown ? pillAnim.startY : pillAnim.targetY
                                    to: pillAnim.targetY
                                    duration: 40
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: selectionPill
                                    property: "pillHeight"
                                    from: selectionPill.baseHeight + pillAnim.distance
                                    to: selectionPill.baseHeight
                                    duration: 40
                                    easing.type: Easing.OutCubic
                                }
                            }

                            onFinished: {
                                selectionPill.pillY = targetY;
                                selectionPill.pillHeight = selectionPill.baseHeight;
                            }
                        }

                        function updatePosition(item) {
                            if (!item) return;

                            Qt.callLater(function () {
                                if (!item || !selectionPill.parent) return;

                                var p = item.mapToItem(selectionPill.parent, 0, 0);
                                var newY = p.y + (item.height - selectionPill.baseHeight) / 2;

                                if (targetItem === null) {
                                    targetItem = item;
                                    pillY = newY;
                                    pillHeight = baseHeight;
                                    return;
                                }

                                if (targetItem === item) {
                                    pillY = newY;
                                    return;
                                }

                                var currentY = pillY;
                                var currentHeight = pillHeight;

                                if (pillAnim.running) pillAnim.stop();

                                pillAnim.startY = currentY;
                                pillAnim.targetY = newY;
                                pillAnim.startHeight = currentHeight;

                                targetItem = item;
                                pillAnim.start();
                            });
                        }
                    }
                }

                Connections {
                    target: settingsWindow
                    function onSelectedPageChanged() {
                        Qt.callLater(function () {
                            var item = settingsNavRepeater.itemAt(settingsWindow.selectedPage);
                            if (item) selectionPill.updatePosition(item);
                        });
                    }
                }

                Component.onCompleted: {
                    Qt.callLater(function () {
                        var item = settingsNavRepeater.itemAt(0);
                        if (item) selectionPill.updatePosition(item);
                    });
                }
            }

            // Dynamic Pages Container
            Item {
                id: pagesContainer
                Layout.fillWidth: true
                Layout.fillHeight: true

                Repeater {
                    model: settingsWindow.settingsList

                    delegate: Flickable {
                        required property var modelData
                        required property int index
                        property var pageData: modelData // Alias to avoid scope shadowing
                        
                        anchors.fill: parent
                        visible: settingsWindow.selectedPage === index
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        contentWidth: width
                        contentHeight: pageColumn.implicitHeight + 64
                        interactive: contentHeight > height

                        ColumnLayout {
                            id: pageColumn
                            width: Math.max(parent.width - anchors.leftMargin * 2, 600)
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.leftMargin: 48
                            anchors.topMargin: 38
                            spacing: 24

                            // Page Title
Item {
    id: pageTitleContainer
    Layout.fillWidth: true
    Layout.preferredHeight: 38
    Layout.bottomMargin: 8
    clip: true

    property bool isActive: settingsWindow.selectedPage === index

    onIsActiveChanged: {
        if (isActive) {
            // Setup incoming title starting state (below + slightly scaled down)
            incomingTitle.text = pageData.name;
            incomingTitle.y = 28;
            incomingTitle.scale = 0.9;
            incomingTitle.opacity = 0.0;
            
            currentTitle.text = pageData.name; // temporary sync
            titleSlideAnim.restart();
        }
    }

    Component.onCompleted: {
        if (isActive) {
            currentTitle.text = pageData.name;
            currentTitle.y = 0;
            currentTitle.scale = 1.0;
            currentTitle.opacity = 1.0;
            incomingTitle.opacity = 0.0;
        }
    }

    // 1. Outgoing Title Text
    Text {
        id: currentTitle
        text: pageData.name
        color: "#ffffff"
        font.pixelSize: 28
        font.weight: Font.DemiBold
        y: 0
        scale: 1.0
        opacity: 1.0
        transformOrigin: Item.Left
    }

    // 2. Incoming Title Text (slides up with scale recoil)
    Text {
        id: incomingTitle
        text: pageData.name
        color: "#ffffff"
        font.pixelSize: 28
        font.weight: Font.DemiBold
        y: 28
        scale: 0.9
        opacity: 0.0
        transformOrigin: Item.Left
    }

    SequentialAnimation {
        id: titleSlideAnim

        ParallelAnimation {
            // Old title moves up, scales down slightly, and fades out
            NumberAnimation {
                target: currentTitle
                property: "y"
                to: -28
                duration: 250
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: currentTitle
                property: "scale"
                to: 0.95
                duration: 250
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: currentTitle
                property: "opacity"
                to: 0.0
                duration: 200
                easing.type: Easing.OutCubic
            }

            // New title slides up into place with scale recoil (OutBack) and fades in
            NumberAnimation {
                target: incomingTitle
                property: "y"
                to: 0
                duration: 340
                easing.type: Easing.OutBack
                easing.overshoot: 1.3
            }
            NumberAnimation {
                target: incomingTitle
                property: "scale"
                to: 1.0
                duration: 340
                easing.type: Easing.OutBack
                easing.overshoot: 1.3
            }
            NumberAnimation {
                target: incomingTitle
                property: "opacity"
                to: 1.0
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        // Clean up and reset roles behind the scenes
        ScriptAction {
            script: {
                currentTitle.text = incomingTitle.text;
                currentTitle.y = 0;
                currentTitle.scale = 1.0;
                currentTitle.opacity = 1.0;
                incomingTitle.opacity = 0.0;
                incomingTitle.y = 28;
                incomingTitle.scale = 0.9;
            }
        }
    }
}
// Item {
//     id: pageTitleContainer
//     Layout.fillWidth: true
//     Layout.preferredHeight: 38
//     Layout.bottomMargin: 8
//     clip: true
//
//     // Track which page index this specific delegate belongs to vs active page
//     property bool isActive: settingsWindow.selectedPage === index
//
//     onIsActiveChanged: {
//         if (isActive) {
//             // New page is coming in: set incoming text to the current page name, start below
//             incomingTitle.text = pageData.name;
//             incomingTitle.y = 28;
//             incomingTitle.opacity = 0.0;
//
//             // Outgoing text starts at center
//             currentTitle.text = pageData.name; // temporary safety
//             // Trigger the transition animation
//             titleSlideAnim.restart();
//         }
//     }
//
//     Component.onCompleted: {
//         if (isActive) {
//             currentTitle.text = pageData.name;
//             currentTitle.y = 0;
//             currentTitle.opacity = 1.0;
//             incomingTitle.opacity = 0.0;
//         }
//     }
//
//     // 1. Outgoing Title Text
//     Text {
//         id: currentTitle
//         text: pageData.name
//         color: "#ffffff"
//         font.pixelSize: 28
//         font.weight: Font.DemiBold
//         y: 0
//         opacity: 1.0
//     }
//
//     // 2. Incoming Title Text (slides up from below)
//     Text {
//         id: incomingTitle
//         text: pageData.name
//         color: "#ffffff"
//         font.pixelSize: 28
//         font.weight: Font.DemiBold
//         y: 28
//         opacity: 0.0
//     }
//
//     SequentialAnimation {
//         id: titleSlideAnim
//
//         ParallelAnimation {
//             // Old title moves up and fades out
//             NumberAnimation {
//                 target: currentTitle
//                 property: "y"
//                 to: -28
//                 duration: 250
//                 easing.type: Easing.OutCubic
//             }
//             NumberAnimation {
//                 target: currentTitle
//                 property: "opacity"
//                 to: 0.0
//                 duration: 200
//                 easing.type: Easing.OutCubic
//             }
//
//             // New title slides up into place and fades in
//             NumberAnimation {
//                 target: incomingTitle
//                 property: "y"
//                 to: 0
//                 duration: 250
//                 easing.type: Easing.OutCubic
//             }
//             NumberAnimation {
//                 target: incomingTitle
//                 property: "opacity"
//                 to: 1.0
//                 duration: 220
//                 easing.type: Easing.OutCubic
//             }
//         }
//
//         // Clean up and sync roles instantly when animation finishes
//         ScriptAction {
//             script: {
//                 currentTitle.text = incomingTitle.text;
//                 currentTitle.y = 0;
//                 currentTitle.opacity = 1.0;
//                 incomingTitle.opacity = 0.0;
//                 incomingTitle.y = 28;
//             }
//         }
//     }
// }

                            // Dynamic Sections
Repeater {
    model: pageData.sections

    delegate: ColumnLayout {
        id: sectionLayout
        required property var modelData
        required property int index
        property var sectionData: modelData 

        Layout.fillWidth: true
        spacing: 12

        // Section Title with Entry Animation
        Text {
            id: sectionTitle
            text: sectionData.title
            color: "#a8a8a8"
            font.pixelSize: 13
            font.weight: Font.Medium
            Layout.bottomMargin: 4

            opacity: 0
            scale: 0.82
            transformOrigin: Item.Center
            transform: Translate { id: titleTranslation; y: 20 }

            function playEntry() {
                sectionTitle.opacity = 0
                sectionTitle.scale = 0.82
                titleTranslation.y = 20
                titleAnim.restart()
            }

            Connections {
                target: settingsWindow
                function onVisibleChanged() {
                    if (settingsWindow.visible) sectionTitle.playEntry()
                }
            function onSelectedPageChanged() {
              if (settingsWindow.visible) sectionTitle.playEntry();
            }
            }

            Component.onCompleted: {
                if (settingsWindow.visible) sectionTitle.playEntry()
            }

            SequentialAnimation {
                id: titleAnim
                PauseAnimation {
                    // Stagger based on section index
                    duration: 120 + (sectionLayout.index * 70)
                }
                ParallelAnimation {
                    NumberAnimation { target: sectionTitle; property: "opacity"; to: 1.0; duration: 280; easing.type: Easing.OutCubic }
                    NumberAnimation { target: sectionTitle; property: "scale"; to: 1.0; duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                    NumberAnimation { target: titleTranslation; property: "y"; to: 0; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                }
            }
        }

        // Dynamic Setting Cards Repeater
        Repeater {
            model: sectionData.items

delegate: SettingCard {
    id: card
    required property var modelData
    required property int index
    property var itemData: modelData 

    title: itemData ? itemData.label : ""
    description: (itemData && itemData.description) ? itemData.description : ""

    opacity: 0
    scale: 0.82
    transformOrigin: Item.Center
    transform: Translate { id: cardTranslation; y: 20 }

    function playEntry() {
        card.opacity = 0
        card.scale = 0.82
        cardTranslation.y = 20
        cardAnim.restart()
    }

    // Wrap non-visual elements inside an Item to satisfy SettingCard's QQuickItem requirement
    Item {
        Connections {
            target: settingsWindow
            function onVisibleChanged() {
                if (settingsWindow.visible) card.playEntry();
            }
            function onSelectedPageChanged() {
              if (settingsWindow.visible) card.playEntry();
            }
        }

        Component.onCompleted: {
            if (settingsWindow.visible) card.playEntry()
        }

        SequentialAnimation {
            id: cardAnim
            PauseAnimation {
                duration: 120 + (sectionLayout.index * 70) + ((card.index + 1) * 45)
            }
            ParallelAnimation {
                NumberAnimation { target: card; property: "opacity"; to: 1.0; duration: 280; easing.type: Easing.OutCubic }
                NumberAnimation { target: card; property: "scale"; to: 1.0; duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                NumberAnimation { target: cardTranslation; property: "y"; to: 0; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2 }
            }
        }
    }

Loader {
        id: controlLoader
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        
        // Give the loader explicit bounds so the TextField respects maximum width and height
        // width: 300
        // height: 32

        sourceComponent: {
            if (!card.itemData || !card.itemData.type) return null;
            
            switch (card.itemData.type) {
                case "select": return selectComponent;
                case "input": return inputComponent;
                case "toggle":
                case "switch": return switchComponent;
                case "button": return buttonComponent;
                default: return null;
            }
        }

        Binding {
            target: controlLoader.item
            property: "itemData"
            value: card.itemData
            when: controlLoader.status === Loader.Ready
        }
    }
}
        }
    }
}
                        }
                    }
                }
            }
        }
    }

    component SettingCard: Rectangle {
        property string title: ""
        property string description: ""
        default property alias control: controlSlot.children

        Layout.fillWidth: true
        implicitHeight: 72
        radius: 8
        color: cardHoverHandler.hovered ? "#292929" : "#252525"
        border.color: "#333333"
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }

        HoverHandler {
            id: cardHoverHandler
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 14
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    text: title
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Text {
                    Layout.fillWidth: true
                    text: description
                    color: "#969696"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
            }

            Item {
                id: controlSlot
                
                implicitWidth: children[0] ? children[0].implicitWidth : 0
                implicitHeight: children[0] ? children[0].implicitHeight : 0
                
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    component StyledSwitch: Switch {
        id: control

        implicitWidth: 44
        implicitHeight: 24

        indicator: Rectangle {
            implicitWidth: 44
            implicitHeight: 24
            x: control.leftPadding
            y: parent.height / 2 - height / 2
            radius: 12
            color: control.checked ? "#11389F" : "#101010" // "#3a3a3a"
            border.color: control.checked ? "#11389F" : "#101010" // "#555555"
            border.width: control.checked ? 0 : 1

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            Rectangle {
                width: 18
                height: 18
                radius: 9
                y: 3
                x: control.checked ? parent.width - width - 3 : 3
                color: "#ffffff"

                Behavior on x {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        contentItem: Item {}
    }

    component StyledButton: Button {
        id: button

        property bool accent: false

        implicitWidth: Math.max(84, contentItem.implicitWidth + 28)
        implicitHeight: 34

        contentItem: Text {
            text: button.text
            color: button.accent ? "#ffffff" : "#eeeeee"
            font.pixelSize: 12
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 6
            color: button.accent ? (button.pressed ? "#0e2d80" : button.hovered ? "#1644bf" : "#11389F") : (button.pressed ? "#383838" : button.hovered ? "#303030" : "#292929")
            border.color: button.accent ? "#11389F" : "#454545"
            border.width: 1

            Behavior on color {
                ColorAnimation {
                    duration: 90
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            selectedPage = 0;
            Qt.callLater(function () {
                var item = settingsNavRepeater.itemAt(0);
                if (item)
                    selectionPill.updatePosition(item);
            });
        }
    }
}
