-- Available states aon: Startscreen, Hub, Game, Loadout selector
State = "game"
Sti = require("libraries.sti")
StiBumpPlugin = require("libraries.sti.plugins.bump")
Bump = require("libraries.bump")
local camera = require("libraries.camera")
Cam = camera()
Timer = require("libraries.timer")

Player = { stats = { hp = 100
                   , maxHp = 100
                   , movementspeed = 300
                   , xp = 0
                   , level = 1
                   }
         , dashTime = 0
         , x = 900, y = 500
         , inventory = {}
         , hand = Weapons.hand
         , character = love.graphics.newImage("assets/Maincharacter1.png")
         , attackCooldown = false
         , attackTime = 0
         , controller = false
         }

CurrentXpMax = 100*math.pow(1.1, Player.stats.level)

Cursor = { x = love.mouse.getX()
         , y = love.mouse.getY()
         , crosshair = {x = 10, y = 10}
         , attackAnimation = false
         , tail = {image = love.graphics.newImage("assets/cursortail.png"), angle = 0}
         }

-- Must have x y image damage hp.
Enemies = {}

-- each one has an x y time damage and opacity
DamageIndicators = {}

function love.load()
    DTotal = 0
    love.window.setMode(1920, 1066, {fullscreen=true, resizable=false, vsync=false, centered = true, minwidth=400, minheight=300})
    W, H = love.graphics.getDimensions()
    MapXOffset = 0
    MapYOffset = 0
    Scale = 1/math.max(60*32/W, 33*32/H)

    love.mouse.setVisible(true)
    local joysticks = love.joystick.getJoysticks()
    Joystick = joysticks[1]
    Maps = { hub = Sti("maps/hub.lua")
           , test = Sti("maps/test.lua", {"bump"})
           }
    Images = { attackBlock = love.graphics.newImage("assets/stop.png")
             , enemy1 = love.graphics.newImage("assets/enemy.png")
             }

    Audio = { hitmark = love.audio.newSource("assets/audio/hitmarker.mp3", "static")
            }
    EnemyTypes = {
        {name = "Mutant", image = Images.enemy1, x = 0, y = 0, damage = 5, hp = 70, range = 70*Scale}
    }

    Currentmap = Maps.test
    Font = love.graphics.newFont(24)
    InstantiateMap(Maps.test)

    Enemies[1] = {name = "Mutant", image = Images.enemy1, x = 500, y = 500, damage = 5, hp = 70, range = 70, time = 0}
    World:add(1, 500*Scale, 500*Scale, 50, 50)
end
