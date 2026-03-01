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
    property real attractCruiseSpeed: 230
    property real attractMoveClock: 0
    property real attractShootClock: 0
    property real attractShootDelay: 0

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
    property real musicVolume: 0.15
    property bool showHelp: false
    property real renderClock: 0
    property real invaderAnimClock: 0
    property int invaderAnimFrame: 0
    property real lastFrameMs: 0
    property int spriteCachePaintCount: 0
    property bool spriteCacheReady: false

    property bool leftPressed: false
    property real attractTargetX: 0
    property real screenShakeIntensity: 0
    property real screenShakeDuration: 0
    property bool rightPressed: false
    property bool shootPressed: false

    property var aliens: []
    property var playerBullets: []
    property var enemyBullets: []
    property var bunkers: []
    property var stars: []
    property var hitParticles: []
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
                if (sprite[sy][sx] === "1") {
                    ctx.fillRect(x + sx * scale, y + sy * scale, scale, scale)
                }
            }
        }
    }

    function drawPlayer(ctx) {
        if (spriteCacheReady) {
            ctx.drawImage(playerSpriteCache, playerX, playerY)
        } else {
            drawPixelSprite(ctx, playerSprite, playerX, playerY, 4, "#8ee9ff", "")
        }
    }

    function drawAlien(ctx, alien) {
        var type = alien.row < 2 ? 0 : (alien.row < 4 ? 1 : 2)
        var bodyColor = type === 0 ? "#ff8f8f" : (type === 1 ? "#ffd67e" : "#98ff95")
        if (spriteCacheReady) {
            ctx.drawImage(alienSpriteCanvas(type, invaderAnimFrame), alien.x, alien.y + 1)
        } else {
            var spriteSet = invaderSprites[type]
            var sprite = invaderAnimFrame === 0 ? spriteSet.a : spriteSet.b
            drawPixelSprite(ctx, sprite, alien.x, alien.y + 1, 3, bodyColor, "")
        }
    }

    function alienSpriteCanvas(type, frame) {
        if (type === 0) {
            return frame === 0 ? alienType0Frame0Cache : alienType0Frame1Cache
        } else if (type === 1) {
            return frame === 0 ? alienType1Frame0Cache : alienType1Frame1Cache
        }
        return frame === 0 ? alienType2Frame0Cache : alienType2Frame1Cache
    }

    function markSpriteCachePainted(canvasItem) {
        if (!canvasItem.cachePainted) {
            canvasItem.cachePainted = true
            spriteCachePaintCount += 1
            if (spriteCachePaintCount >= 7) {
                spriteCacheReady = true
            }
        }
    }

    function alienColorForRow(row) {
        if (row < 2) {
            return "#ff8f8f"
        } else if (row < 4) {
            return "#ffd67e"
        }
        return "#98ff95"
    }

    function playSfx(effect) {
        if (!soundsEnabled || !effect) {
            return
        }
        effect.stop()
        effect.play()
    }

    function setGameState(nextState) {
        if (gameState === nextState) {
            return
        }
        gameState = nextState
        if (nextState === stateWaveCleared) {
            playSfx(sfxWaveClear)
        } else if (nextState === stateGameOver) {
            playSfx(sfxGameOver)
        }
        if (nextState === stateGameOver) {
            // Reset screen shake when game over
            screenShakeIntensity = 0
            screenShakeDuration = 0
        }
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
            if (bgmPlayer.playbackState !== MediaPlayer.PlayingState) {
                bgmPlayer.play()
            }
        } else {
            if (bgmPlayer.playbackState !== MediaPlayer.StoppedState) {
                bgmPlayer.stop()
            }
        }
    }

    function changeMusicVolume(delta) {
        musicVolume = clamp(musicVolume + delta, 0.0, 1.0)
        if (musicVolume > 0 && !musicEnabled) {
            musicEnabled = true
        }
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
        hitParticles = []
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

    function setAttractTargetX() {
        attractTargetX = randRange(10, width - playerWidth - 10)
    }

    function resetStartAttractMode() {
        playerX = (width - playerWidth) * 0.5
        playerY = height - 70
        playerBullets = []
        enemyBullets = []
        shootCooldown = 0
        attractMoveClock = 0
        attractShootClock = 0
        attractShootDelay = randRange(0.8, 2.4)
        setAttractTargetX()
    }

    function startNewGame() {
        score = 0
        lives = 3
        level = 1
        showHelp = false
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
            if (playerBullets[i].y + playerBullets[i].h < 0) {
                playerBullets[i].dead = true
            }
        }

        for (var j = 0; j < enemyBullets.length; ++j) {
            enemyBullets[j].y += enemyShotSpeed * dt
            if (enemyBullets[j].y > height) {
                enemyBullets[j].dead = true
            }
        }
    }

    function updateAliens(dt) {
        var aliveCount = 0
        var minX = 1e9
        var maxX = -1e9

        for (var i = 0; i < aliens.length; ++i) {
            if (!aliens[i].alive) {
                continue
            }
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
                if (aliens[k].alive) {
                    aliens[k].y += alienDrop
                }
            }
        } else {
            for (var m = 0; m < aliens.length; ++m) {
                if (aliens[m].alive) {
                    aliens[m].x += moveX
                }
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
        if (enemyBullets.length >= maxEnemyBullets || enemyShootClock < enemyShootDelay) {
            return
        }

        enemyShootClock = 0

        var columns = {}
        for (var i = 0; i < aliens.length; ++i) {
            var a = aliens[i]
            if (!a.alive) {
                continue
            }
            var key = Math.round(a.x)
            var picked = columns[key]
            if (!picked || a.y > picked.y) {
                columns[key] = a
            }
        }

        var shooters = []
        for (var k in columns) {
            shooters.push(columns[k])
        }

        if (shooters.length === 0) {
            return
        }

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
        if (!shootPressed || shootCooldown > 0) {
            return
        }

        spawnPlayerBullet(true)
    }

    function spawnPlayerBullet(playSound) {
        playerBullets.push({
            x: playerX + playerWidth * 0.5 - 2,
            y: playerY - 14,
            w: 4,
            h: 14,
            dead: false
        })
        shootCooldown = shootDelay
        if (playSound) {
            playSfx(sfxShoot)
        }
    }

    function cleanupProjectiles() {
        for (var p = playerBullets.length - 1; p >= 0; --p) {
            if (playerBullets[p].dead) {
                playerBullets.splice(p, 1)
            }
        }

        for (var e = enemyBullets.length - 1; e >= 0; --e) {
            if (enemyBullets[e].dead) {
                enemyBullets.splice(e, 1)
            }
        }
    }

    function stepStartAttractMode(dt) {
        shootCooldown = Math.max(0, shootCooldown - dt)
        attractMoveClock += dt
        attractShootClock += dt

        var dx = attractTargetX - playerX
        if (Math.abs(dx) < 8 || attractMoveClock > 2.8) {
            attractMoveClock = 0
            setAttractTargetX()
            dx = attractTargetX - playerX
        }

        var maxStep = attractCruiseSpeed * dt
        playerX += clamp(dx, -maxStep, maxStep)
        playerX = clamp(playerX, 10, width - playerWidth - 10)

        if (shootCooldown <= 0 && attractShootClock >= attractShootDelay) {
            attractShootClock = 0
            attractShootDelay = randRange(0.8, 2.4)
            spawnPlayerBullet(Math.random() < 0.35)
        }

        updateBullets(dt)
        cleanupProjectiles()
    }

    function spawnAlienHitParticles(x, y, color) {
        for (var i = 0; i < 14; ++i) {
            var angle = Math.random() * Math.PI * 2
            var speed = 70 + Math.random() * 140
            var life = 0.36 + Math.random() * 0.24
            hitParticles.push({
                x: x,
                y: y,
                vx: Math.cos(angle) * speed,
                vy: Math.sin(angle) * speed,
                life: life,
                maxLife: life,
                size: 2 + Math.random() * 2.5,
                color: color
            })
        }
    }

    function updateHitParticles(dt) {
        var out = []
        for (var i = 0; i < hitParticles.length; ++i) {
            var p = hitParticles[i]
            p.life -= dt
            if (p.life <= 0) continue
            p.x += p.vx * dt
            p.y += p.vy * dt
            p.vx *= 0.96
            p.vy = p.vy * 0.96 + 140 * dt
            out.push(p)
        }
        hitParticles = out
    }

    function handleCollisions() {
        for (var i = 0; i < playerBullets.length; ++i) {
            var pb = playerBullets[i]
            if (pb.dead) {
                continue
            }

            for (var a = 0; a < aliens.length; ++a) {
                var alien = aliens[a]
                if (!alien.alive) {
                    continue
                }
                if (aabb(pb.x, pb.y, pb.w, pb.h, alien.x, alien.y, alien.w, alien.h)) {
                    alien.alive = false
                    pb.dead = true
                    spawnAlienHitParticles(alien.x + alien.w * 0.5, alien.y + alien.h * 0.5, alienColorForRow(alien.row))
                    score += (6 - alien.row) * 10
                    updateHighScoreIfNeeded()
                    playSfx(sfxAlienHit)
                    break
                }
            }

            if (pb.dead) {
                continue
            }

            for (var b = 0; b < bunkers.length; ++b) {
                var block = bunkers[b]
                if (block.hp <= 0) {
                    continue
                }
                if (aabb(pb.x, pb.y, pb.w, pb.h, block.x, block.y, block.w, block.h)) {
                    block.hp -= 2
                    pb.dead = true
                    break
                }
            }
        }

        for (var j = 0; j < enemyBullets.length; ++j) {
            var eb = enemyBullets[j]
            if (eb.dead) {
                continue
            }

            if (aabb(eb.x, eb.y, eb.w, eb.h, playerX, playerY, playerWidth, playerHeight)) {
                eb.dead = true
                lives -= 1
                // Add screen shake effect when player is hit
                screenShakeIntensity = 20
                screenShakeDuration = 0.3

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
                if (bunkerCell.hp <= 0) {
                    continue
                }
                if (aabb(eb.x, eb.y, eb.w, eb.h, bunkerCell.x, bunkerCell.y, bunkerCell.w, bunkerCell.h)) {
                    bunkerCell.hp -= 1
                    eb.dead = true
                    break
                }
            }
        }

        for (var z = bunkers.length - 1; z >= 0; --z) {
            if (bunkers[z].hp <= 0) {
                bunkers.splice(z, 1)
            }
        }

        cleanupProjectiles()
    }

    function handleAlienBunkerCollisions(dt) {
        if (!dt || !isFinite(dt)) return

        // How fast aliens destroy the bunkers (hp/second)
        var crushRate = 5.0
        for (var a = 0; a < aliens.length; ++a) {
            var alien = aliens[a]
            if (!alien.alive) continue

            for (var b = 0; b < bunkers.length; ++b) {
                var block = bunkers[b]
                if (block.hp <= 0) continue

                if (aabb(alien.x, alien.y, alien.w, alien.h, block.x, block.y, block.w, block.h)) {
                    block._crush = (block._crush || 0) + crushRate * dt
                    if (block._crush >= 1) {
                        var dmg = Math.floor(block._crush)
                        block._crush -= dmg
                        block.hp -= dmg
                    }
                }
            }
        }
    }

    function stepSimulation(dt) {
        updateHitParticles(dt)
        shootCooldown = Math.max(0, shootCooldown - dt)

        if (leftPressed) {
            playerX -= playerSpeed * dt
        }
        if (rightPressed) {
            playerX += playerSpeed * dt
        }
        playerX = clamp(playerX, 10, width - playerWidth - 10)

        handlePlayerFire()
        updateBullets(dt)
        updateAliens(dt)
        if (gameState !== stateRunning) {
            return
        }

        tryEnemyShoot(dt)
        handleCollisions()
        handleAlienBunkerCollisions(dt)
        if (screenShakeDuration > 0) {
            screenShakeDuration -= dt
            if (screenShakeDuration <= 0) {
                screenShakeIntensity = 0
            }
        }
    }

    Item {
        id: inputLayer
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            if (event.isAutoRepeat) {
                return
            }

            if (event.key === Qt.Key_H) {
                root.showHelp = !root.showHelp
                if (root.showHelp) {
                    root.leftPressed = false
                    root.rightPressed = false
                    root.shootPressed = false
                }
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_M) {
                root.musicEnabled = !root.musicEnabled
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_N) {
                bgmPlayer.nextSong()
                event.accepted = true
                return
            }


            if (event.key === Qt.Key_Minus || event.key === Qt.Key_Underscore) {
                root.changeMusicVolume(-0.05)
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Equal || event.key === Qt.Key_Plus) {
                root.changeMusicVolume(0.05)
                event.accepted = true
                return
            }

            if (root.showHelp) {
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_P) {
                if (root.gameState === root.stateRunning) {
                    root.leftPressed = false
                    root.rightPressed = false
                    root.shootPressed = false
                    root.setGameState(root.statePaused)
                } else if (root.gameState === root.statePaused) {
                    root.setGameState(root.stateRunning)
                }
                event.accepted = true
                return
            }

            if (root.gameState === root.stateRunning && (event.key === Qt.Key_Left || event.key === Qt.Key_A)) {
                root.leftPressed = true
            }
            if (root.gameState === root.stateRunning && (event.key === Qt.Key_Right || event.key === Qt.Key_D)) {
                root.rightPressed = true
            }
            if (root.gameState === root.stateRunning && event.key === Qt.Key_Space) {
                root.shootPressed = true
            }

            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.gameState === root.stateStart) {
                root.startNewGame()
            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.gameState === root.stateGameOver) {
                root.startNewGame()
            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.gameState === root.stateWaveCleared) {
                root.nextWave()
            }

            event.accepted = true
        }

        Keys.onReleased: function(event) {
            if (event.isAutoRepeat) {
                return
            }

            if (event.key === Qt.Key_Left || event.key === Qt.Key_A) {
                root.leftPressed = false
            }
            if (event.key === Qt.Key_Right || event.key === Qt.Key_D) {
                root.rightPressed = false
            }
            if (event.key === Qt.Key_Space) {
                root.shootPressed = false
            }

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
            var dt = root.lastFrameMs > 0 ? (nowMs - root.lastFrameMs) / 1000.0 : interval / 1000.0
            root.lastFrameMs = nowMs
            dt = Math.min(dt, 0.25)
            root.renderClock += dt
            if (root.gameState === root.stateRunning && !root.showHelp) {
                root.stepSimulation(dt)
            }
            if (root.gameState === root.stateStart && !root.showHelp) {
                root.stepStartAttractMode(dt)
            }
            if (root.gameState === root.stateRunning && !root.showHelp) {
                root.invaderAnimClock += dt
                if (root.invaderAnimClock >= 0.30) {
                    root.invaderAnimClock = 0
                    root.invaderAnimFrame = 1 - root.invaderAnimFrame
                }
            }
            gameCanvas.requestPaint()
        }
    }

    Item {
        id: spriteCacheLayer
        visible: false

        Canvas {
            id: staticBackgroundCache
            width: root.width
            height: root.height
            onPaint: {
                var bgctx = getContext("2d")
                bgctx.reset()

                var bg = bgctx.createLinearGradient(0, 0, 0, height)
                bg.addColorStop(0, "#060710")
                bg.addColorStop(0.55, "#090c18")
                bg.addColorStop(1, "#020306")
                bgctx.fillStyle = bg
                bgctx.fillRect(0, 0, width, height)

                bgctx.globalAlpha = 0.22
                bgctx.fillStyle = "#203f7f"
                bgctx.beginPath()
                bgctx.arc(width * 0.18, height * 0.2, 170, 0, Math.PI * 2)
                bgctx.fill()
                bgctx.fillStyle = "#27436b"
                bgctx.beginPath()
                bgctx.arc(width * 0.82, height * 0.35, 220, 0, Math.PI * 2)
                bgctx.fill()

                bgctx.globalAlpha = 0.035
                bgctx.fillStyle = "#c7d8ff"
                for (var y = 84; y < height; y += 8) {
                    bgctx.fillRect(0, y, width, 1)
                }
                bgctx.globalAlpha = 1
            }
        }

        Canvas {
            id: playerSpriteCache
            width: 56
            height: 24
            property bool cachePainted: false
            onPaint: {
                var pctx = getContext("2d")
                pctx.reset()
                root.drawPixelSprite(pctx, root.playerSprite, 0, 0, 4, "#8ee9ff", "")
                root.markSpriteCachePainted(playerSpriteCache)
            }
        }

        Canvas {
            id: alienType0Frame0Cache
            width: 36
            height: 24
            property bool cachePainted: false
            onPaint: {
                var c = getContext("2d")
                c.reset()
                root.drawPixelSprite(c, root.invaderSprites[0].a, 0, 0, 3, "#ff8f8f", "")
                root.markSpriteCachePainted(alienType0Frame0Cache)
            }
        }

        Canvas {
            id: alienType0Frame1Cache
            width: 36
            height: 24
            property bool cachePainted: false
            onPaint: {
                var c = getContext("2d")
                c.reset()
                root.drawPixelSprite(c, root.invaderSprites[0].b, 0, 0, 3, "#ff8f8f", "")
                root.markSpriteCachePainted(alienType0Frame1Cache)
            }
        }

        Canvas {
            id: alienType1Frame0Cache
            width: 36
            height: 24
            property bool cachePainted: false
            onPaint: {
                var c = getContext("2d")
                c.reset()
                root.drawPixelSprite(c, root.invaderSprites[1].a, 0, 0, 3, "#ffd67e", "")
                root.markSpriteCachePainted(alienType1Frame0Cache)
            }
        }

        Canvas {
            id: alienType1Frame1Cache
            width: 36
            height: 24
            property bool cachePainted: false
            onPaint: {
                var c = getContext("2d")
                c.reset()
                root.drawPixelSprite(c, root.invaderSprites[1].b, 0, 0, 3, "#ffd67e", "")
                root.markSpriteCachePainted(alienType1Frame1Cache)
            }
        }

        Canvas {
            id: alienType2Frame0Cache
            width: 36
            height: 24
            property bool cachePainted: false
            onPaint: {
                var c = getContext("2d")
                c.reset()
                root.drawPixelSprite(c, root.invaderSprites[2].a, 0, 0, 3, "#98ff95", "")
                root.markSpriteCachePainted(alienType2Frame0Cache)
            }
        }

        Canvas {
            id: alienType2Frame1Cache
            width: 36
            height: 24
            property bool cachePainted: false
            onPaint: {
                var c = getContext("2d")
                c.reset()
                root.drawPixelSprite(c, root.invaderSprites[2].b, 0, 0, 3, "#98ff95", "")
                root.markSpriteCachePainted(alienType2Frame1Cache)
            }
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

            // Apply screen shake effect
            if (root.screenShakeIntensity > 0) {
                var shakeX = (Math.random() - 0.5) * root.screenShakeIntensity
                var shakeY = (Math.random() - 0.5) * root.screenShakeIntensity
                ctx.save()
                ctx.translate(shakeX, shakeY)
            }

            ctx.drawImage(staticBackgroundCache, 0, 0)

            for (var s = 0; s < root.stars.length; ++s) {
                var star = root.stars[s]
                var twinkle = 0.55 + 0.45 * Math.sin(root.renderClock * 1.7 + star.phase)
                ctx.globalAlpha = star.a * twinkle
                ctx.fillStyle = "#e9f2ff"
                ctx.beginPath()
                ctx.arc(star.x, star.y, star.r, 0, Math.PI * 2)
                ctx.fill()
            }
            ctx.globalAlpha = 1

            for (var b = 0; b < root.bunkers.length; ++b) {
                var block = root.bunkers[b]
                if (block.hp <= 0) {
                    continue
                }
                var bunkerColor = block.hp === 3 ? "#5ad65a" : (block.hp === 2 ? "#3fb03f" : "#2a7d2a")
                ctx.fillStyle = bunkerColor
                ctx.fillRect(block.x, block.y, block.w, block.h)
                ctx.fillStyle = "rgba(255, 255, 255, 0.12)"
                ctx.fillRect(block.x, block.y, block.w, 2)
            }

            root.drawPlayer(ctx)

            for (var i = 0; i < root.aliens.length; ++i) {
                var alien = root.aliens[i]
                if (!alien.alive) {
                    continue
                }
                root.drawAlien(ctx, alien)
            }

            for (var p = 0; p < root.playerBullets.length; ++p) {
                var pb = root.playerBullets[p]
                ctx.fillStyle = "#f4f8ff"
                ctx.fillRect(pb.x, pb.y, pb.w, pb.h)
                ctx.fillStyle = "rgba(170, 220, 255, 0.5)"
                ctx.fillRect(pb.x, pb.y + pb.h, pb.w, 6)
            }

            for (var e = 0; e < root.enemyBullets.length; ++e) {
                var eb = root.enemyBullets[e]
                ctx.fillStyle = "#ff9090"
                ctx.fillRect(eb.x, eb.y, eb.w, eb.h)
                ctx.fillStyle = "rgba(255, 109, 109, 0.4)"
                ctx.fillRect(eb.x, eb.y - 5, eb.w, 5)
            }

            for (var hp = 0; hp < root.hitParticles.length; ++hp) {
                var part = root.hitParticles[hp]
                var lifeRatio = part.life / part.maxLife
                ctx.globalAlpha = Math.max(0, Math.min(1, lifeRatio))
                ctx.fillStyle = part.color
                ctx.fillRect(part.x, part.y, part.size, part.size)
            }
            ctx.globalAlpha = 1

            ctx.fillStyle = "rgba(10, 16, 36, 0.7)"
            ctx.fillRect(0, 0, width, 76)
            ctx.fillStyle = "#dce8ff"
            ctx.font = "bold 22px monospace"
            ctx.fillText("SCORE  " + root.score, 22, 32)
            ctx.fillText("HIGH  " + root.highScore, width * 0.5 - 95, 32)
            ctx.fillText("LIVES  " + root.lives, width - 180, 32)
            ctx.font = "bold 20px monospace"
            ctx.fillText("WAVE  " + root.level, width * 0.5 - 60, 62)

            ctx.textAlign = "center"
            if (root.gameState === root.stateStart) {
                ctx.fillStyle = "#dce8ff"
                ctx.font = "bold 48px monospace"
                ctx.fillText("SPACE INVADERS", width * 0.5, height * 0.42)
                ctx.font = "24px monospace"
                ctx.fillText("Press ENTER to start", width * 0.5, height * 0.52)
                ctx.fillText("High Score: " + root.highScore, width * 0.5, height * 0.58)
                ctx.fillText("Press H for help", width * 0.5, height * 0.64)
                ctx.fillText("Move: A/D or Left/Right  Fire: Space", width * 0.5, height * 0.70)
            } else if (root.gameState === root.stateWaveCleared) {
                ctx.fillStyle = "#b5ffb5"
                ctx.font = "bold 46px monospace"
                ctx.fillText("WAVE CLEARED", width * 0.5, height * 0.46)
                ctx.fillStyle = "#dce8ff"
                ctx.font = "24px monospace"
                ctx.fillText("Press ENTER for next wave", width * 0.5, height * 0.55)
            } else if (root.gameState === root.stateGameOver) {
                ctx.fillStyle = "rgba(8, 14, 28, 0.80)"
                ctx.fillRect(width * 0.5 - 260, height * 0.46 - 70, 520, 250)
                ctx.strokeStyle = "rgba(193, 214, 255, 0.45)"
                ctx.lineWidth = 2
                ctx.strokeRect(width * 0.5 - 260, height * 0.46 - 70, 520, 250)
                ctx.fillStyle = "#ffb0b0"
                ctx.font = "bold 46px monospace"
                ctx.fillText("GAME OVER", width * 0.5, height * 0.46)
                ctx.fillStyle = "#dce8ff"
                ctx.font = "24px monospace"
                ctx.fillText("Press ENTER to restart", width * 0.5, height * 0.55)
                ctx.fillText("Score: " + root.score, width * 0.5, height * 0.61)
                ctx.fillText("High Score: " + root.highScore, width * 0.5, height * 0.67)
            } else if (root.gameState === root.statePaused) {
                ctx.fillStyle = "rgba(5, 10, 20, 0.58)"
                ctx.fillRect(0, 0, width, height)
                ctx.fillStyle = "#cfe2ff"
                ctx.font = "bold 48px monospace"
                ctx.fillText("PAUSED", width * 0.5, height * 0.46)
                ctx.font = "24px monospace"
                ctx.fillText("Press P to resume", width * 0.5, height * 0.55)
            }

            if (root.showHelp) {
                ctx.fillStyle = "rgba(8, 14, 28, 0.90)"
                ctx.fillRect(width * 0.5 - 310, height * 0.5 - 210, 620, 420)
                ctx.strokeStyle = "rgba(193, 214, 255, 0.45)"
                ctx.lineWidth = 2
                ctx.strokeRect(width * 0.5 - 310, height * 0.5 - 210, 620, 420)

                ctx.fillStyle = "#cfe2ff"
                ctx.font = "bold 42px monospace"
                ctx.fillText("HELP", width * 0.5, height * 0.5 - 155)

                ctx.fillStyle = "#dce8ff"
                ctx.font = "22px monospace"
                ctx.fillText("Enter  - Start / Next Wave / Restart", width * 0.5, height * 0.5 - 95)
                ctx.fillText("A / Left Arrow   - Move Left", width * 0.5, height * 0.5 - 55)
                ctx.fillText("D / Right Arrow  - Move Right", width * 0.5, height * 0.5 - 15)
                ctx.fillText("Space - Fire", width * 0.5, height * 0.5 + 25)
                ctx.fillText("P - Pause / Resume", width * 0.5, height * 0.5 + 65)
                ctx.fillText("M - Music Mute / Unmute", width * 0.5, height * 0.5 + 105)
                ctx.fillText("- / = - Music Volume Down / Up", width * 0.5, height * 0.5 + 145)
                ctx.fillText("H - Close Help", width * 0.5, height * 0.5 + 185)
            }
            ctx.textAlign = "start"
            // Restore for screen shake effect
            if (root.screenShakeIntensity > 0) {
                ctx.restore()
            }

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
        volume: root.sfxVolume * 1.2
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

        function nextSong() {
            playlistIndex = (playlistIndex + 1) % playlist.length
            pendingPlay = true
        }

        readonly property var playlist: [
            "qrc:/qt/qml/QtSpaceInvaders/assets/music/orbital_siege_loop.ogg",
            "qrc:/qt/qml/QtSpaceInvaders/assets/music/galactic_onslaught.ogg"
        ]
        property int playlistIndex: 0
        property bool pendingPlay: false

        source: playlist[playlistIndex]
        audioOutput: bgmOutput

        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia) {
                nextSong()
            } else if (pendingPlay && mediaStatus === MediaPlayer.LoadedMedia) {
                pendingPlay = false
                play()
            }
        }
    }

    Component.onCompleted: {
        loadHighScore()
        staticBackgroundCache.requestPaint()
        playerSpriteCache.requestPaint()
        alienType0Frame0Cache.requestPaint()
        alienType0Frame1Cache.requestPaint()
        alienType1Frame0Cache.requestPaint()
        alienType1Frame1Cache.requestPaint()
        alienType2Frame0Cache.requestPaint()
        alienType2Frame1Cache.requestPaint()
        createStars()
        resetStartAttractMode()
        updateMusicState()
        gameCanvas.requestPaint()
    }

    onMusicEnabledChanged: updateMusicState()
    onWidthChanged: staticBackgroundCache.requestPaint()
    onHeightChanged: staticBackgroundCache.requestPaint()
}
