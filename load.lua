-- Available states aon: Startscreen, Hub, Game, Loadout selector
State = "game"

Player = { position = {x = 0, y = 0}
         , stats = { hp = 100
                   , maxHp = 100
                   , movementspeed = 1
                   , xp = 0
                   , level = 1
                   }
         , inventory = {}
         , hand = Weapons.hand
         , character = love.graphics.newImage("assets/character.png")
         , attackCooldown = false
         , attackTime = 0
         , dashCooldown = 0
         , controller = false
         }

CurrentXpMax = 100*math.pow(1.1, Player.stats.level)

Cursor = { x = love.mouse.getX()
         , y = love.mouse.getY()
         , crosshair = {x = 10, y = 10}
         , attackAnimation = false
         , tail = {image = love.graphics.newImage("assets/cursortail.png"), angle = 0}
         }

Enemies = { {image = love.graphics.newImage("assets/enemy.png"), x=500, y=500, w = 50, h = 50, hp = 100}
          , {image = love.graphics.newImage("assets/enemy.png"), x=520, y=480, w = 50, h = 50, hp = 100}
          , {image = love.graphics.newImage("assets/enemy.png"), x=540, y=520, w = 50, h = 50, hp = 100}
          , {image = love.graphics.newImage("assets/enemy.png"), x=510, y=490, w = 50, h = 50, hp = 100}
          }

-- each one has an x y and time
DamageIndicators = {}

function love.load()
    DTotal = 0
    love.window.setMode(1920, 1080, {fullscreen=true, resizable=true, vsync=false, minwidth=400, minheight=300})
    W, H = love.graphics.getDimensions()
    love.mouse.setVisible(true)
    local joysticks = love.joystick.getJoysticks()
    Joystick = joysticks[1]
    Images = { attackBlock = love.graphics.newImage("assets/stop.png")
             }

    Audio = { hitmark = love.audio.newSource("assets/audio/hitmarker.mp3", "static")}
    Font = love.graphics.newFont(24)
end