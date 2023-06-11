require("items")
require("load")
require("player")
require("enemy")
require("drawing")
require("map")

function love.update(dt)
    Currentmap:update(dt)
    if State == "game" then
        Player:setPosition()
        if Player.controller then
            Player:joystickMovement(dt)
            Cursor:calcCrosshairJoystick()
            Player:joystickAttack()
        else
            Cursor.x = love.mouse.getX()
            Cursor.y = love.mouse.getY()
            Cursor:calcCrosshair()
            Player:keyboardMove()
        end
        Enemies:update()
        Enemies:move()
        Enemies:onDeath()
        Enemies:attack()
        if Player.dashTime then Player.dashTime = Player.dashTime + dt end
        if Player.attackCooldown then Player:attackTimeout(dt) end
        if Player.stats.xp >= CurrentXpMax then
            Player.stats.xp = 0
            Player.stats.level = Player.stats.level + 1
            CurrentXpMax = math.floor(100*math.pow(1.1, Player.stats.level))
        end
        DamageIndicators:clean(dt)
        Cam:lookAt(Player.x, Player.y)
    elseif State == "hub" then
        Player:setPosition()
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
        if Player.dashTime then Player.dashTime = Player.dashTime + dt end
        if Player.attackCooldown then Player:attackTimeout(dt) end
        if Player.stats.xp >= CurrentXpMax then
            Player.stats.xp = 0
            Player.stats.level = Player.stats.level + 1
            CurrentXpMax = math.floor(100*math.pow(1.1, Player.stats.level))
        end
        Cam:lookAt(Player.x+Player.w/2, Player.y+Player.w/2)
    end
end

function love.draw()
    if State == "game" then
        Cam:attach()
            MapDrawer()
            love.graphics.draw(Cursor.tail.image, Player.x+Player.w/2, Player.y+Player.w/2, Cursor.tail.angle, 1, 1, 6, 6)
            Enemies:draw()
            love.graphics.draw(Player.character, Player.x, Player.y)
            DamageIndicators:draw()
        Cam:detach()
        -- Gui stuff which should be static on the screen
        DrawXp()
        DrawHealth()
        if Player.attackCooldown then
            love.graphics.draw(Images.attackBlock, 32, 100, 0, 0.05, 0.05)
        end
    elseif State == "hub" then
        Cam:attach()
            MapDrawer()
            love.graphics.draw(Cursor.tail.image, Player.x+25, Player.y+25, Cursor.tail.angle, 1, 1, 6, 6)
            love.graphics.draw(Player.character, Player.x, Player.y)
        Cam:detach()
        DrawXp()
        DrawHealth()
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

function love.gamepadpressed(joystick, button)
    if button == "leftshoulder" then
        Player:dash(Player.stats.movementspeed)
    end
end

function Distance(ax, ay, bx, by)
    return math.sqrt(math.pow(ax-bx,2) + math.pow(ay-by,2))
end

function AngleOverlap(a1, x, a2)
    return a1 < x and x < a2
end

