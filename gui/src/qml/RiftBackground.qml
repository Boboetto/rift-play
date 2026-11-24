import QtQuick
import QtQuick.Particles

// Rift Play animated background: flowing ribbons of soft particles.
// Each ribbon is an emitter that slowly oscillates up and down on the left edge
// while its particles drift right, leaving a wave-shaped trail of light.
Item {
    id: bg
    property bool running: true
    readonly property real flowSpeed: Math.max(90, width / 14)
    readonly property real lifeMs: (width + 200) / flowSpeed * 1000

    ParticleSystem {
        id: sys
        running: bg.width > 0
        // pause (not stop): stopping a ParticleSystem clears all particles
        paused: !(bg.running && bg.visible)
    }

    ImageParticle {
        system: sys
        groups: ["cyan"]
        source: "qrc:/icons/riftplay-glow-cyan.svg"
        alpha: 0.55
        alphaVariation: 0.3
        entryEffect: ImageParticle.Fade
    }
    ImageParticle {
        system: sys
        groups: ["violet"]
        source: "qrc:/icons/riftplay-glow-violet.svg"
        alpha: 0.55
        alphaVariation: 0.3
        entryEffect: ImageParticle.Fade
    }
    ImageParticle {
        system: sys
        groups: ["pink"]
        source: "qrc:/icons/riftplay-glow-pink.svg"
        alpha: 0.45
        alphaVariation: 0.3
        entryEffect: ImageParticle.Fade
    }

    // ribbons: [group, base y (fraction of height), amplitude, period ms, particle size]
    Repeater {
        model: [
            ["violet", 0.80, 0.07, 9000, 7],
            ["cyan",   0.85, 0.06, 12000, 6],
            ["pink",   0.89, 0.05, 15000, 5],
            ["violet", 0.76, 0.04, 7000, 4]
        ]
        Emitter {
            id: ribbon
            required property var modelData
            required property int index
            system: sys
            group: modelData[0]
            x: -20
            width: 8
            height: 10
            readonly property real baseY: bg.height * modelData[1]
            readonly property real amp: bg.height * modelData[2]
            y: baseY
            emitRate: 18
            startTime: bg.lifeMs
            lifeSpan: bg.lifeMs
            lifeSpanVariation: bg.lifeMs * 0.08
            size: modelData[4]
            sizeVariation: modelData[4] * 0.6
            endSize: modelData[4] * 1.6
            velocity: PointDirection { x: bg.flowSpeed; xVariation: bg.flowSpeed * 0.08; yVariation: 3 }

            SequentialAnimation on y {
                running: sys.running
                paused: sys.paused
                loops: Animation.Infinite
                NumberAnimation { from: ribbon.baseY - ribbon.amp; to: ribbon.baseY + ribbon.amp; duration: ribbon.modelData[3] / 2; easing.type: Easing.InOutSine }
                NumberAnimation { from: ribbon.baseY + ribbon.amp; to: ribbon.baseY - ribbon.amp; duration: ribbon.modelData[3] / 2; easing.type: Easing.InOutSine }
            }
        }
    }

    // floating dust over the whole screen
    Emitter {
        system: sys
        group: "cyan"
        anchors.fill: parent
        emitRate: 6
        lifeSpan: 9000
        lifeSpanVariation: 3000
        size: 4
        sizeVariation: 3
        endSize: 1
        velocity: AngleDirection { angle: -90; angleVariation: 40; magnitude: 10; magnitudeVariation: 6 }
    }

    // gentle organic drift for every particle
    Wander {
        system: sys
        xVariance: 12
        yVariance: 26
        pace: 40
    }
}
