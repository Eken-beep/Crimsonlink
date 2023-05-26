require("player")

function love.load()
    DTotal = 0
    love.window.setMode(1920, 1080, {fullscreen=true, resizable=true, vsync=false, minwidth=400, minheight=300})
    W, H = love.graphics.getDimensions()
    love.mouse.setVisible(true)
    Player = { position = {x = 0, y = 0}
             , stats = { hp = 100
                       , movementspeed = 1
                       }
             , inventory = {}
             , hand = nil
             , character = love.graphics.newImage("assets/character.png")
             }

    Cursor = { x = love.mouse.getX()
             , y = love.mouse.getY()
             , crosshair = {x = 10, y = 10}
             , tail = {image = love.graphics.newImage("assets/cursortail.png"), angle = 0}
             }

end

function love.update(dt)
    Cursor.x = love.mouse.getX()
    Cursor.y = love.mouse.getY()
    CalcCrosshair()
    Move()
end

function love.draw()
    love.graphics.setBackgroundColor(1,1,1)
    love.graphics.draw(Cursor.tail.image, Player.position.x, Player.position.y, Cursor.tail.angle)
    love.graphics.draw(Player.character, Player.position.x, Player.position.y)
end