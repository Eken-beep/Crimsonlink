require("player")
require("items")
require("enemy")

Player = { position = {x = 0, y = 0}
         , stats = { hp = 100
                   , maxHp = 100
                   , movementspeed = 1
                   }
         , inventory = {}
         , hand = Weapons.hand
         , character = love.graphics.newImage("assets/character.png")
         }

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
end

function love.update(dt)
    Cursor.x = love.mouse.getX()
    Cursor.y = love.mouse.getY()
    CalcCrosshair()
    Move()
    EnemyDeath()
end

function love.draw()
    love.graphics.setBackgroundColor(1,1,1)
    love.graphics.draw(Cursor.tail.image, Player.position.x+12.5, Player.position.y+12.5, Cursor.tail.angle, 1, 1, 6, 6)
    love.graphics.draw(Player.character, Player.position.x, Player.position.y)
    DrawEnemies()

    local sx,sy = 32,32

	local c = Player.stats.hp/Player.stats.maxHp
	local color = {2-2*c,2*c,0}
	love.graphics.setColor(color)
	love.graphics.print('Health: ' .. math.floor(Player.stats.hp),sx,sy)
	love.graphics.rectangle('fill', sx,1.5*sy, Player.stats.hp, sy/2)

	love.graphics.setColor(1,1,1)
	love.graphics.rectangle('line', sx,1.5*sy, Player.stats.maxHp, sy/2)
end

function love.mousepressed(x, y, button)
    if button == 1 then
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
