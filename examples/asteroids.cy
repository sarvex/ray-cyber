-- Copyright (c) 2023 Cyber (See LICENSE)

-- Asteroids, a game ported from Raylib examples.
-- Original authors: Ian Eito, Albert Martos and Ramon Santamaria

import os 'os'
import m 'math'
--import ray 'https://github.com/fubark/ray-cyber'
import ray '../mod.cy'

var DEG2RAD: m.pi/180

-- Some Constants
var PLAYER_BASE_SIZE: 20
var PLAYER_SPEED: 6
var PLAYER_MAX_SHOOTS: 10

var METEORS_SPEED number: 2
var MAX_BIG_METEORS number: 4
var MAX_MEDIUM_METEORS number: 8
var MAX_SMALL_METEORS number: 16

-- Types and Structures Definition
type Player object:
    position Vec2
    speed Vec2
    acceleration number
    rotation number
    collider Vec3
    color ray.Color

type Shoot object:
    position Vec2
    speed Vec2
    radius number
    rotation number
    lifeSpawn number
    active boolean
    color ray.Color

type Meteor object:
    position Vec2
    speed Vec2
    radius number
    active boolean
    color ray.Color

type Vec2 ray.Vector2

type Vec3 object:
    x number
    y number
    z number

-- Global Variables Declaration
var screenWidth number: 800
var screenHeight number: 450

var gameOver: false
var pause: false
var victory: false

-- NOTE: Defined triangle is isosceles with common angles of 70 degrees.
var shipHeight: 0

var player Player: Player{}
var shoot: arrayFill(Shoot{}, number(PLAYER_MAX_SHOOTS))
var bigMeteor: arrayFill(Meteor{}, number(MAX_BIG_METEORS))
var mediumMeteor: arrayFill(Meteor{}, number(MAX_MEDIUM_METEORS))
var smallMeteor: arrayFill(Meteor{}, number(MAX_SMALL_METEORS))

var midMeteorsCount: 0
var smallMeteorsCount: 0
var destroyedMeteorsCount: 0

-- Program main entry point
main()
func main():
    -- Initialization (Note windowTitle is unused on Android)
    ray.InitWindow(screenWidth, screenHeight, 'classic game: asteroids')
    InitGame()

    ray.SetTargetFPS(60)

    -- Main game loop
    while !ray.WindowShouldClose():    -- Detect window close button or ESC key
        UpdateDrawFrame()
    
    -- De-Initialization
    UnloadGame()         -- Unload loaded data (textures, sounds, models...)
    ray.CloseWindow()    -- Close window and OpenGL context

-- Initialize game variables
func InitGame():
    posx = 0
    posy = 0
    velx = 0
    vely = 0
    correctRange = false
    static victory = false
    static pause = false

    static shipHeight = (PLAYER_BASE_SIZE/2)/m.tan(20*DEG2RAD)

    -- Initialization player
    player.position = Vec2{ x: screenWidth/2, y: screenHeight/2 - shipHeight/2 }
    player.speed = Vec2{ x: 0, y: 0}
    player.acceleration = 0
    player.rotation = 0
    player.collider = Vec3{
        x: player.position.x + m.sin(player.rotation*DEG2RAD)*(shipHeight/2.5),
        y: player.position.y - m.cos(player.rotation*DEG2RAD)*(shipHeight/2.5),
        z: 12,
    }
    player.color = ray.LIGHTGRAY

    static destroyedMeteorsCount = 0

    -- Initialization shoot
    for 0..PLAYER_MAX_SHOOTS each i:
        shoot[i].position = Vec2{ x: 0, y: 0 }
        shoot[i].speed = Vec2{ x: 0, y: 0 }
        shoot[i].radius = 2
        shoot[i].active = false
        shoot[i].lifeSpawn = 0
        shoot[i].color = ray.WHITE

    for 0..MAX_BIG_METEORS each i:
        posx = ray.GetRandomValue(0, screenWidth)

        while !correctRange:
            if posx > screenWidth/2 - 150 and posx < screenWidth/2 + 150:
                posx = ray.GetRandomValue(0, screenWidth)
            else: correctRange = true

        correctRange = false

        posy = ray.GetRandomValue(0, screenHeight)

        while !correctRange:
            if posy > screenHeight/2 - 150 and posy < screenHeight/2 + 150:
                posy = ray.GetRandomValue(0, screenHeight)
            else: correctRange = true

        bigMeteor[i].position = Vec2{x: posx, y: posy}

        correctRange = false
        velx = ray.GetRandomValue(-METEORS_SPEED, METEORS_SPEED)
        vely = ray.GetRandomValue(-METEORS_SPEED, METEORS_SPEED)

        while !correctRange:
            if velx == 0 and vely == 0:
                velx = ray.GetRandomValue(-METEORS_SPEED, METEORS_SPEED)
                vely = ray.GetRandomValue(-METEORS_SPEED, METEORS_SPEED)
            else: correctRange = true

        bigMeteor[i].speed = Vec2{ x: velx, y: vely}
        bigMeteor[i].radius = 40
        bigMeteor[i].active = true
        bigMeteor[i].color = ray.BLUE

    for 0..MAX_MEDIUM_METEORS each i:
        mediumMeteor[i].position = Vec2{ x: -100, y: -100 }
        mediumMeteor[i].speed = Vec2{ x: 0, y: 0 }
        mediumMeteor[i].radius = 20
        mediumMeteor[i].active = false
        mediumMeteor[i].color = ray.BLUE

    for 0..MAX_SMALL_METEORS each i:
        smallMeteor[i].position = Vec2{ x: -100, y: -100 }
        smallMeteor[i].speed = Vec2{ x: 0, y: 0 }
        smallMeteor[i].radius = 10
        smallMeteor[i].active = false
        smallMeteor[i].color = ray.BLUE

    static midMeteorsCount = 0
    static smallMeteorsCount = 0

