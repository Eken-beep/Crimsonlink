-- Available states aon: Startscreen, Hub, Game, Loadout selector
State = "game"

Player = { stats = { hp = 100
                   , maxHp = 100
                   , movementspeed = 3000
                   , xp = 0
                   , level = 1
                   }
         , dashData = { dashMeter = 0
                      , maxDashMeter = 1.4
                      }
         , x = 900, y = 500
         , inventory = {}
         , hand = Weapons.hand
         , character = love.graphics.newImage("assets/character.png")
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

Enemies = {}

-- each one has an x y time damage and opacity
DamageIndicators = {}

function love.load()
    DTotal = 0
    love.window.setMode(1920, 1080, {fullscreen=true, resizable=true, vsync=false, minwidth=400, minheight=300})
    W, H = love.graphics.getDimensions()

    -- physics properties of constant objects
    World = love.physics.newWorld(0,0,true)
    Player.body = love.physics.newBody(World, W/2-25, H/2-25, "dynamic")
    Player.shape = love.physics.newRectangleShape(50, 50)
    Player.fixture = love.physics.newFixture(Player.body, Player.shape, 1)
    Player.fixture:setFriction(0.0)
    Player.body:setLinearDamping(5)

    love.mouse.setVisible(true)
    local joysticks = love.joystick.getJoysticks()
    Joystick = joysticks[1]
    Images = { attackBlock = love.graphics.newImage("assets/stop.png")
             }

    Audio = { hitmark = love.audio.newSource("assets/audio/hitmarker.mp3", "static")
            }
    Font = love.graphics.newFont(24)
end
