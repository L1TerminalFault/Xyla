import QtQuick
import QtQuick.Shapes

import Qt5Compat.GraphicalEffects

                    Item {
                        id: loadingState
                        anchors.fill: parent
                        visible: fileSystemModel.loading && !viewContainer.suppressMotion
                        z: 50

                        onVisibleChanged: {
                            if (visible) {
                                spinAnim.start();
                            } else {
                                spinAnim.stop();
                            }
                        }

                        Item {
                            id: spinner
                            anchors.centerIn: parent
                            width: 64
                            height: 64

                            // Base Ring with Gradient Mask
                            Item {
                                id: ringContainer
                                anchors.fill: parent

                                // 1. The #2d2d2d Circle Base
                                Rectangle {
                                    id: ringShape
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: "#2d2d2d"
                                    border.width: 6
                                    visible: false // Hidden, used only as a source for opacity masking
                                }

                                Rectangle {
                                    width: 6  // Must match border.width of ringShape
                                    height: 6
                                    radius: 3
                                    color: "#2d2d2d"

                                    // Position centered on the top edge of the ring stroke
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                }

                                // 2. Conical Gradient (Fades 1/4 of the circle smoothly to opacity 0)
                                ConicalGradient {
                                    id: gradientSource
                                    anchors.fill: parent
                                    visible: false
                                    gradient: Gradient {
                                        GradientStop {
                                            position: 0.00
                                            color: "#ff000000"
                                        } // Fully opaque
                                        GradientStop {
                                            position: 0.25
                                            color: "#ff000000"
                                        } // Starts fading at 270°
                                        GradientStop {
                                            position: 1.00
                                            color: "#00000000"
                                        } // Fully transparent at 360° (1/4 fade)
                                    }
                                }

                                // 3. Apply Gradient Mask onto the #2d2d2d Ring
                                OpacityMask {
                                    anchors.fill: parent
                                    source: ringShape
                                    maskSource: gradientSource
                                }
                            }

                            // Hardware-accelerated continuous spin
                            RotationAnimator {
                                id: spinAnim
                                target: spinner
                                from: 360
                                to: 0
                                duration: 850
                                loops: Animation.Infinite
                                running: loadingState.visible
                            }
                        }
                    }

