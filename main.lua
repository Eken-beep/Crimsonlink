function love.load()
    DTotal = 0
    love.window.setMode(1920, 1080, {fullscreen=true, resizable=true, vsync=false, minwidth=400, minheight=300})
    W, H = love.graphics.getDimensions()
    love.mouse.setVisible(true)
    Player = { position = {x = 0, y = 0}
             , hp       = 100
             , inventory = {}
             , hand = nil
             , character = love.graphics.newImage("assets/character.png")
             }

    Cursor = { x = love.mouse.getX()
             , y = love.mouse.getY()
             , tail = {image = love.graphics.newImage("assets/cursortail.png"), angle = 0}
             }

end

function love.update(dt)
    Cursor.x = love.mouse.getX()
    Cursor.y = love.mouse.getY()
    MouseTail()
end

function love.draw()
    love.graphics.setBackgroundColor(1,1,1)
    love.graphics.draw(Cursor.tail.image, Player.position.x, Player.position.y, Cursor.tail.angle)
    love.graphics.draw(Player.character, Player.position.x, Player.position.y)
end

-- Move gets the distance it should move and at what angle, from 0 to 2 pi
function love.keypressed(key)
    if key == "right" then
        Move(10, 0)
    elseif key == "down" then
        Move(10, 0.5*math.pi)
    elseif key == "left" then
        Move(10, 1*math.pi)
    elseif key == "up" then
        Move(10, 1.5*math.pi)
    end
end

function Move(distance, alpha)
    local x = distance*math.cos(alpha)
    local y = distance*math.sin(alpha)
    Player.position.x = Player.position.x + x
    Player.position.y = Player.position.y + y
end

function MouseTail()
    local px, py = Player.position.x , Player.position.y
    local dx, dy = Cursor.x - px, Cursor.y - py
    Cursor.tail.angle = math.atan2(dy, dx)
end
