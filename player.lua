function KeyboardMove()
    if love.keyboard.isDown("d")  then
        Movement(Player.stats.movementspeed,0*math.pi)
    elseif love.keyboard.isDown("s")  then
        Movement(Player.stats.movementspeed, 0.5*math.pi)
    elseif love.keyboard.isDown("a") then
        Movement(Player.stats.movementspeed,1*math.pi)
    elseif love.keyboard.isDown("w") then
        Movement(Player.stats.movementspeed, 1.5*math.pi)
    end
end

function JoystickMovement()
    local x = Deadzone(Joystick:getGamepadAxis("leftx"))
    local y = Deadzone(Joystick:getGamepadAxis("lefty"))
    Player.position.x = Player.position.x + x*Player.stats.movementspeed
    Player.position.y = Player.position.y + y*Player.stats.movementspeed
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

function CalcCrosshairJoystick()
    local x = Deadzone(Joystick:getGamepadAxis("rightx"))
    local y = Deadzone(Joystick:getGamepadAxis("righty"))
    Cursor.tail.angle = math.atan2(y,x)
    local cx = 250*math.cos(Cursor.tail.angle)
    local cy = 250*math.sin(Cursor.tail.angle)
    Cursor.crosshair.x = cx + Cursor.crosshair.x
    Cursor.crosshair.y = cy + Cursor.crosshair.y
end

function JoystickAttack()
    local trigger = Joystick:getGamepadAxis("triggerright")
    if trigger > 0 and not Player.attackCooldown then Attack() end
end

function Dash(dt)
    Player.dashCooldown = Player.dashCooldown + dt
    if Player.dashCooldown > 4 then
        local _, buttonIndex, _ = Joystick:getGamepadMapping("leftshoulder")
        if love.keyboard.isDown("space") or Joystick:isDown(buttonIndex) then
            Movement(700, Cursor.tail.angle)
            Player.dashCooldown = 0
        end
    end
end

function Deadzone(a)
    if math.abs(a) < 0.1 then return 0
    else return a end
end

function Attack()
    local attackNeg = Cursor.tail.angle - math.pi/4
    local attackPos = Cursor.tail.angle + math.pi/4
    for i=1, #Enemies do
        local px, py = Player.position.x , Player.position.y
        local dx, dy = Enemies[i].x - px, Enemies[i].y - py
        local enemyAngle = math.atan2(dy, dx)
        if Distance(Player.position.x, Player.position.y, Enemies[i].x, Enemies[i].y) < Player.hand.range and AngleOverlap(attackNeg, enemyAngle, attackPos) then
            Enemies[i].hp = Enemies[i].hp - Player.hand.damage
        end
    end
    Player.stats.xp = Player.stats.xp + 10
    Player.attackCooldown = true
end

function AttackTimeout(dt)
    Player.attackTime = Player.attackTime + dt
    if Player.attackTime >= Player.hand.cooldown then
        Player.attackCooldown = false
        Player.attackTime = 0
    end
end
