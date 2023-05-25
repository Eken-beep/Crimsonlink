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

    Cursor = {x = love.mouse.getX(), y = love.mouse.getY(), image = love.graphics.newImage("assets/crosshair.png")}

end

function love.update(dt)
    Cursor.x = love.mouse.getX()
    Cursor.y = love.mouse.getY()
end

function love.draw()
    love.graphics.setBackgroundColor(1,1,1)
    love.graphics.rectangle("line", (W/2)-0.4*W, (H/2)-0.4*H, 0.8*W, 0.8*H)
    love.graphics.draw(Player.character, Player.position.x, Player.position.y)
    love.graphics.line(Player.position.x, Player.position.y, Cursor.x, Cursor.y)
end

function love.keypressed(key)
    if key == "right" then
        Player.position.x = Player.position.x + 10
    elseif key == "left" then
        Direction = "left"
        Player.position.x = Player.position.x - 10
    elseif key == "up" then
        Player.position.y = Player.position.y - 10
    elseif key == "down" then
        Player.position.y = Player.position.y + 10
    end
end
