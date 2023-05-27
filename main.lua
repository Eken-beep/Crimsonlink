require("player")
require("items")
require("enemy")

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
         }

CurrentXpMax = 100*math.pow(1.1, Player.stats.level)

Cursor = { x = love.mouse.getX()
         , y = love.mouse.getY()
         , crosshair = {x = 10, y = 10}
         , attackAnimation = false
         , tail = {image = love.graphics.newImage("assets/cursortail.png"), angle = 0}
         }

Enemies = {{image = love.graphics.newImage("assets/enemy.png"), x=500, y=500, w = 50, h = 50, hp = 100}}

function love.load()
    DTotal = 0
    love.window.setMode(1920, 1080, {fullscreen=true, resizable=true, vsync=false, minwidth=400, minheight=300})
    W, H = love.graphics.getDimensions()
    love.mouse.setVisible(true)
    Images = { attackBlock = love.graphics.newImage("assets/stop.png")
             }
    Font = love.graphics.newFont(24)
end

function love.update(dt)
    Cursor.x = love.mouse.getX()
    Cursor.y = love.mouse.getY()
    CalcCrosshair()
    Move()
    EnemyDeath()
    if Player.attackCooldown then AttackTimeout(dt) end
    if Player.stats.xp >= CurrentXpMax then
        Player.stats.xp = 0
        Player.stats.level = Player.stats.level + 1
        CurrentXpMax = math.floor(100*math.pow(1.1, Player.stats.level))
    end
end

function love.draw()
    love.graphics.setBackgroundColor(1,1,1)
    love.graphics.draw(Cursor.tail.image, Player.position.x+12.5, Player.position.y+12.5, Cursor.tail.angle, 1, 1, 6, 6)
    love.graphics.draw(Player.character, Player.position.x, Player.position.y)
    DrawEnemies()
    DrawXp()
    DrawHealth()
    if Player.attackCooldown then
        love.graphics.draw(Images.attackBlock, 32, 100, 0, 0.05, 0.05)
    end
end

function love.mousepressed(x, y, button)
    if button == 1 and not Player.attackCooldown then
        Attack()
    end
end

function Distance(ax, ay, bx, by)
    return math.sqrt(math.pow(ax-bx,2) + math.pow(ay-by,2))
end

function DoCollide(x1,y1,w1,h1, x2,y2,w2,h2)
  return x1 < x2+w2 and
         x2 < x1+w1 and
         y1 < y2+h2 and
         y2 < y1+h1
end

function AngleOverlap(a1, x, a2)
    return a1 < x and x < a2
end
