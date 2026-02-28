import QtQuick

Window {
    id: root
    width: 900
    height: 700
    visible: true
    color: "#06070a"
    title: "Qt Space Invaders"

    readonly property int stateStart: 0
    readonly property int stateRunning: 1
    readonly property int stateWaveCleared: 2
    readonly property int stateGameOver: 3

    property int gameState: stateStart
    property int score: 0
    property int lives: 3
    property int level: 1

    property real playerX: 0
    property real playerY: height - 70
    property real playerWidth: 56
    property real playerHeight: 24
    property real playerSpeed: 360

    property real playerShotSpeed: 520
    property real enemyShotSpeed: 250
    property real shootCooldown: 0
    property real shootDelay: 0.30

    property real alienSpeed: 45
    property real alienDirection: 1
    property real alienDrop: 22
    property real enemyShootClock: 0
    property real renderClock: 0
    property real invaderAnimClock: 0
    property int invaderAnimFrame: 0
    property real lastFrameMs: 0

    property bool leftPressed: false
    property bool rightPressed: false
    property bool shootPressed: false

    property var aliens: []
    property var playerBullets: []
    property var enemyBullets: []
    property var bunkers: []
    property var stars: []
    property var playerSprite: [
        "00001111110000",
        "00011111111000",
        "00111111111100",
        "01111011011110",
        "11111111111111",
        "00111100111100"
    ]
    property var invaderSprites: [
        {
            a: [
                "001100001100",
                "000111111000",
                "001111111100",
                "011011110110",
                "111111111111",
                "101111111101",
                "101000001101",
                "000110011000"
            ],
            b: [
                "001100001100",
                "100111111001",
                "111111111111",
                "110111111011",
                "111111111111",
                "001111111100",
                "011000000110",
                "110000000011"
            ]
        },
        {
            a: [
                "000011110000",
                "001111111100",
                "011101101110",
                "111111111111",
                "110111111011",
                "110000000011",
                "001100001100",
                "011000000110"
            ],
            b: [
                "000011110000",
                "001111111100",
                "011101101110",
                "111111111111",
                "110111111011",
                "001100001100",
                "011000000110",
                "110000000011"
            ]
        },
        {
            a: [
                "000111111000",
                "001111111100",
                "011011110110",
                "111111111111",
                "001101101100",
                "011000000110",
                "110000000011",
                "011000000110"
            ],
            b: [
                "000111111000",
                "001111111100",
                "011011110110",
                "111111111111",
                "001101101100",
                "000110011000",
                "001100001100",
                "011000000110"
            ]
        }
    ]

    function randRange(min, max) {
        return min + Math.random() * (max - min)
    }

    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value))
    }

    function createStars() {
        var s = []
        for (var i = 0; i < 50; ++i) {
            s.push({
                x: randRange(0, width),
                y: randRange(0, height),
                r: randRange(0.6, 1.8),
                a: randRange(0.25, 0.8),
                phase: randRange(0, Math.PI * 2)
            })
        }
        stars = s
    }

    function drawPixelSprite(ctx, sprite, x, y, scale, color, glow) {
        ctx.fillStyle = color

        for (var sy = 0; sy < sprite.length; ++sy) {
            for (var sx = 0; sx < sprite[sy].length; ++sx) {
                if (sprite[sy][sx] === "1")
                    ctx.fillRect(x + sx * scale, y + sy * scale, scale, scale)
            }
        }
    }

    function drawPlayer(ctx) {
        drawPixelSprite(ctx, playerSprite, playerX, playerY, 4, "#8ee9ff", "")
    }

    function drawAlien(ctx, alien) {
        var type = alien.row < 2 ? 0 : (alien.row < 4 ? 1 : 2)
        var spriteSet = invaderSprites[type]
        var sprite = invaderAnimFrame === 0 ? spriteSet.a : spriteSet.b
        var bodyColor = type === 0 ? "#ff8f8f" : (type === 1 ? "#ffd67e" : "#98ff95")
        var glowColor = type === 0 ? "rgba(255, 121, 121, 0.45)"
                                   : (type === 1 ? "rgba(255, 209, 112, 0.45)"
                                                 : "rgba(138, 255, 132, 0.45)")
        drawPixelSprite(ctx, sprite, alien.x, alien.y + 1, 3, bodyColor, "")
    }

    function spawnWave() {
        var rows = 5
        var cols = 11
        var spacingX = 54
        var spacingY = 42
        var alienW = 36
        var alienH = 26
        var formationWidth = (cols - 1) * spacingX + alienW
        var startX = (width - formationWidth) * 0.5
        var startY = 90
        var wave = []

        for (var r = 0; r < rows; ++r) {
            for (var c = 0; c < cols; ++c) {
                wave.push({
                    x: startX + c * spacingX,
                    y: startY + r * spacingY,
                    w: alienW,
                    h: alienH,
                    row: r,
                    alive: true
                })
            }
        }

        aliens = wave
        playerBullets = []
        enemyBullets = []
        alienDirection = 1
        alienSpeed = 45 + (level - 1) * 8
        enemyShootClock = 0
    }

    function createBunkers() {
        var bunkerCount = 4
        var cell = 10
        var pattern = [
            " 111111 ",
            "11111111",
            "11111111",
            "11100111",
            "11000011"
        ]
        var totalW = bunkerCount * (8 * cell) + (bunkerCount - 1) * 70
        var baseX = (width - totalW) * 0.5
        var y = height - 190
        var allCells = []

        for (var b = 0; b < bunkerCount; ++b) {
            var bunkerX = baseX + b * (8 * cell + 70)
            for (var py = 0; py < pattern.length; ++py) {
                for (var px = 0; px < pattern[py].length; ++px) {
                    if (pattern[py][px] === "1") {
                        allCells.push({
                            x: bunkerX + px * cell,
                            y: y + py * cell,
                            w: cell,
                            h: cell,
                            hp: 3
                        })
                    }
                }
            }
        }

        bunkers = allCells
    }

    function startNewGame() {
        score = 0
        lives = 3
        level = 1
        playerX = (width - playerWidth) * 0.5
        playerY = height - 70
        shootCooldown = 0
        createStars()
        createBunkers()
        spawnWave()
        gameState = stateRunning
    }

    function nextWave() {
        level += 1
        createBunkers()
        spawnWave()
        gameState = stateRunning
    }

    function aabb(ax, ay, aw, ah, bx, by, bw, bh) {
        return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by
    }

    function markBulletForRemoval(bullet) {
        bullet.dead = true
    }

    function updateBullets(dt) {
        for (var i = 0; i < playerBullets.length; ++i) {
            playerBullets[i].y -= playerShotSpeed * dt
            if (playerBullets[i].y + playerBullets[i].h < 0)
                playerBullets[i].dead = true
        }

        for (var j = 0; j < enemyBullets.length; ++j) {
            enemyBullets[j].y += enemyShotSpeed * dt
            if (enemyBullets[j].y > height)
                enemyBullets[j].dead = true
        }
    }

    function updateAliens(dt) {
        var aliveCount = 0
        var minX = 1e9
        var maxX = -1e9

        for (var i = 0; i < aliens.length; ++i) {
            if (!aliens[i].alive)
                continue
            aliveCount += 1
            minX = Math.min(minX, aliens[i].x)
            maxX = Math.max(maxX, aliens[i].x + aliens[i].w)
        }

        if (aliveCount === 0) {
            gameState = stateWaveCleared
            return
        }

        var margin = 18
        var moveX = alienDirection * alienSpeed * dt
        if (minX + moveX < margin || maxX + moveX > width - margin) {
            alienDirection *= -1
            alienSpeed += 7
            for (var k = 0; k < aliens.length; ++k) {
                if (aliens[k].alive)
                    aliens[k].y += alienDrop
            }
        } else {
            for (var m = 0; m < aliens.length; ++m) {
                if (aliens[m].alive)
                    aliens[m].x += moveX
            }
        }

        for (var n = 0; n < aliens.length; ++n) {
            if (aliens[n].alive && aliens[n].y + aliens[n].h >= playerY - 6) {
                gameState = stateGameOver
                return
            }
        }
    }

    function tryEnemyShoot(dt) {
        enemyShootClock += dt
        var delay = Math.max(0.2, 0.9 - level * 0.06)
        if (enemyShootClock < delay)
            return

        enemyShootClock = 0

        var columns = {}
        for (var i = 0; i < aliens.length; ++i) {
            var a = aliens[i]
            if (!a.alive)
                continue
            var key = Math.round(a.x)
            var picked = columns[key]
            if (!picked || a.y > picked.y)
                columns[key] = a
        }

        var shooters = []
        for (var k in columns)
            shooters.push(columns[k])

        if (shooters.length === 0)
            return

        var shooter = shooters[Math.floor(Math.random() * shooters.length)]
        enemyBullets.push({
            x: shooter.x + shooter.w * 0.5 - 2,
            y: shooter.y + shooter.h,
            w: 4,
            h: 14,
            dead: false
        })
    }

    function handlePlayerFire() {
        if (!shootPressed || shootCooldown > 0)
            return

        playerBullets.push({
            x: playerX + playerWidth * 0.5 - 2,
            y: playerY - 14,
            w: 4,
            h: 14,
            dead: false
        })
        shootCooldown = shootDelay
    }

    function handleCollisions() {
        for (var i = 0; i < playerBullets.length; ++i) {
            var pb = playerBullets[i]
            if (pb.dead)
                continue

            for (var a = 0; a < aliens.length; ++a) {
                var alien = aliens[a]
                if (!alien.alive)
                    continue
                if (aabb(pb.x, pb.y, pb.w, pb.h, alien.x, alien.y, alien.w, alien.h)) {
                    alien.alive = false
                    pb.dead = true
                    score += (6 - alien.row) * 10
                    break
                }
            }

            if (pb.dead)
                continue

            for (var b = 0; b < bunkers.length; ++b) {
                var block = bunkers[b]
                if (block.hp <= 0)
                    continue
                if (aabb(pb.x, pb.y, pb.w, pb.h, block.x, block.y, block.w, block.h)) {
                    block.hp -= 2
                    pb.dead = true
                    break
                }
            }
        }

        for (var j = 0; j < enemyBullets.length; ++j) {
            var eb = enemyBullets[j]
            if (eb.dead)
                continue

            if (aabb(eb.x, eb.y, eb.w, eb.h, playerX, playerY, playerWidth, playerHeight)) {
                eb.dead = true
                lives -= 1
                if (lives <= 0) {
                    gameState = stateGameOver
                } else {
                    playerX = (width - playerWidth) * 0.5
                }
                continue
            }

            for (var c = 0; c < bunkers.length; ++c) {
                var bunkerCell = bunkers[c]
                if (bunkerCell.hp <= 0)
                    continue
                if (aabb(eb.x, eb.y, eb.w, eb.h, bunkerCell.x, bunkerCell.y, bunkerCell.w, bunkerCell.h)) {
                    bunkerCell.hp -= 1
                    eb.dead = true
                    break
                }
            }
        }

        for (var z = bunkers.length - 1; z >= 0; --z) {
            if (bunkers[z].hp <= 0)
                bunkers.splice(z, 1)
        }

        for (var p = playerBullets.length - 1; p >= 0; --p) {
            if (playerBullets[p].dead)
                playerBullets.splice(p, 1)
        }

        for (var e = enemyBullets.length - 1; e >= 0; --e) {
            if (enemyBullets[e].dead)
                enemyBullets.splice(e, 1)
        }
    }

    function stepSimulation(dt) {
        shootCooldown = Math.max(0, shootCooldown - dt)

        if (leftPressed)
            playerX -= playerSpeed * dt
        if (rightPressed)
            playerX += playerSpeed * dt
        playerX = clamp(playerX, 10, width - playerWidth - 10)

        handlePlayerFire()
        updateBullets(dt)
        updateAliens(dt)
        if (gameState !== stateRunning)
            return

        tryEnemyShoot(dt)
        handleCollisions()
    }

    Item {
        id: inputLayer
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            if (event.isAutoRepeat)
                return

            if (event.key === Qt.Key_Left || event.key === Qt.Key_A)
                leftPressed = true
            if (event.key === Qt.Key_Right || event.key === Qt.Key_D)
                rightPressed = true
            if (event.key === Qt.Key_Space)
                shootPressed = true

            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && gameState === stateStart)
                startNewGame()
            else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && gameState === stateGameOver)
                startNewGame()
            else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && gameState === stateWaveCleared)
                nextWave()

            event.accepted = true
        }

        Keys.onReleased: function(event) {
            if (event.isAutoRepeat)
                return

            if (event.key === Qt.Key_Left || event.key === Qt.Key_A)
                leftPressed = false
            if (event.key === Qt.Key_Right || event.key === Qt.Key_D)
                rightPressed = false
            if (event.key === Qt.Key_Space)
                shootPressed = false

            event.accepted = true
        }
    }

    Timer {
        id: gameTimer
        interval: 16
        repeat: true
        running: true
        onTriggered: {
            var nowMs = Date.now()
            var dt = lastFrameMs > 0 ? (nowMs - lastFrameMs) / 1000.0 : interval / 1000.0
            lastFrameMs = nowMs
            dt = Math.min(dt, 0.25)
            root.renderClock += dt
            if (root.gameState === root.stateRunning)
                root.stepSimulation(dt)
            if (root.gameState === root.stateRunning) {
                root.invaderAnimClock += dt
                if (root.invaderAnimClock >= 0.30) {
                    root.invaderAnimClock = 0
                    root.invaderAnimFrame = 1 - root.invaderAnimFrame
                }
            }
            gameCanvas.requestPaint()
        }
    }

    Canvas {
        id: gameCanvas
        anchors.fill: parent
        antialiasing: false
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var bg = ctx.createLinearGradient(0, 0, 0, height)
            bg.addColorStop(0, "#060710")
            bg.addColorStop(0.55, "#090c18")
            bg.addColorStop(1, "#020306")
            ctx.fillStyle = bg
            ctx.fillRect(0, 0, width, height)

            ctx.globalAlpha = 0.22
            ctx.fillStyle = "#203f7f"
            ctx.beginPath()
            ctx.arc(width * 0.18, height * 0.2, 170, 0, Math.PI * 2)
            ctx.fill()
            ctx.fillStyle = "#27436b"
            ctx.beginPath()
            ctx.arc(width * 0.82, height * 0.35, 220, 0, Math.PI * 2)
            ctx.fill()
            ctx.globalAlpha = 1

            for (var s = 0; s < stars.length; ++s) {
                var star = stars[s]
                var twinkle = 0.55 + 0.45 * Math.sin(renderClock * 1.7 + star.phase)
                ctx.globalAlpha = star.a * twinkle
                ctx.fillStyle = "#e9f2ff"
                ctx.beginPath()
                ctx.arc(star.x, star.y, star.r, 0, Math.PI * 2)
                ctx.fill()
            }
            ctx.globalAlpha = 1

            for (var b = 0; b < bunkers.length; ++b) {
                var block = bunkers[b]
                if (block.hp <= 0)
                    continue
                var bunkerColor = block.hp === 3 ? "#5ad65a" : (block.hp === 2 ? "#3fb03f" : "#2a7d2a")
                ctx.fillStyle = bunkerColor
                ctx.fillRect(block.x, block.y, block.w, block.h)
                ctx.fillStyle = "rgba(255, 255, 255, 0.12)"
                ctx.fillRect(block.x, block.y, block.w, 2)
            }

            drawPlayer(ctx)

            for (var i = 0; i < aliens.length; ++i) {
                var alien = aliens[i]
                if (!alien.alive)
                    continue
                drawAlien(ctx, alien)
            }

            for (var p = 0; p < playerBullets.length; ++p) {
                var pb = playerBullets[p]
                ctx.fillStyle = "#f4f8ff"
                ctx.fillRect(pb.x, pb.y, pb.w, pb.h)
                ctx.fillStyle = "rgba(170, 220, 255, 0.5)"
                ctx.fillRect(pb.x, pb.y + pb.h, pb.w, 6)
            }

            for (var e = 0; e < enemyBullets.length; ++e) {
                var eb = enemyBullets[e]
                ctx.fillStyle = "#ff9090"
                ctx.fillRect(eb.x, eb.y, eb.w, eb.h)
                ctx.fillStyle = "rgba(255, 109, 109, 0.4)"
                ctx.fillRect(eb.x, eb.y - 5, eb.w, 5)
            }

            ctx.fillStyle = "rgba(10, 16, 36, 0.7)"
            ctx.fillRect(0, 0, width, 52)
            ctx.fillStyle = "#dce8ff"
            ctx.font = "bold 24px monospace"
            ctx.fillText("SCORE  " + score, 22, 36)
            ctx.fillText("LIVES  " + lives, width - 180, 36)
            ctx.fillText("WAVE  " + level, width * 0.5 - 70, 36)

            ctx.globalAlpha = 0.035
            ctx.fillStyle = "#c7d8ff"
            for (var y = 64; y < height; y += 8)
                ctx.fillRect(0, y, width, 1)
            ctx.globalAlpha = 1

            ctx.textAlign = "center"
            if (gameState === stateStart) {
                ctx.fillStyle = "#dce8ff"
                ctx.font = "bold 48px monospace"
                ctx.fillText("SPACE INVADERS", width * 0.5, height * 0.42)
                ctx.font = "24px monospace"
                ctx.fillText("Press ENTER to start", width * 0.5, height * 0.52)
                ctx.fillText("Move: A/D or Left/Right  Fire: Space", width * 0.5, height * 0.58)
            } else if (gameState === stateWaveCleared) {
                ctx.fillStyle = "#b5ffb5"
                ctx.font = "bold 46px monospace"
                ctx.fillText("WAVE CLEARED", width * 0.5, height * 0.46)
                ctx.fillStyle = "#dce8ff"
                ctx.font = "24px monospace"
                ctx.fillText("Press ENTER for next wave", width * 0.5, height * 0.55)
            } else if (gameState === stateGameOver) {
                ctx.fillStyle = "#ffb0b0"
                ctx.font = "bold 46px monospace"
                ctx.fillText("GAME OVER", width * 0.5, height * 0.46)
                ctx.fillStyle = "#dce8ff"
                ctx.font = "24px monospace"
                ctx.fillText("Press ENTER to restart", width * 0.5, height * 0.55)
            }
            ctx.textAlign = "start"
        }
    }

    Component.onCompleted: {
        createStars()
        gameCanvas.requestPaint()
    }
}
