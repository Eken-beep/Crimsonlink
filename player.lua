function Move()
    if love.keyboard.isDown("d") or love.keyboard.isDown("e") then
        Movement(Player.stats.movementspeed,0*math.pi)
    elseif love.keyboard.isDown("s") or love.keyboard.isDown("o") then
        Movement(Player.stats.movementspeed, 0.5*math.pi)
    elseif love.keyboard.isDown("a") then
        Movement(Player.stats.movementspeed,1*math.pi)
    elseif love.keyboard.isDown("w") or love.keyboard.isDown(",") then
        Movement(Player.stats.movementspeed, 1.5*math.pi)
    end
end

function Movement(distance, angle)
    local x = distance*math.cos(angle)
    local y = distance*math.sin(angle)
    Player.position.x = Player.position.x + x
    Player.position.y = Player.position.y + y
end

function CalcCrosshair()
    local px, py = Player.position.x , Player.position.y
    local dx, dy = Cursor.x - px, Cursor.y - py
    Cursor.tail.angle = math.atan2(dy, dx)
    local cx = 250*math.cos(Cursor.tail.angle)
    local cy = 250*math.sin(Cursor.tail.angle)
    Cursor.crosshair.x = cx + Cursor.crosshair.x
    Cursor.crosshair.y = cy + Cursor.crosshair.y
end
