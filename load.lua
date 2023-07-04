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
         -- Inventory is the naming of the dpad item selector, which allows a max of four items at a time
         , backpack = { Items.empty, Items.empty, Items.empty, Items.empty}
         , hand = Weapons.hand
         , character = love.graphics.newImage("assets/player/MainCharacter1.png")
         , attackCooldown = false
         , attackTime = 0
         , controller = true
         , flipped = false
         , animationTime = 0.01
         }

CurrentXpMax = 100*math.pow(1.1, Player.stats.level)

Cursor = { x = love.mouse.getX()
         , y = love.mouse.getY()
         , crosshair = {x = 10, y = 10}
         , attackAnimation = false
         , tail = {image = love.graphics.newImage("assets/cursortail.png"), angle = 0}
         }

Keybinds = {
    controller = { backpack = { "dpup", "dpright", "dpdown", "dpleft"}
                 , dash = "leftshoulder"
                 , pickupMode = "a"
                 },
    keyboard   = { backpack = { "1", "2", "3", "4" }
                 , dash = "space"
                 , pickupMode = "lctrl"
                 }
}

-- Must have x y image damage hp.
Enemies = {}

-- each one has an x y time damage and opacity
DamageIndicators = {}

-- List of items that are dropped in a room
DroppedItems = {}

function love.load()
    DTotal = 0
    love.window.setMode(1920, 1066, {fullscreen=true, resizable=false, vsync=false, centered = true, minwidth=400, minheight=300})
    W, H = love.graphics.getDimensions()
    Scale = math.min(W/(60*32), H/(33*32))
    MapXOffset = W/2 - Scale*60*32/2
    MapYOffset = H/2 - Scale*33*32/2

    love.mouse.setVisible(true)
    local joysticks = love.joystick.getJoysticks()
    Joystick = joysticks[1]
    Maps = { hub = Sti("maps/hub.lua")
           , test = Sti("maps/test.lua", {"bump"})
           }
    Images = { attackBlock = love.graphics.newImage("assets/stop.png")
             -- The only image that is a table, animation selects one of the images to draw
             , animatedPlayer = { love.graphics.newImage("assets/player/MainCharacter1.png")
                                , love.graphics.newImage("assets/player/MainCharacter2.png")
                                , love.graphics.newImage("assets/player/MainCharacter3.png")
                                , love.graphics.newImage("assets/player/MainCharacter4.png")
                                , love.graphics.newImage("assets/player/MainCharacter5.png")
                                , love.graphics.newImage("assets/player/MainCharacter6.png")
                                , love.graphics.newImage("assets/player/MainCharacter7.png")
                                , love.graphics.newImage("assets/player/MainCharacter1.png")
                                }
             , enemy1 = love.graphics.newImage("assets/Enemy1.png")
             , empty = love.graphics.newImage("assets/stop.png")
             }

    Audio = { hitmark = love.audio.newSource("assets/audio/hitmarker.mp3", "static")
            , oof = love.audio.newSource("assets/audio/oof.mp3", "static")
            }
    EnemyTypes = {
        {name = "Mutant", image = Images.enemy1, x = 0, y = 0, damage = 5, hp = 70, range = 70*Scale}
    }

    Currentmap = Maps.test
    Font = love.graphics.newFont(24)
    InstantiateMap(Maps.test)

    Enemies[1] = {name = "Mutant", image = Images.enemy1, x = 500, y = 500, damage = 5, hp = 70, range = 70, time = 0}
    World:add(1, 500*Scale, 500*Scale, Enemies[1].image:getWidth(), Enemies[1].image:getHeight())
end
