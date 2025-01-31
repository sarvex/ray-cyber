-- Copyright (c) 2023 Cyber (See LICENSE)

-- Clash Game
-- Ported from GameDevTV/CPPCourse
-- https://gitlab.com/GameDevTV/CPPCourse/top-down-section
-- This port revises how the camera view is rendered so that variables such as screenWidth/screenHeight
-- can be adjusted without breaking the presentation.
-- This port also adds a gameplay mechanic with a score and advancing difficulty.

import os 'os'
import m 'math'

--import ray 'https://github.com/fubark/ray-cyber'
import ray '../mod.cy'

type Texture2D ray.Texture2D
type Rect ray.Rectangle
type Vec2 ray.Vector2

var screenWidth number: 600
var screenHeight number: 400
var score: 0

var CharIdleTex: none
var CharRunTex: none
var WeaponTex: none
var GoblinIdleTex: none
var GoblinRunTex: none
var SlimeIdleTex: none
var SlimeRunTex: none

var viewPos: Vec2{ x: 0, y: 0 }
var mapScale number: 4
var boundsMinX number: 45 * mapScale
var boundsMinY number: 45 * mapScale
var boundsMaxX number: 700 * mapScale
var boundsMaxY number: 700 * mapScale
var knight Character: none
var enemies: []

-- Assumes script path is the second arg.
basePath = os.dirName(try os.realPath(os.args()[1]))

ray.InitWindow(screenWidth, screenHeight, 'Clash Game')
ray.SetTargetFPS(60)

rockTex = ray.LoadTexture('{basePath}/nature_tileset/Rock.png')
logTex = ray.LoadTexture('{basePath}/nature_tileset/Log.png')

mapTex = ray.LoadTexture('{basePath}/nature_tileset/OpenWorldMap24x24.png')

CharIdleTex = ray.LoadTexture('{basePath}/characters/knight_idle_spritesheet.png')
CharRunTex = ray.LoadTexture('{basePath}/characters/knight_run_spritesheet.png')

WeaponTex = ray.LoadTexture('{basePath}/characters/weapon_sword.png')

GoblinIdleTex = ray.LoadTexture('{basePath}/characters/goblin_idle_spritesheet.png')
GoblinRunTex = ray.LoadTexture('{basePath}/characters/goblin_run_spritesheet.png')

SlimeIdleTex = ray.LoadTexture('{basePath}/characters/slime_idle_spritesheet.png')
SlimeRunTex = ray.LoadTexture('{basePath}/characters/slime_run_spritesheet.png')

props = [
    Prop.new(Vec2{ x: 600, y: 300 }, rockTex),
    Prop.new(Vec2{ x: 400, y: 500 }, logTex),
]

InitGame()
while !ray.WindowShouldClose():
    ray.BeginDrawing()
    ray.ClearBackground(ray.WHITE)

    knightPos = knight.base.getWorldPos()
    viewPos = Vec2{ x: knightPos.x - screenWidth/2, y: knightPos.y - screenHeight/2 }
    if viewPos.x < 0: viewPos.x = 0
    if viewPos.y < 0: viewPos.y = 0
    if viewPos.x > mapTex.width * mapScale - screenWidth: viewPos.x = mapTex.width * mapScale - screenWidth

    -- Draw the map
    ray.DrawTextureEx(mapTex, Vec2.scale(viewPos, -1), 0, mapScale, ray.WHITE)

    -- Draw the props
    for props each prop:
        prop.render()

    if !knight.base.getAlive():
        -- Character is not alive
        ray.DrawText('Game Over!', 30, 20, 40, ray.RED)
        ray.DrawText('Score: {score}', 30, 70, 40, ray.GREEN)
        ray.DrawText('PRESS [ENTER] TO PLAY AGAIN', 30, 120, 20, ray.GREEN)
        ray.EndDrawing()
        if ray.IsKeyPressed(ray.KEY_ENTER):
            InitGame()
        continue
    else:
        -- Character is alive
        ray.DrawText('Health: {m.floor(number(knight.getHealth()))}', 30, 20, 40, ray.RED)
        ray.DrawText('Score: {score}', 30, 70, 40, ray.GREEN)

    knight.tick(ray.GetFrameTime())
    knight.render()


    -- Check prop collisions
    for props each prop:
        if ray.CheckCollisionRecs(prop.getCollideRect() as Rect, knight.base.getCollideRect() as Rect):
            knight.base.undoMovement()

    for enemies each enemy:
        enemy.tick(ray.GetFrameTime())
        enemy.base.render()

    if ray.IsMouseButtonPressed(ray.MOUSE_LEFT_BUTTON):
        for enemies each enemy:
            if ray.CheckCollisionRecs(enemy.base.getCollideRect() as Rect, knight.getWeaponCollideRect() as Rect):
                removeEnemy(enemy)
                score += 10
                -- Spawn 2 more
                spawnRandomEnemy(knight)
                spawnRandomEnemy(knight)

    ray.EndDrawing()
