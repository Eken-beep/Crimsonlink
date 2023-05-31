require("items")
require("load")
require("player")
require("enemy")
require("drawing")


function love.update(dt)
    if State == "game" then
        Player.x, Player.y = Player.body:getPosition()
        if Player.controller then
            Player:joystickMovement()
            Cursor:calcCrosshairJoystick()
            Player:joystickAttack()
        else
            Cursor.x = love.mouse.getX()
            Cursor.y = love.mouse.getY()
            Cursor:calcCrosshair()
            Player:keyboardMove()
        end
        Enemies:onDeath()
        if love.keyboard.isDown("space") then
            Player.body:setLinearVelocity(1000,0)
        end
        Player.dashData.dashMeter = math.min(Player.dashData.dashMeter + dt/20, Player.dashData.maxDashMeter)
        Player:dash(1000,dt)
        if Player.attackCooldown then Player:attackTimeout(dt) end
        if Player.stats.xp >= CurrentXpMax then
            Player.stats.xp = 0
            Player.stats.level = Player.stats.level + 1
            CurrentXpMax = math.floor(100*math.pow(1.1, Player.stats.level))
        end
        World:update(dt)
    end
end

function love.draw()
    if State == "game" then
        love.graphics.setBackgroundColor(1,1,1)
        love.graphics.draw(Cursor.tail.image, Player.x+25, Player.y+25, Cursor.tail.angle, 1, 1, 6, 6)
        love.graphics.draw(Player.character, Player.x, Player.y)
        Enemies:draw()
        DrawXp()
        DrawHealth()
        DrawDash()
        DamageIndicators:draw()
        if Player.attackCooldown then
            love.graphics.draw(Images.attackBlock, 32, 100, 0, 0.05, 0.05)
        end
    end
end

function love.mousepressed(x, y, button)
    if button == 1 and not Player.attackCooldown then
        Player:attack()
    end
end

function Distance(ax, ay, bx, by)
    return math.sqrt(math.pow(ax-bx,2) + math.pow(ay-by,2))
end

function AngleOverlap(a1, x, a2)
    return a1 < x and x < a2
end
