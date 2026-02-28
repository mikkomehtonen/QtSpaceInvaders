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

    property bool leftPressed: false
    property bool rightPressed: false
    property bool shootPressed: false

    property var aliens: []
    property var playerBullets: []
    property var enemyBullets: []
    property var bunkers: []
    property var stars: []

    function randRange(min, max) {
        return min + Math.random() * (max - min)
    }

    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value))
    }

    function createStars() {
        var s = []
        for (var i = 0; i < 100; ++i) {
            s.push({
                x: randRange(0, width),
                y: randRange(0, height),
                r: randRange(0.6, 1.8),
                a: randRange(0.25, 0.8)
            })
        }
        stars = s
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
            if (root.gameState === root.stateRunning)
                root.stepSimulation(interval / 1000.0)
            gameCanvas.requestPaint()
        }
    }

    Canvas {
        id: gameCanvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            ctx.fillStyle = "#06070a"
            ctx.fillRect(0, 0, width, height)

            for (var s = 0; s < stars.length; ++s) {
                var star = stars[s]
                ctx.globalAlpha = star.a
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
            }

            ctx.fillStyle = "#7dd3ff"
            ctx.fillRect(playerX, playerY, playerWidth, playerHeight)
            ctx.fillRect(playerX + playerWidth * 0.46, playerY - 10, playerWidth * 0.08, 10)

            for (var i = 0; i < aliens.length; ++i) {
                var alien = aliens[i]
                if (!alien.alive)
                    continue

                ctx.fillStyle = alien.row < 2 ? "#ff7a7a" : (alien.row < 4 ? "#ffd166" : "#7bff7b")
                ctx.fillRect(alien.x, alien.y, alien.w, alien.h)
                ctx.fillRect(alien.x - 4, alien.y + 8, 4, 8)
                ctx.fillRect(alien.x + alien.w, alien.y + 8, 4, 8)
            }

            ctx.fillStyle = "#f4f8ff"
            for (var p = 0; p < playerBullets.length; ++p) {
                var pb = playerBullets[p]
                ctx.fillRect(pb.x, pb.y, pb.w, pb.h)
            }

            ctx.fillStyle = "#ff8b8b"
            for (var e = 0; e < enemyBullets.length; ++e) {
                var eb = enemyBullets[e]
                ctx.fillRect(eb.x, eb.y, eb.w, eb.h)
            }

            ctx.fillStyle = "#dce8ff"
            ctx.font = "bold 24px monospace"
            ctx.fillText("SCORE  " + score, 22, 36)
            ctx.fillText("LIVES  " + lives, width - 180, 36)
            ctx.fillText("WAVE  " + level, width * 0.5 - 70, 36)

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
