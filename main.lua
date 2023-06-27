require("items")
require("load")
require("player")
require("enemy")
require("drawing")
require("map")

function love.update(dt)
    Currentmap:update(dt)
    Player.animationTime = Player.animationTime + dt
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
            Player:keyboardMove(dt)
        end
        Enemies:update(dt)
        Enemies:move(dt)
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
            Player:keyboardMove(dt)
        end
        if Player.dashTime then Player.dashTime = Player.dashTime + dt end
        if Player.attackCooldown then Player:attackTimeout(dt) end
        if Player.stats.xp >= CurrentXpMax then
            Player.stats.xp = 0
            Player.stats.level = Player.stats.level + 1
            CurrentXpMax = math.floor(100*math.pow(1.1, Player.stats.level))
        end
    end
end

function love.draw()
    if State == "game" then
        love.graphics.push()
        love.graphics.translate(MapXOffset, MapYOffset)
        love.graphics.scale(Scale)
            MapDrawer()
            love.graphics.draw(Cursor.tail.image, Player.x+Player.w/2, Player.y+Player.w/2, Cursor.tail.angle, 1, 1, 6, 6)
            Enemies:draw()
            Player:animate()
            --love.graphics.draw(Player.character, Player.x, Player.y--[[, 0, Scale, Scale]])
            DamageIndicators:draw()
            Currentmap:bump_draw()
        love.graphics.pop()
        -- Gui stuff which should be static on the screen
        love.graphics.push()
        love.graphics.scale(Scale)
        DrawXp()
        DrawHealth()
        Player:drawBackpack()
        if Player.attackCooldown then
            love.graphics.draw(Images.attackBlock, 32, 100, 0, 0.05, 0.05)
        end
        love.graphics.pop()
    elseif State == "hub" then
        Cam:attach()
            MapDrawer()
            love.graphics.draw(Cursor.tail.image, Player.x+25, Player.y+25, Cursor.tail.angle, 1, 1, 6, 6)
            love.graphics.draw(Player.character, Player.x, Player.y)
        Cam:detach()
        DrawXp()
        DrawHealth()
        Player:drawBackpack()
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
    elseif button == "dpup" then
        Player.backpack:useItem(1)
    elseif button == "dpright" then
        Player.backpack:useItem(2)
    elseif button == "dpdown" then
        Player.backpack:useItem(3)
    elseif button == "dpleft" then
        Player.backpack:useItem(4)
    end
end

function love.keypressed(key)
    if key == "space" then
        Player:dash(Player.stats.movementspeed)
    elseif key == "1" then
        Player.backpack:useItem(1)
    elseif key == "2" then
        Player.backpack:useItem(2)
    elseif key == "3" then
        Player.backpack:useItem(3)
    elseif key == "4" then
        Player.backpack:useItem(4)
    end
end

function Distance(ax, ay, bx, by)
    return math.sqrt(math.pow(ax-bx,2) + math.pow(ay-by,2))
end

function AngleOverlap(a1, x, a2)
    return a1 < x and x < a2
end

function CheckCollision(x1,y1,w1,h1, x2,y2,w2,h2)
  return x1 < x2+w2 and
         x2 < x1+w1 and
         y1 < y2+h2 and
         y2 < y1+h1
end
