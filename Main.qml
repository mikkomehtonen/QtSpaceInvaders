import QtQuick
import QtMultimedia
import QtQuick.LocalStorage

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
    readonly property int statePaused: 4

    property int gameState: stateStart
    property int score: 0
    property int highScore: 0
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
    property real enemyShootDelay: 0.9
    property int maxEnemyBullets: 2
    property int currentWaveRows: 5
    property int currentWaveCols: 11
    property bool soundsEnabled: true
    property real sfxVolume: 0.55
    property bool musicEnabled: true
    property real musicVolume: 0.26
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
        drawPixelSprite(ctx, sprite, alien.x, alien.y + 1, 3, bodyColor, "")
    }

    function playSfx(effect) {
        if (!soundsEnabled || !effect)
            return
        effect.stop()
        effect.play()
    }

    function setGameState(nextState) {
        if (gameState === nextState)
            return
        gameState = nextState
        if (nextState === stateWaveCleared)
            playSfx(sfxWaveClear)
        else if (nextState === stateGameOver)
            playSfx(sfxGameOver)
    }

    function loadHighScore() {
        var db = LocalStorage.openDatabaseSync("QtSpaceInvadersDB", "1.0", "Space Invaders Data", 100000)
        db.transaction(function(tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS highscores(name TEXT UNIQUE, value INTEGER)")
            var rs = tx.executeSql("SELECT value FROM highscores WHERE name = ?", ["highScore"])
            if (rs.rows.length > 0) {
                highScore = rs.rows.item(0).value
            } else {
                tx.executeSql("INSERT INTO highscores(name, value) VALUES(?, ?)", ["highScore", 0])
                highScore = 0
            }
        })
    }

    function saveHighScore() {
        var db = LocalStorage.openDatabaseSync("QtSpaceInvadersDB", "1.0", "Space Invaders Data", 100000)
        db.transaction(function(tx) {
            tx.executeSql("INSERT OR REPLACE INTO highscores(name, value) VALUES(?, ?)", ["highScore", highScore])
        })
    }

    function updateHighScoreIfNeeded() {
        if (score > highScore) {
            highScore = score
            saveHighScore()
        }
    }

    function updateMusicState() {
        if (musicEnabled) {
            if (bgmPlayer.playbackState !== MediaPlayer.PlayingState)
                bgmPlayer.play()
        } else {
            if (bgmPlayer.playbackState !== MediaPlayer.StoppedState)
                bgmPlayer.stop()
        }
    }

    function changeMusicVolume(delta) {
        musicVolume = clamp(musicVolume + delta, 0.0, 1.0)
        if (musicVolume > 0 && !musicEnabled)
            musicEnabled = true
    }

    function spawnWave() {
        var rows = currentWaveRows
        var cols = currentWaveCols
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
        enemyShootClock = 0
    }

    function updateDifficultyForLevel() {
        var l = Math.max(1, level)
        currentWaveRows = Math.min(7, 5 + Math.floor((l - 1) / 2))
        currentWaveCols = 11
        alienSpeed = 45 + (l - 1) * 14
        alienDrop = 22 + Math.min(14, (l - 1) * 2)
        enemyShotSpeed = 250 + (l - 1) * 28
        enemyShootDelay = Math.max(0.16, 0.90 - (l - 1) * 0.08)
        maxEnemyBullets = Math.min(8, 2 + Math.floor((l - 1) / 2))
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
        updateDifficultyForLevel()
        spawnWave()
        setGameState(stateRunning)
    }

    function nextWave() {
        level += 1
        createBunkers()
        updateDifficultyForLevel()
        spawnWave()
        setGameState(stateRunning)
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
            setGameState(stateWaveCleared)
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
                setGameState(stateGameOver)
                return
            }
        }
    }

    function tryEnemyShoot(dt) {
        enemyShootClock += dt
        if (enemyBullets.length >= maxEnemyBullets || enemyShootClock < enemyShootDelay)
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

        // Higher levels occasionally fire a second shot to ramp pressure.
        var bonusShotChance = Math.min(0.45, (level - 1) * 0.06)
        if (enemyBullets.length < maxEnemyBullets && Math.random() < bonusShotChance) {
            var shooter2 = shooters[Math.floor(Math.random() * shooters.length)]
            enemyBullets.push({
                x: shooter2.x + shooter2.w * 0.5 - 2,
                y: shooter2.y + shooter2.h,
                w: 4,
                h: 14,
                dead: false
            })
        }
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
        playSfx(sfxShoot)
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
                    updateHighScoreIfNeeded()
                    playSfx(sfxAlienHit)
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
                playSfx(sfxPlayerHit)
                if (lives <= 0) {
                    setGameState(stateGameOver)
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

            if (event.key === Qt.Key_M) {
                musicEnabled = !musicEnabled
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Minus || event.key === Qt.Key_Underscore) {
                changeMusicVolume(-0.05)
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Equal || event.key === Qt.Key_Plus) {
                changeMusicVolume(0.05)
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_P) {
                if (gameState === stateRunning) {
                    leftPressed = false
                    rightPressed = false
                    shootPressed = false
                    setGameState(statePaused)
                } else if (gameState === statePaused) {
                    setGameState(stateRunning)
                }
                event.accepted = true
                return
            }

            if (gameState === stateRunning && (event.key === Qt.Key_Left || event.key === Qt.Key_A))
                leftPressed = true
            if (gameState === stateRunning && (event.key === Qt.Key_Right || event.key === Qt.Key_D))
                rightPressed = true
            if (gameState === stateRunning && event.key === Qt.Key_Space)
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
            ctx.fillRect(0, 0, width, 76)
            ctx.fillStyle = "#dce8ff"
            ctx.font = "bold 22px monospace"
            ctx.fillText("SCORE  " + score, 22, 32)
            ctx.fillText("HIGH  " + highScore, width * 0.5 - 95, 32)
            ctx.fillText("LIVES  " + lives, width - 180, 32)
            ctx.font = "bold 20px monospace"
            ctx.fillText("WAVE  " + level, width * 0.5 - 60, 62)

            ctx.globalAlpha = 0.035
            ctx.fillStyle = "#c7d8ff"
            for (var y = 84; y < height; y += 8)
                ctx.fillRect(0, y, width, 1)
            ctx.globalAlpha = 1

            ctx.textAlign = "center"
            if (gameState === stateStart) {
                ctx.fillStyle = "#dce8ff"
                ctx.font = "bold 48px monospace"
                ctx.fillText("SPACE INVADERS", width * 0.5, height * 0.42)
                ctx.font = "24px monospace"
                ctx.fillText("Press ENTER to start", width * 0.5, height * 0.52)
                ctx.fillText("High Score: " + highScore, width * 0.5, height * 0.58)
                ctx.fillText("Move: A/D or Left/Right  Fire: Space", width * 0.5, height * 0.64)
            } else if (gameState === stateWaveCleared) {
                ctx.fillStyle = "#b5ffb5"
                ctx.font = "bold 46px monospace"
                ctx.fillText("WAVE CLEARED", width * 0.5, height * 0.46)
                ctx.fillStyle = "#dce8ff"
                ctx.font = "24px monospace"
                ctx.fillText("Press ENTER for next wave", width * 0.5, height * 0.55)
            } else if (gameState === stateGameOver) {
                ctx.fillStyle = "rgba(8, 14, 28, 0.72)"
                ctx.fillRect(width * 0.5 - 260, height * 0.46 - 70, 520, 190)
                ctx.strokeStyle = "rgba(193, 214, 255, 0.45)"
                ctx.lineWidth = 2
                ctx.strokeRect(width * 0.5 - 260, height * 0.46 - 70, 520, 190)
                ctx.fillStyle = "#ffb0b0"
                ctx.font = "bold 46px monospace"
                ctx.fillText("GAME OVER", width * 0.5, height * 0.46)
                ctx.fillStyle = "#dce8ff"
                ctx.font = "24px monospace"
                ctx.fillText("Press ENTER to restart", width * 0.5, height * 0.55)
                ctx.fillText("High Score: " + highScore, width * 0.5, height * 0.61)
            } else if (gameState === statePaused) {
                ctx.fillStyle = "rgba(5, 10, 20, 0.58)"
                ctx.fillRect(0, 0, width, height)
                ctx.fillStyle = "#cfe2ff"
                ctx.font = "bold 48px monospace"
                ctx.fillText("PAUSED", width * 0.5, height * 0.46)
                ctx.font = "24px monospace"
                ctx.fillText("Press P to resume", width * 0.5, height * 0.55)
            }
            ctx.textAlign = "start"
        }
    }

    SoundEffect {
        id: sfxShoot
        source: "qrc:/qt/qml/QtSpaceInvaders/assets/sfx/shoot.wav"
        volume: root.sfxVolume
    }

    SoundEffect {
        id: sfxAlienHit
        source: "qrc:/qt/qml/QtSpaceInvaders/assets/sfx/alien_hit.wav"
        volume: root.sfxVolume
    }

    SoundEffect {
        id: sfxPlayerHit
        source: "qrc:/qt/qml/QtSpaceInvaders/assets/sfx/player_hit.wav"
        volume: root.sfxVolume
    }

    SoundEffect {
        id: sfxWaveClear
        source: "qrc:/qt/qml/QtSpaceInvaders/assets/sfx/wave_clear.wav"
        volume: root.sfxVolume
    }

    SoundEffect {
        id: sfxGameOver
        source: "qrc:/qt/qml/QtSpaceInvaders/assets/sfx/game_over.wav"
        volume: root.sfxVolume
    }

    AudioOutput {
        id: bgmOutput
        volume: root.musicVolume
    }

    MediaPlayer {
        id: bgmPlayer

        readonly property var playlist: [
            "qrc:/qt/qml/QtSpaceInvaders/assets/music/orbital_siege_loop.mp3",
            "qrc:/qt/qml/QtSpaceInvaders/assets/music/galactic_onslaught.mp3"
        ]
        property int playlistIndex: 0

        source: playlist[playlistIndex]
        audioOutput: bgmOutput
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia) {
                playlistIndex = (playlistIndex + 1) % playlist.length
                source = playlist[playlistIndex]
                play()
            }
        }
    }

    Component.onCompleted: {
        loadHighScore()
        createStars()
        updateMusicState()
        gameCanvas.requestPaint()
    }

    onMusicEnabledChanged: updateMusicState()
}