ray.CloseWindow()

type Character object:
    base BaseCharacter
    weapon ray.Texture2D
    weaponCollideRect Rect
    health number

    func new():
        o = Character{
            base: BaseCharacter.new(),
            weapon: WeaponTex,
            weaponCollideRect: Rect{ x: 0, y: 0, width: 0, height: 0 },
            health: 100,
        }
        o.base.texture = CharIdleTex
        o.base.idle = CharIdleTex
        o.base.run = CharRunTex
        o.base.width = o.base.texture.width / o.base.maxFrames
        o.base.height = o.base.texture.height
        return o

    func tick(self, deltaTime):
        if !self.base.getAlive(): return

        if ray.IsKeyDown(ray.KEY_A): self.base.velocity.x -= 1.0
        if ray.IsKeyDown(ray.KEY_D): self.base.velocity.x += 1.0
        if ray.IsKeyDown(ray.KEY_W): self.base.velocity.y -= 1.0
        if ray.IsKeyDown(ray.KEY_S): self.base.velocity.y += 1.0
        self.base.tick(deltaTime)

    func render(self):
        self.base.render()
        -- Draw the sword
        origin = Vec2{ x: 0, y: 0 }
        offset = Vec2{ x: 0, y: 0 }
        rotation = 0
        if self.base.rightLeft > 0:
            origin = Vec2{ x: 0, y: self.weapon.height * self.base.scale}
            offset = Vec2{ x: 35, y: 55 }
            self.weaponCollideRect = Rect{
                x: self.base.worldPos.x + offset.x,
                y: self.base.worldPos.y + offset.y - self.weapon.height * self.base.scale,
                width: self.weapon.width * self.base.scale,
                height: self.weapon.height * self.base.scale
            }
            rotation = if ray.IsMouseButtonDown(ray.MOUSE_LEFT_BUTTON) then 35 else 0
        else:
            origin = Vec2{ x: self.weapon.width * self.base.scale, y: self.weapon.height * self.base.scale }
            offset = Vec2{ x: 25, y: 55 }
            self.weaponCollideRect = Rect{
                x: self.base.worldPos.x + offset.x - self.weapon.width * self.base.scale,
                y: self.base.worldPos.y + offset.y - self.weapon.height * self.base.scale,
                width: self.weapon.width * self.base.scale,
                height: self.weapon.height * self.base.scale,
            }
            rotation = if ray.IsMouseButtonDown(ray.MOUSE_LEFT_BUTTON) then -35 else 0
        source = Rect{ x: 0, y: 0,
            width: self.weapon.width * self.base.rightLeft,
            height: self.weapon.height,
        }
        screenPos = Vec2.sub(self.base.worldPos, viewPos)
        dest = Rect{
            x: screenPos.x + offset.x,
            y: screenPos.y + offset.y,
            width: self.weapon.width * self.base.scale,
            height: self.weapon.height * self.base.scale,
        }
        ray.DrawTexturePro(self.weapon as Texture2D, source, dest, origin, rotation as number, ray.WHITE)

    func takeDamage(self, damage):
        self.health -= damage
        if self.health <= 0:
            self.base.setAlive(false)

    func getHealth(self): return self.health
    func getWeaponCollideRect(self): return self.weaponCollideRect

