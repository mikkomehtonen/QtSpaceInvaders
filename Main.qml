import QtQuick
import QtMultimedia
import QtQuick.LocalStorage

Window {
    id: root
    width: 900
    height: 700
    minimumWidth: 900
    maximumWidth: 900
    minimumHeight: 700
    maximumHeight: 700
    visible: true
    color: "#06070a"
    title: "Qt Space Invaders"
    flags: Qt.Window | Qt.CustomizeWindowHint | Qt.WindowTitleHint | Qt.WindowCloseButtonHint | Qt.WindowMinimizeButtonHint

    readonly property int stateStart: 0
    readonly property int stateRunning: 1
    readonly property int stateWaveCleared: 2
    readonly property int stateGameOver: 3
    readonly property int statePaused: 4
    readonly property int stateVictory: 5

    property int gameState: stateStart
    property int score: 0
    property int highScore: 0
    property int lives: 3
    property int level: 1
    property int bossWaveLevel: 6
    property int bossHitPoints: 28
    property int bombCount: 0
    property int maxBombCount: 3
    property int nextBombScoreThreshold: 1000

    property real playerX: 0
    property real playerY: height - 70
    property real playerWidth: 56
    property real playerHeight: 24
    property real playerSpeed: 360
    property real playerInvulnerabilityDuration: 2.0
    property real playerInvulnerabilityRemaining: 0

    property real playerShotSpeed: 520
    property real bombShotSpeed: playerShotSpeed * 0.5
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
    property real bossMoveClock: 0
    property real bossRetargetClock: 0
    property real bossTargetX: 0
    property real bossBaseY: 95
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
    property bool highScoreDirty: false

    property bool leftPressed: false
    property real attractTargetX: 0
    property real screenShakeIntensity: 0
    property real screenShakeDuration: 0
    property bool rightPressed: false
    property bool shootPressed: false

    property var aliens: []
    property var aliveAliensCache: []
    property var aliveAliensByRowCache: []
    property var playerBullets: []
    property var playerBombs: []
    property var enemyBullets: []
    property var bunkers: []
    property var stars: []
    property var hitParticles: []
    property var fireworks: []
    property real fireworkSpawnClock: 0
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
        if (playerInvulnerabilityRemaining > 0) {
            var pulse = 0.55 + 0.45 * Math.sin(renderClock * 16)
            var centerX = playerX + playerWidth * 0.5
            var centerY = playerY + playerHeight * 0.5
            var radius = Math.max(playerWidth, playerHeight) * (0.75 + 0.20 * pulse)
            ctx.save()
            ctx.globalAlpha = 0.20 + 0.16 * pulse
            ctx.fillStyle = "#ffffff"
            ctx.beginPath()
            ctx.arc(centerX, centerY, radius, 0, Math.PI * 2)
            ctx.fill()
            ctx.restore()
        }

        if (spriteCacheReady) {
            ctx.drawImage(playerSpriteCache, playerX, playerY)
        } else {
            drawPixelSprite(ctx, playerSprite, playerX, playerY, 4, "#8ee9ff", "")
        }
    }

    function drawAlien(ctx, alien) {
        if (alien.boss) {
            var hpRatio = Math.max(0, alien.hp) / alien.maxHp
            var pulse = 0.55 + 0.45 * Math.sin(renderClock * 5)

            ctx.fillStyle = "rgba(255, 115, 90, " + (0.18 + pulse * 0.10) + ")"
            ctx.beginPath()
            ctx.arc(alien.x + alien.w * 0.5, alien.y + alien.h * 0.5, alien.w * 0.62, 0, Math.PI * 2)
            ctx.fill()

            ctx.fillStyle = "#ff7a5d"
            ctx.fillRect(alien.x, alien.y + 8, alien.w, alien.h - 12)
            ctx.fillStyle = "#ff987f"
            ctx.fillRect(alien.x + 8, alien.y, alien.w - 16, 16)
            ctx.fillStyle = "#2b1420"
            ctx.fillRect(alien.x + 16, alien.y + 12, 12, 8)
            ctx.fillRect(alien.x + alien.w - 28, alien.y + 12, 12, 8)
            ctx.fillStyle = "#ffe0d7"
            ctx.fillRect(alien.x + 12, alien.y + 3, alien.w - 24, 4)

            ctx.fillStyle = "rgba(20, 8, 14, 0.7)"
            ctx.fillRect(alien.x, alien.y - 12, alien.w, 5)
            ctx.fillStyle = "#ff6f6f"
            ctx.fillRect(alien.x, alien.y - 12, alien.w * hpRatio, 5)
            return
        }

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
            flushHighScoreIfNeeded()
        } else if (nextState === stateVictory) {
            playSfx(sfxWaveClear)
            flushHighScoreIfNeeded()
            fireworks = []
            fireworkSpawnClock = 0
            spawnFireworkBurst(width * 0.32, height * 0.34)
            spawnFireworkBurst(width * 0.68, height * 0.30)
        } else if (nextState === stateGameOver) {
            playSfx(sfxGameOver)
            flushHighScoreIfNeeded()
        }
        if (nextState === stateGameOver || nextState === stateVictory) {
            // Reset screen shake when run ends
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

    function flushHighScoreIfNeeded() {
        if (!highScoreDirty) {
            return
        }
        saveHighScore()
        highScoreDirty = false
    }

    function updateHighScoreIfNeeded() {
        if (score > highScore) {
            highScore = score
            highScoreDirty = true
        }
    }

    function updateBombRewards() {
        while (nextBombScoreThreshold <= score) {
            if (bombCount < maxBombCount) {
                bombCount += 1
            }
            nextBombScoreThreshold += 1000
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
        var wave = []
        if (level === bossWaveLevel) {
            var bossW = 120
            var bossH = 84
            var spawnY = 95
            wave.push({
                x: (width - bossW) * 0.5,
                y: spawnY,
                w: bossW,
                h: bossH,
                row: 0,
                hp: bossHitPoints,
                maxHp: bossHitPoints,
                boss: true,
                alive: true
            })
            bossBaseY = spawnY
            bossMoveClock = 0
            bossRetargetClock = 0
            bossTargetX = randRange(40, width - bossW - 40)
            alienSpeed = 130
            alienDrop = 16
            enemyShotSpeed = 320
            enemyShootDelay = 0.40
            maxEnemyBullets = 4
        } else {
            var rows = currentWaveRows
            var cols = currentWaveCols
            var spacingX = 54
            var spacingY = 42
            var alienW = 36
            var alienH = 26
            var formationWidth = (cols - 1) * spacingX + alienW
            var startX = (width - formationWidth) * 0.5
            var startY = 90

            for (var r = 0; r < rows; ++r) {
                for (var c = 0; c < cols; ++c) {
                    wave.push({
                        x: startX + c * spacingX,
                        y: startY + r * spacingY,
                        w: alienW,
                        h: alienH,
                        row: r,
                        hp: 1,
                        maxHp: 1,
                        boss: false,
                        alive: true
                    })
                }
            }
        }

        aliens = wave
        aliveAliensCache = wave
        aliveAliensByRowCache = []
        playerBullets = []
        playerBombs = []
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
        playerBombs = []
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
        bombCount = 0
        maxBombCount = 3
        nextBombScoreThreshold = 1000
        showHelp = false
        playerX = (width - playerWidth) * 0.5
        playerY = height - 70
        playerInvulnerabilityRemaining = 0
        bossMoveClock = 0
        bossRetargetClock = 0
        fireworks = []
        fireworkSpawnClock = 0
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

        for (var b = 0; b < playerBombs.length; ++b) {
            playerBombs[b].y -= bombShotSpeed * dt
            if (playerBombs[b].y + playerBombs[b].h < 0) {
                playerBombs[b].dead = true
            }
        }

        for (var j = 0; j < enemyBullets.length; ++j) {
            var enemyBullet = enemyBullets[j]
            enemyBullet.y += enemyShotSpeed * dt
            enemyBullet.x += (enemyBullet.vx || 0) * dt

            if (enemyBullet.homing) {
                var bulletCenterX = enemyBullet.x + enemyBullet.w * 0.5
                var playerCenterX = playerX + playerWidth * 0.5
                var steer = clamp((playerCenterX - bulletCenterX) * 2.6, -180, 180)
                enemyBullet.vx = clamp((enemyBullet.vx || 0) + steer * dt, -260, 260)
            }

            if (enemyBullet.y > height || enemyBullet.x + enemyBullet.w < 0 || enemyBullet.x > width) {
                enemyBullet.dead = true
            }
        }
    }

    function updateAliens(dt) {
        var aliveCount = 0
        var minX = 1e9
        var maxX = -1e9
        var aliveList = []
        var byRow = []

        for (var i = 0; i < aliens.length; ++i) {
            var currentAlien = aliens[i]
            if (!currentAlien.alive) {
                continue
            }
            aliveList.push(currentAlien)
            if (!byRow[currentAlien.row]) {
                byRow[currentAlien.row] = []
            }
            byRow[currentAlien.row].push(currentAlien)
            aliveCount += 1
            minX = Math.min(minX, currentAlien.x)
            maxX = Math.max(maxX, currentAlien.x + currentAlien.w)
        }

        aliveAliensCache = aliveList
        aliveAliensByRowCache = byRow

        if (aliveCount === 0) {
            if (level === bossWaveLevel) {
                setGameState(stateVictory)
            } else {
                setGameState(stateWaveCleared)
            }
            return
        }

        if (level === bossWaveLevel && aliveList.length === 1 && aliveList[0].boss) {
            var boss = aliveList[0]
            bossMoveClock += dt
            bossRetargetClock += dt

            if (bossRetargetClock >= 0.85) {
                bossRetargetClock = 0
                bossTargetX = randRange(35, width - boss.w - 35)
            }

            var trackStep = alienSpeed * dt
            var moveToTarget = clamp(bossTargetX - boss.x, -trackStep, trackStep)
            var weaveOffset = Math.sin(bossMoveClock * 4.8) * 150 * dt
            boss.x += moveToTarget + weaveOffset
            boss.x = clamp(boss.x, 15, width - boss.w - 15)

            var yWave = Math.sin(bossMoveClock * 2.4) * 22 + Math.sin(bossMoveClock * 5.3) * 9
            boss.y = bossBaseY + yWave

            aliveAliensCache = [boss]
            aliveAliensByRowCache = [[boss]]

            if (boss.y + boss.h >= playerY - 6) {
                setGameState(stateGameOver)
            }
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
        var isBossShooter = !!shooter.boss
        var bulletW = isBossShooter ? 12 : 4
        var bulletH = isBossShooter ? 24 : 14
        var bulletDamage = isBossShooter ? 3 : 1
        var bulletVx = isBossShooter ? clamp((playerX + playerWidth * 0.5 - (shooter.x + shooter.w * 0.5)) * 0.9, -180, 180) : 0
        enemyBullets.push({
            x: shooter.x + shooter.w * 0.5 - bulletW * 0.5,
            y: shooter.y + shooter.h,
            w: bulletW,
            h: bulletH,
            vx: bulletVx,
            homing: isBossShooter,
            damage: bulletDamage,
            dead: false
        })

        // Higher levels occasionally fire a second shot to ramp pressure.
        var bonusShotChance = isBossShooter ? 0 : Math.min(0.45, (level - 1) * 0.06)
        if (enemyBullets.length < maxEnemyBullets && Math.random() < bonusShotChance) {
            var shooter2 = shooters[Math.floor(Math.random() * shooters.length)]
            enemyBullets.push({
                x: shooter2.x + shooter2.w * 0.5 - 2,
                y: shooter2.y + shooter2.h,
                w: 4,
                h: 14,
                vx: 0,
                homing: false,
                damage: 1,
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

    function launchBomb() {
        if (bombCount <= 0) {
            return
        }

        bombCount -= 1
        playerBombs.push({
            x: playerX + playerWidth * 0.5 - 5,
            y: playerY - 14,
            w: 10,
            h: 16,
            dead: false
        })
        playSfx(sfxShoot)
    }

    function cleanupProjectiles() {
        for (var p = playerBullets.length - 1; p >= 0; --p) {
            if (playerBullets[p].dead) {
                playerBullets.splice(p, 1)
            }
        }

        for (var b = playerBombs.length - 1; b >= 0; --b) {
            if (playerBombs[b].dead) {
                playerBombs.splice(b, 1)
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

    function spawnFireworkBurst(x, y) {
        var palette = ["#ffd56a", "#8ee9ff", "#ff92b0", "#9dfd8f", "#ffffff"]
        for (var i = 0; i < 34; ++i) {
            var angle = Math.random() * Math.PI * 2
            var speed = 90 + Math.random() * 190
            var life = 0.75 + Math.random() * 0.7
            fireworks.push({
                x: x,
                y: y,
                vx: Math.cos(angle) * speed,
                vy: Math.sin(angle) * speed,
                life: life,
                maxLife: life,
                size: 1.8 + Math.random() * 2.6,
                color: palette[Math.floor(Math.random() * palette.length)]
            })
        }
    }

    function updateFireworks(dt) {
        var out = []
        for (var i = 0; i < fireworks.length; ++i) {
            var p = fireworks[i]
            p.life -= dt
            if (p.life <= 0) {
                continue
            }
            p.x += p.vx * dt
            p.y += p.vy * dt
            p.vx *= 0.985
            p.vy = p.vy * 0.985 + 120 * dt
            out.push(p)
        }
        fireworks = out
    }

    function stepVictoryEffects(dt) {
        fireworkSpawnClock += dt
        if (fireworkSpawnClock >= 0.30) {
            fireworkSpawnClock = 0
            spawnFireworkBurst(randRange(90, width - 90), randRange(80, height * 0.52))
        }
        updateFireworks(dt)
    }

    function applyAlienDamage(alien, damage) {
        if (!alien.alive) {
            return
        }

        alien.hp = Math.max(0, alien.hp - damage)
        var hitColor = alien.boss ? "#ff7a5d" : alienColorForRow(alien.row)
        spawnAlienHitParticles(alien.x + alien.w * 0.5, alien.y + alien.h * 0.5, hitColor)
        playSfx(sfxAlienHit)

        if (alien.hp <= 0) {
            alien.alive = false
            score += alien.boss ? 2000 : (6 - alien.row) * 10
            updateHighScoreIfNeeded()
            updateBombRewards()
        }
    }

    function handleCollisions() {
        for (var i = 0; i < playerBullets.length; ++i) {
            var pb = playerBullets[i]
            if (pb.dead) {
                continue
            }

            var pbTop = pb.y
            var pbBottom = pb.y + pb.h
            for (var row = 0; row < aliveAliensByRowCache.length && !pb.dead; ++row) {
                var rowAliens = aliveAliensByRowCache[row]
                if (!rowAliens || rowAliens.length === 0) {
                    continue
                }

                var rowAnchor = null
                for (var ra = 0; ra < rowAliens.length; ++ra) {
                    if (rowAliens[ra].alive) {
                        rowAnchor = rowAliens[ra]
                        break
                    }
                }
                if (!rowAnchor) {
                    continue
                }
                if (pbBottom <= rowAnchor.y || pbTop >= rowAnchor.y + rowAnchor.h) {
                    continue
                }

                for (var a = 0; a < rowAliens.length; ++a) {
                    var alien = rowAliens[a]
                    if (!alien.alive) {
                        continue
                    }
                    if (aabb(pb.x, pb.y, pb.w, pb.h, alien.x, alien.y, alien.w, alien.h)) {
                        pb.dead = true
                        applyAlienDamage(alien, 1)
                        break
                    }
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

        for (var m = 0; m < playerBombs.length; ++m) {
            var bomb = playerBombs[m]
            if (bomb.dead) {
                continue
            }

            var bombTop = bomb.y
            var bombBottom = bomb.y + bomb.h
            for (var bombRow = 0; bombRow < aliveAliensByRowCache.length && !bomb.dead; ++bombRow) {
                var bombRowAliens = aliveAliensByRowCache[bombRow]
                if (!bombRowAliens || bombRowAliens.length === 0) {
                    continue
                }

                var bombRowAnchor = null
                for (var bra = 0; bra < bombRowAliens.length; ++bra) {
                    if (bombRowAliens[bra].alive) {
                        bombRowAnchor = bombRowAliens[bra]
                        break
                    }
                }
                if (!bombRowAnchor) {
                    continue
                }
                if (bombBottom <= bombRowAnchor.y || bombTop >= bombRowAnchor.y + bombRowAnchor.h) {
                    continue
                }

                for (var q = 0; q < bombRowAliens.length; ++q) {
                    var hitAlien = bombRowAliens[q]
                    if (!hitAlien.alive) {
                        continue
                    }

                    if (!aabb(bomb.x, bomb.y, bomb.w, bomb.h, hitAlien.x, hitAlien.y, hitAlien.w, hitAlien.h)) {
                        continue
                    }

                    bomb.dead = true
                    for (var r = 0; r < aliveAliensCache.length; ++r) {
                        var nearAlien = aliveAliensCache[r]
                        if (!nearAlien.alive) {
                            continue
                        }

                        var adjacentX = Math.abs(nearAlien.x - hitAlien.x) <= (hitAlien.w + 20)
                        var adjacentY = Math.abs(nearAlien.y - hitAlien.y) <= (hitAlien.h + 16)
                        if (!adjacentX || !adjacentY) {
                            continue
                        }

                        applyAlienDamage(nearAlien, nearAlien === hitAlien ? 4 : 2)
                    }
                    break
                }
            }

            if (bomb.dead) {
                continue
            }

            for (var br = 0; br < bunkers.length; ++br) {
                var bunker = bunkers[br]
                if (bunker.hp <= 0) {
                    continue
                }
                if (aabb(bomb.x, bomb.y, bomb.w, bomb.h, bunker.x, bunker.y, bunker.w, bunker.h)) {
                    bunker.hp = Math.max(0, bunker.hp - 3)
                    bomb.dead = true
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
                if (playerInvulnerabilityRemaining > 0) {
                    continue
                }
                lives -= 1
                // Add screen shake effect when player is hit
                screenShakeIntensity = 20
                screenShakeDuration = 0.3

                playSfx(sfxPlayerHit)
                if (lives <= 0) {
                    playerInvulnerabilityRemaining = 0
                    setGameState(stateGameOver)
                } else {
                    playerInvulnerabilityRemaining = playerInvulnerabilityDuration
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
                    bunkerCell.hp -= (eb.damage || 1)
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
        for (var b = 0; b < bunkers.length; ++b) {
            var block = bunkers[b]
            if (block.hp <= 0) continue

            var blockTop = block.y
            var blockBottom = block.y + block.h
            for (var row = 0; row < aliveAliensByRowCache.length; ++row) {
                var rowAliens = aliveAliensByRowCache[row]
                if (!rowAliens || rowAliens.length === 0) {
                    continue
                }

                var rowAnchor = null
                for (var ra = 0; ra < rowAliens.length; ++ra) {
                    if (rowAliens[ra].alive) {
                        rowAnchor = rowAliens[ra]
                        break
                    }
                }
                if (!rowAnchor) {
                    continue
                }
                if (blockBottom <= rowAnchor.y || blockTop >= rowAnchor.y + rowAnchor.h) {
                    continue
                }

                for (var a = 0; a < rowAliens.length; ++a) {
                    var alien = rowAliens[a]
                    if (!alien.alive) continue

                    if (aabb(alien.x, alien.y, alien.w, alien.h, block.x, block.y, block.w, block.h)) {
                        block._crush = (block._crush || 0) + crushRate * dt
                        if (block._crush >= 1) {
                            var dmg = Math.floor(block._crush)
                            block._crush -= dmg
                            block.hp -= dmg
                        }
                        break
                    }
                }
            }
        }
    }

    function stepSimulation(dt) {
        updateHitParticles(dt)
        playerInvulnerabilityRemaining = Math.max(0, playerInvulnerabilityRemaining - dt)
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
            if (root.gameState === root.stateRunning && (event.key === Qt.Key_B)) {
                root.launchBomb()
            }

            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.gameState === root.stateStart) {
                root.startNewGame()
            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.gameState === root.stateGameOver) {
                root.startNewGame()
            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.gameState === root.stateVictory) {
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
            if (root.gameState === root.stateVictory && !root.showHelp) {
                root.stepVictoryEffects(dt)
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

            for (var pbm = 0; pbm < root.playerBombs.length; ++pbm) {
                var bomb = root.playerBombs[pbm]
                // Bomb flies upward: draw pointed nose at the top.
                ctx.fillStyle = "#ffd27a"
                ctx.beginPath()
                ctx.moveTo(bomb.x + bomb.w * 0.5, bomb.y - 5)
                ctx.lineTo(bomb.x, bomb.y + 3)
                ctx.lineTo(bomb.x + bomb.w, bomb.y + 3)
                ctx.closePath()
                ctx.fill()
                ctx.fillRect(bomb.x + 1, bomb.y + 3, bomb.w - 2, bomb.h - 3)
                ctx.fillStyle = "rgba(255, 160, 60, 0.5)"
                ctx.fillRect(bomb.x + 2, bomb.y + bomb.h, bomb.w - 4, 7)
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

            for (var fw = 0; fw < root.fireworks.length; ++fw) {
                var spark = root.fireworks[fw]
                var sparkLife = spark.life / spark.maxLife
                ctx.globalAlpha = Math.max(0, Math.min(1, sparkLife))
                ctx.fillStyle = spark.color
                ctx.fillRect(spark.x, spark.y, spark.size, spark.size)
            }
            ctx.globalAlpha = 1

            ctx.fillStyle = "rgba(10, 16, 36, 0.7)"
            ctx.fillRect(0, 0, width, 76)
            ctx.fillStyle = "#dce8ff"
            ctx.font = "bold 22px monospace"
            ctx.fillText("SCORE  " + root.score, 22, 32)
            ctx.fillText("HIGH  " + root.highScore, width * 0.5 - 95, 32)
            ctx.fillText("LIVES  " + root.lives, width - 180, 32)
            ctx.fillText("BOMBS  " + root.bombCount, width - 180, 62)
            ctx.font = "bold 20px monospace"
            ctx.fillText("WAVE  " + (root.level === root.bossWaveLevel ? "BOSS" : root.level), width * 0.5 - 60, 62)

            ctx.textAlign = "center"
            if (root.gameState === root.stateStart) {
                ctx.fillStyle = "#dce8ff"
                ctx.font = "bold 48px monospace"
                ctx.fillText("SPACE INVADERS", width * 0.5, height * 0.23)

                ctx.fillStyle = "rgba(8, 14, 28, 0.88)"
                ctx.fillRect(width * 0.5 - 345, height * 0.56 - 190, 690, 390)
                ctx.strokeStyle = "rgba(193, 214, 255, 0.45)"
                ctx.lineWidth = 2
                ctx.strokeRect(width * 0.5 - 345, height * 0.56 - 190, 690, 390)

                ctx.fillStyle = "#cfe2ff"
                ctx.font = "bold 36px monospace"
                ctx.fillText("MISSION BRIEF", width * 0.5, height * 0.56 - 130)

                ctx.fillStyle = "#dce8ff"
                ctx.font = "22px monospace"
                ctx.fillText("Unknown fleets breached orbit and started", width * 0.5, height * 0.56 - 75)
                ctx.fillText("striking major cities. Defense command is gone.", width * 0.5, height * 0.56 - 40)
                ctx.fillText("Your interceptor is the last ship still responding.", width * 0.5, height * 0.56 - 5)
                ctx.fillText("Hold the line through six attack waves.", width * 0.5, height * 0.56 + 35)
                ctx.fillText("Wave six brings their warlord.", width * 0.5, height * 0.56 + 70)
                ctx.fillText("If you fall, civilization falls with you.", width * 0.5, height * 0.56 + 105)
                ctx.fillText("Press H for controls and combat tips", width * 0.5, height * 0.56 + 150)
                ctx.fillText("Press ENTER to start", width * 0.5, height * 0.56 + 175)
            } else if (root.gameState === root.stateWaveCleared) {
                ctx.fillStyle = "#b5ffb5"
                ctx.font = "bold 46px monospace"
                ctx.fillText("WAVE CLEARED", width * 0.5, height * 0.46)
                ctx.fillStyle = "#dce8ff"
                ctx.font = "24px monospace"
                if (root.level + 1 === root.bossWaveLevel) {
                    ctx.fillText("Press ENTER for BOSS WAVE", width * 0.5, height * 0.55)
                } else {
                    ctx.fillText("Press ENTER for next wave", width * 0.5, height * 0.55)
                }
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
            } else if (root.gameState === root.stateVictory) {
                ctx.fillStyle = "rgba(8, 14, 28, 0.80)"
                ctx.fillRect(width * 0.5 - 280, height * 0.46 - 70, 560, 250)
                ctx.strokeStyle = "rgba(193, 214, 255, 0.45)"
                ctx.lineWidth = 2
                ctx.strokeRect(width * 0.5 - 280, height * 0.46 - 70, 560, 250)
                ctx.fillStyle = "#b5ffb5"
                ctx.font = "bold 46px monospace"
                ctx.fillText("BOSS DEFEATED", width * 0.5, height * 0.46)
                ctx.fillStyle = "#dce8ff"
                ctx.font = "24px monospace"
                ctx.fillText("You cleared all waves", width * 0.5, height * 0.55)
                ctx.fillText("Press ENTER to restart", width * 0.5, height * 0.61)
                ctx.fillText("Score: " + root.score, width * 0.5, height * 0.67)
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
                ctx.fillText("A / Left Arrow   - Move Left", width * 0.5, height * 0.5 - 60)
                ctx.fillText("D / Right Arrow  - Move Right", width * 0.5, height * 0.5 - 25)
                ctx.fillText("Space - Fire", width * 0.5, height * 0.5 + 10)
                ctx.fillText("B - Launch Bomb (every 1000 points, max 3)", width * 0.5, height * 0.5 + 45)
                ctx.fillText("P - Pause / Resume", width * 0.5, height * 0.5 + 80)
                ctx.fillText("M - Music Mute / Unmute", width * 0.5, height * 0.5 + 115)
                ctx.fillText("- / = - Music Volume Down / Up", width * 0.5, height * 0.5 + 150)
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
        highScoreDirty = false
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
    onVisibilityChanged: {
        if (visibility === Window.Hidden || visibility === Window.Minimized) {
            flushHighScoreIfNeeded()
        }
        if (visibility === Window.Maximized || visibility === Window.FullScreen) {
            visibility = Window.Windowed
        }
    }

    onClosing: function(closeEvent) {
        flushHighScoreIfNeeded()
    }
}