-- Update game (one frame)
func UpdateGame():
    static pause
    static gameOver
    static destroyedMeteorsCount
    static midMeteorsCount
    static smallMeteorsCount

    if !gameOver:
        if ray.IsKeyPressed(0u'P'):
            pause = !pause

        if !pause:
            -- Player logic: rotation
            if ray.IsKeyDown(ray.KEY_LEFT): player.rotation -= 5
            if ray.IsKeyDown(ray.KEY_RIGHT): player.rotation += 5

            -- Player logic: speed
            player.speed.x = m.sin(player.rotation*DEG2RAD)*PLAYER_SPEED
            player.speed.y = m.cos(player.rotation*DEG2RAD)*PLAYER_SPEED

            -- Player logic: acceleration
            if ray.IsKeyDown(ray.KEY_UP):
                if player.acceleration < 1: player.acceleration += 0.04
            else:
                if player.acceleration > 0: player.acceleration -= 0.02
                else player.acceleration < 0: player.acceleration = 0

            if ray.IsKeyDown(ray.KEY_DOWN):
                if player.acceleration > 0: player.acceleration -= 0.04
                else player.acceleration < 0: player.acceleration = 0

            -- Player logic: movement
            player.position.x += player.speed.x*player.acceleration
            player.position.y -= player.speed.y*player.acceleration

            -- Collision logic: player vs walls
            if player.position.x > screenWidth + shipHeight: player.position.x = -shipHeight
            else player.position.x < -shipHeight: player.position.x = screenWidth + shipHeight
            if player.position.y > (screenHeight + shipHeight): player.position.y = -shipHeight
            else player.position.y < -shipHeight: player.position.y = screenHeight + shipHeight

            -- Player shoot logic
            if ray.IsKeyPressed(ray.KEY_SPACE):
                for 0..PLAYER_MAX_SHOOTS each i:
                    if !shoot[i].active:
                        shoot[i].position = Vec2{
                            x: player.position.x + m.sin(player.rotation*DEG2RAD)*(shipHeight),
                            y: player.position.y - m.cos(player.rotation*DEG2RAD)*(shipHeight)
                        }
                        shoot[i].active = true
                        shoot[i].speed.x = 1.5*m.sin(player.rotation*DEG2RAD)*PLAYER_SPEED
                        shoot[i].speed.y = 1.5*m.cos(player.rotation*DEG2RAD)*PLAYER_SPEED
                        shoot[i].rotation = player.rotation
                        break

            -- Shoot life timer
            for 0..PLAYER_MAX_SHOOTS each i:
                if shoot[i].active: shoot[i].lifeSpawn += 1

            -- Shot logic
            for 0..PLAYER_MAX_SHOOTS each i:
                if shoot[i].active:
                    -- Movement
                    shoot[i].position.x += shoot[i].speed.x
                    shoot[i].position.y -= shoot[i].speed.y

                    -- Collision logic: shoot vs walls
                    if shoot[i].position.x > screenWidth + shoot[i].radius:
                        shoot[i].active = false
                        shoot[i].lifeSpawn = 0
                    else shoot[i].position.x < 0 - shoot[i].radius:
                        shoot[i].active = false
                        shoot[i].lifeSpawn = 0
                    if shoot[i].position.y > screenHeight + shoot[i].radius:
                        shoot[i].active = false
                        shoot[i].lifeSpawn = 0
                    else shoot[i].position.y < 0 - shoot[i].radius:
                        shoot[i].active = false
                        shoot[i].lifeSpawn = 0

                    -- Life of shoot
                    if shoot[i].lifeSpawn >= 60:
                        shoot[i].position = Vec2{ x: 0, y: 0 }
                        shoot[i].speed = Vec2{ x: 0, y: 0 }
                        shoot[i].lifeSpawn = 0
                        shoot[i].active = false

            -- Collision logic: player vs meteors
            player.collider = Vec3{
                x: player.position.x + m.sin(player.rotation*DEG2RAD)*(shipHeight/2.5),
                y: player.position.y - m.cos(player.rotation*DEG2RAD)*(shipHeight/2.5),
                z: 12
            }

            for 0..MAX_BIG_METEORS each a:
                meteor = bigMeteor[a] as Meteor
                if ray.CheckCollisionCircles(
                    Vec2{ x: player.collider.x, y: player.collider.y}, player.collider.z,
                    meteor.position, meteor.radius) and meteor.active:
                    gameOver = true

            for 0..MAX_MEDIUM_METEORS each a:
                meteor = mediumMeteor[a] as Meteor
                if ray.CheckCollisionCircles(
                    Vec2{ x: player.collider.x, y: player.collider.y}, player.collider.z,
                    meteor.position, meteor.radius) and meteor.active:
                    gameOver = true

            for 0..MAX_SMALL_METEORS each a:
                meteor = smallMeteor[a] as Meteor
                if ray.CheckCollisionCircles(
                    Vec2{ x: player.collider.x, y: player.collider.y}, player.collider.z,
                    meteor.position, meteor.radius) and meteor.active:
                    gameOver = true

            -- Meteors logic: big meteors
            for 0..MAX_BIG_METEORS each i:
                if bigMeteor[i].active:
                    -- Movement
                    bigMeteor[i].position.x += bigMeteor[i].speed.x
                    bigMeteor[i].position.y += bigMeteor[i].speed.y

                    -- Collision logic: meteor vs wall
                    if bigMeteor[i].position.x > screenWidth + bigMeteor[i].radius: bigMeteor[i].position.x = -(bigMeteor[i].radius)
                    else bigMeteor[i].position.x < 0 - bigMeteor[i].radius: bigMeteor[i].position.x = screenWidth + bigMeteor[i].radius
                    if bigMeteor[i].position.y > screenHeight + bigMeteor[i].radius: bigMeteor[i].position.y = -(bigMeteor[i].radius)
                    else bigMeteor[i].position.y < 0 - bigMeteor[i].radius: bigMeteor[i].position.y = screenHeight + bigMeteor[i].radius

            -- Meteors logic: medium meteors
            for i..MAX_MEDIUM_METEORS each i:
                if mediumMeteor[i].active:
                    -- Movement
                    mediumMeteor[i].position.x += mediumMeteor[i].speed.x
                    mediumMeteor[i].position.y += mediumMeteor[i].speed.y

                    -- Collision logic: meteor vs wall
                    if mediumMeteor[i].position.x > screenWidth + mediumMeteor[i].radius: mediumMeteor[i].position.x = -(mediumMeteor[i].radius)
                    else mediumMeteor[i].position.x < 0 - mediumMeteor[i].radius: mediumMeteor[i].position.x = screenWidth + mediumMeteor[i].radius
                    if mediumMeteor[i].position.y > screenHeight + mediumMeteor[i].radius: mediumMeteor[i].position.y = -(mediumMeteor[i].radius)
                    else mediumMeteor[i].position.y < 0 - mediumMeteor[i].radius: mediumMeteor[i].position.y = screenHeight + mediumMeteor[i].radius

            -- Meteors logic: small meteors
            for 0..MAX_SMALL_METEORS each i:
                if smallMeteor[i].active:
                    -- Movement
                    smallMeteor[i].position.x += smallMeteor[i].speed.x
                    smallMeteor[i].position.y += smallMeteor[i].speed.y

                    -- Collision logic: meteor vs wall
                    if smallMeteor[i].position.x > screenWidth + smallMeteor[i].radius: smallMeteor[i].position.x = -(smallMeteor[i].radius)
                    else smallMeteor[i].position.x < 0 - smallMeteor[i].radius: smallMeteor[i].position.x = screenWidth + smallMeteor[i].radius
                    if smallMeteor[i].position.y > screenHeight + smallMeteor[i].radius: smallMeteor[i].position.y = -(smallMeteor[i].radius)
                    else smallMeteor[i].position.y < 0 - smallMeteor[i].radius: smallMeteor[i].position.y = screenHeight + smallMeteor[i].radius

            -- Collision logic: player-shoots vs meteors
            for 0..PLAYER_MAX_SHOOTS each i:
                shooti = shoot[i] as Shoot
                if shooti.active:
                    for 0..MAX_BIG_METEORS each a:
                        meteor = bigMeteor[a] as Meteor
                        if meteor.active and ray.CheckCollisionCircles(shooti.position, shooti.radius, meteor.position, meteor.radius):
                            shooti.active = false
                            shooti.lifeSpawn = 0
                            meteor.active = false
                            destroyedMeteorsCount += 1

                            for 0..2 each j:
                                if midMeteorsCount%2 == 0:
                                    mediumMeteor[midMeteorsCount].position = Vec2{
                                        x: bigMeteor[a].position.x, y: bigMeteor[a].position.y
                                    }
                                    mediumMeteor[midMeteorsCount].speed = Vec2{
                                        x: m.cos(shooti.rotation*DEG2RAD)*METEORS_SPEED*-1,
                                        y: m.sin(shooti.rotation*DEG2RAD)*METEORS_SPEED*-1,
                                    }
                                else:
                                    mediumMeteor[midMeteorsCount].position = Vec2{
                                        x: bigMeteor[a].position.x, y: bigMeteor[a].position.y
                                    }
                                    mediumMeteor[midMeteorsCount].speed = Vec2{
                                        x: m.cos(shooti.rotation*DEG2RAD)*METEORS_SPEED,
                                        y: m.sin(shooti.rotation*DEG2RAD)*METEORS_SPEED
                                    }

                                mediumMeteor[midMeteorsCount].active = true
                                midMeteorsCount += 1
                            --bigMeteor[a].position = (Vector2){-100, -100};
                            meteor.color = ray.RED
                            break

                    for 0..MAX_MEDIUM_METEORS each b:
                        meteor = mediumMeteor[b] as Meteor
                        if meteor.active and ray.CheckCollisionCircles(shooti.position, shooti.radius, meteor.position, meteor.radius):
                            shooti.active = false
                            shooti.lifeSpawn = 0
                            meteor.active = false
                            destroyedMeteorsCount += 1

                            for 0..2 each j:
                                if smallMeteorsCount%2 == 0:
                                    smallMeteor[smallMeteorsCount].position = Vec2{
                                        x: mediumMeteor[b].position.x, y: mediumMeteor[b].position.y
                                    }
                                    smallMeteor[smallMeteorsCount].speed = Vec2{
                                        x: m.cos(shooti.rotation*DEG2RAD)*METEORS_SPEED*-1,
                                        y: m.sin(shooti.rotation*DEG2RAD)*METEORS_SPEED*-1,
                                    }
                                else:
                                    smallMeteor[smallMeteorsCount].position = Vec2{
                                        x: meteor.position.x, y: meteor.position.y
                                    }
                                    smallMeteor[smallMeteorsCount].speed = Vec2{
                                        x: m.cos(shooti.rotation*DEG2RAD)*METEORS_SPEED,
                                        y: m.sin(shooti.rotation*DEG2RAD)*METEORS_SPEED
                                    }

                                smallMeteor[smallMeteorsCount].active = true
                                smallMeteorsCount += 1
                            --mediumMeteor[b].position = Vec2{ x: -100, y: -100};
                            meteor.color = ray.GREEN
                            break

                    for 0..MAX_SMALL_METEORS each c:
                        meteor = smallMeteor[c] as Meteor
                        if meteor.active and ray.CheckCollisionCircles(shooti.position, shooti.radius, meteor.position, meteor.radius):
                            shooti.active = false
                            shooti.lifeSpawn = 0
                            meteor.active = false
                            destroyedMeteorsCount += 1
                            meteor.color = ray.YELLOW
                            -- smallMeteor[c].position = Vec2{x: -100, y:-100}
                            break

        if destroyedMeteorsCount == MAX_BIG_METEORS + MAX_MEDIUM_METEORS + MAX_SMALL_METEORS:
            victory = true
    else:
        if ray.IsKeyPressed(ray.KEY_ENTER):
            InitGame()
            gameOver = false

