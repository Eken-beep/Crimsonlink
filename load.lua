-- Available states aon: Startscreen, Hub, Game, Loadout selector
State = "game"
Sti = require("libraries.sti")
StiBumpPlugin = require("libraries.sti.plugins.bump")
Bump = require("libraries.bump")
local camera = require("libraries.hump.camera")
Cam = camera()
Timer = require("libraries.hump.timer")

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
         , character = love.graphics.newImage("assets/character.png")
         , attackCooldown = false
         , attackTime = 0
         , controller = true
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
    love.window.setMode(1920, 1080, {fullscreen=true, resizable=true, vsync=false, minwidth=400, minheight=300})
    W, H = love.graphics.getDimensions()
    MapXOffset = (W/2)-(1920/2)
    MapYOffset = (H/2)-(1056/2)
    Scale = 1

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
        {name = "Mutant", image = Images.enemy1, x = 0, y = 0, damage = 5, hp = 70, range = 70}
    }

    Currentmap = Maps.test
    Font = love.graphics.newFont(24)
    InstantiateMap(Maps.test)

    Enemies[1] = {name = "Mutant", image = Images.enemy1, x = 500, y = 500, damage = 5, hp = 70, range = 70}
    World:add(1, 500, 500, 50, 50)
end