type BaseCharacter object:
    worldPos Vec2
    velocity Vec2
    alive boolean
    width number
    height number
    speed number
    scale number

    -- animation variables
    runningTime number
    frame number
    maxFrames number
    updateTime number

    -- 1 : facing right, -1 : facing left
    rightLeft number

    worldPosLastFrame Vec2

    texture Texture2D
    idle Texture2D
    run Texture2D

    func new():
        return BaseCharacter{
            worldPos: Vec2{ x: 0, y: 0 },
            velocity: Vec2{ x: 0, y: 0 },
            worldPosLastFrame: Vec2{ x: 0, y: 0 },
            frame: 0,
            width: 0,
            height: 0,
            alive: true,
            speed: 4,
            scale: 4,
            updateTime: 1/12,
            runningTime: 0,
            maxFrames: 6,
            rightLeft: 1,
            texture: none,
            idle: none,
            run: none,
        }

    func getWorldPos(self):
        return self.worldPos

    func setAlive(self, isAlive):
        self.alive = isAlive

    func getAlive(self):
        return self.alive

    func undoMovement(self):
        self.worldPos = self.worldPosLastFrame

    func tick(self, deltaTime):
        self.worldPosLastFrame = self.worldPos

        -- update animation frame
        self.runningTime += deltaTime
        if self.runningTime >= self.updateTime:
            self.frame += 1
            self.runningTime = 0
            if self.frame > self.maxFrames:
                self.frame = 0

        if self.velocity.len() != 0:
            -- Update pos based on velocity.
            self.worldPos = Vec2.add(self.worldPos, Vec2.scale(Vec2.normalize(self.velocity), self.speed))
            if self.velocity.x < 0: self.rightLeft = -1
            else: self.rightLeft = 1

            -- Check bounds.
            if self.worldPos.x < boundsMinX: self.worldPos.x = boundsMinX
            if self.worldPos.y < boundsMinY: self.worldPos.y = boundsMinY
            if self.worldPos.x > boundsMaxX: self.worldPos.x = boundsMaxX
            if self.worldPos.y > boundsMaxY: self.worldPos.y = boundsMaxY

            self.texture = self.run
        else:
            self.texture = self.idle

        self.velocity.x = 0
        self.velocity.y = 0

    func render(self):
        if !self.alive: return
        source = Rect{ x: self.frame * self.width, y: 0, width: self.rightLeft * self.width, height: self.height }

        screenPos = Vec2.sub(self.worldPos, viewPos)
        dest = Rect{ x: screenPos.x, y: screenPos.y,
            width: self.scale * self.width, height: self.scale * self.height }
        ray.DrawTexturePro(self.texture as Texture2D, source, dest, Vec2{ x: 0, y: 0 }, 0, ray.WHITE)

    func getCollideRect(self) Rect:
        return Rect{
            x: self.worldPos.x,
            y: self.worldPos.y,
            width: self.width * self.scale,
            height: self.height * self.scale,
        }

type Prop object:
    worldPos Vec2
    texture ray.Texture2D
    scale number

    func new(pos, tex):
        return Prop{ worldPos: pos, texture: tex, scale: 4 }

    func render(self):
        screenPos = Vec2.sub(self.worldPos, viewPos)
        ray.DrawTextureEx(self.texture as Texture2D, screenPos, 0, self.scale as number, ray.WHITE)

    func getCollideRect(self):
        return Rect{
            x: self.worldPos.x,
            y: self.worldPos.y,
            width: self.texture.width * self.scale,
            height: self.texture.height * self.scale,
        }

type Enemy object:
    base BaseCharacter
    target Character
    damagePerSec number
    radius number

    func new(pos, idleTex, runTex):
        o = Enemy{
            base: BaseCharacter.new(),
            damagePerSec: 10,
            radius: 25,
        }
        o.base.worldPos = pos
        o.base.texture = idleTex
        o.base.idle = idleTex
        o.base.run = runTex
        o.base.width = o.base.texture.width / o.base.maxFrames
        o.base.height = o.base.texture.height
        o.base.speed = 3.5
        return o

    func tick(self, deltaTime):
        if !self.base.getAlive(): return

        -- get toTarget
        self.base.velocity = Vec2.sub(self.target.base.getWorldPos(), self.base.getWorldPos())
        if self.base.velocity.len() < self.radius: self.base.velocity = Vec2{ x: 0, y: 0 }
        self.base.tick(deltaTime)

        if ray.CheckCollisionRecs(self.target.base.getCollideRect() as Rect, self.base.getCollideRect() as Rect):
            self.target.takeDamage(self.damagePerSec * deltaTime)

    func setTarget(self, char):
        self.target = char

    func getScreenPos(self):
        return Vec2.sub(self.base.worldPos, self.target.base.getWorldPos())

func spawnRandomEnemy(target):
    x = ray.GetRandomValue(boundsMinX, boundsMaxX)
    y = ray.GetRandomValue(boundsMinY, boundsMaxY)
    creature = ray.GetRandomValue(0, 1)
    if creature == 0:
        enemy = Enemy.new(Vec2{ x: x, y: y }, GoblinIdleTex, GoblinRunTex)
    else:
        enemy = Enemy.new(Vec2{ x: x, y: y }, SlimeIdleTex, SlimeRunTex)
    enemy.setTarget(target)
    enemies.append(enemy)

func removeEnemy(enemy):
    for enemies each i, it:
        if it == enemy:
            enemies.remove(number(i))
            break

func InitGame():
    static knight = Character.new()
    knight.base.worldPos.x = ray.GetRandomValue(boundsMinX, boundsMaxX)
    knight.base.worldPos.y = ray.GetRandomValue(boundsMinY, boundsMaxY)

    score = 0

    static enemies = []
    for 0..10:
        spawnRandomEnemy(knight)