-- Draw game (one frame)
func DrawGame():
    ray.BeginDrawing()
    ray.ClearBackground(ray.RAYWHITE)

    if !gameOver:
        -- Draw spaceship
        v1 = Vec2{
            x: player.position.x + m.sin(player.rotation*DEG2RAD)*(shipHeight),
            y: player.position.y - m.cos(player.rotation*DEG2RAD)*(shipHeight),
        }
        v2 = Vec2{
            x: player.position.x - m.cos(player.rotation*DEG2RAD)*(PLAYER_BASE_SIZE/2),
            y: player.position.y - m.sin(player.rotation*DEG2RAD)*(PLAYER_BASE_SIZE/2),
        }
        v3 = Vec2{
            x: player.position.x + m.cos(player.rotation*DEG2RAD)*(PLAYER_BASE_SIZE/2),
            y: player.position.y + m.sin(player.rotation*DEG2RAD)*(PLAYER_BASE_SIZE/2),
        }
        ray.DrawTriangle(v1, v2, v3, ray.MAROON)

        -- Draw meteors
        for 0..MAX_BIG_METEORS each i:
            meteor = bigMeteor[i] as Meteor
            if meteor.active:
                ray.DrawCircleV(meteor.position, meteor.radius, ray.DARKGRAY)
            else:
                ray.DrawCircleV(meteor.position, meteor.radius, ray.Fade(ray.LIGHTGRAY, 0.3))

        for 0..MAX_MEDIUM_METEORS each i:
            meteor = mediumMeteor[i] as Meteor
            if meteor.active:
                ray.DrawCircleV(meteor.position, meteor.radius, ray.GRAY)
            else:
                ray.DrawCircleV(meteor.position, meteor.radius, ray.Fade(ray.LIGHTGRAY, 0.3))

        for 0..MAX_SMALL_METEORS each i:
            meteor = smallMeteor[i] as Meteor
            if meteor.active:
                ray.DrawCircleV(meteor.position, meteor.radius, ray.GRAY)
            else:
                ray.DrawCircleV(meteor.position, meteor.radius, ray.Fade(ray.LIGHTGRAY, 0.3))

        -- Draw shoot
        for 0..PLAYER_MAX_SHOOTS each i:
            shooti = shoot[i] as Shoot
            if shooti.active:
                ray.DrawCircleV(shooti.position, shooti.radius, ray.BLACK)

        if victory:
            ray.DrawText('VICTORY', screenWidth/2 - ray.MeasureText('VICTORY', 20)/2, screenHeight/2, 20, ray.LIGHTGRAY)

        if pause:
            ray.DrawText('GAME PAUSED', screenWidth/2 - ray.MeasureText('GAME PAUSED', 40)/2, screenHeight/2 - 40, 40, ray.GRAY)
    else: ray.DrawText('PRESS [ENTER] TO PLAY AGAIN', ray.GetScreenWidth()/2 - ray.MeasureText('PRESS [ENTER] TO PLAY AGAIN', 20)/2, ray.GetScreenHeight()/2 - 50, 20, ray.GRAY)

    ray.EndDrawing()

-- Unload game variables
func UnloadGame():
    -- TODO: Unload all dynamic loaded data (textures, sounds, models...)
    pass

-- Update and Draw (one frame)
func UpdateDrawFrame():
    UpdateGame()
    DrawGame()
