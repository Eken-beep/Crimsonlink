function Player:keyboardMove()
    if love.keyboard.isDown("d")  then
        Player:movement(self.stats.movementspeed,0*math.pi)
    elseif love.keyboard.isDown("s")  then
        Player:movement(self.stats.movementspeed, 0.5*math.pi)
    elseif love.keyboard.isDown("a") then
        Player:movement(self.stats.movementspeed,1*math.pi)
    elseif love.keyboard.isDown("w") then
        Player:movement(self.stats.movementspeed, 1.5*math.pi)
    end
end

function Player:joystickMovement()
    local x = Deadzone(Joystick:getGamepadAxis("leftx"))
    local y = Deadzone(Joystick:getGamepadAxis("lefty"))
    self.position.x = self.position.x + x*self.stats.movementspeed
    self.position.y = self.position.y + y*self.stats.movementspeed
end

function Player:movement(distance, angle)
    local x = distance*math.cos(angle)
    local y = distance*math.sin(angle)
    self.position.x = self.position.x + x
    self.position.y = self.position.y + y
end

function Cursor:calcCrosshair()
    local px, py = Player.position.x , Player.position.y
    local dx, dy = self.x - px, self.y - py
    self.tail.angle = math.atan2(dy, dx)
    local cx = 250*math.cos(self.tail.angle)
    local cy = 250*math.sin(self.tail.angle)
    self.crosshair.x = cx + self.crosshair.x
    self.crosshair.y = cy + self.crosshair.y
end

function Cursor:calcCrosshairJoystick()
    local x = Deadzone(Joystick:getGamepadAxis("rightx"))
    local y = Deadzone(Joystick:getGamepadAxis("righty"))
    self.tail.angle = math.atan2(y,x)
    local cx = 250*math.cos(self.tail.angle)
    local cy = 250*math.sin(self.tail.angle)
    self.crosshair.x = cx + self.crosshair.x
    self.crosshair.y = cy + self.crosshair.y
end

function Player:joystickAttack()
    local trigger = Joystick:getGamepadAxis("triggerright")
    if trigger > 0 and not self.attackCooldown then Player:attack() end
end

function Player:dash(dt)
    self.dashCooldown = self.dashCooldown + dt
    if self.dashCooldown > 4 then
        if Player.controller then 
            local _, buttonIndex, _ = Joystick:getGamepadMapping("leftshoulder")
            if Joystick:isDown(buttonIndex) then
                Player:movement(700, Cursor.tail.angle)
                self.dashCooldown = 0
            end
        else
            if love.keyboard.isDown("space") then
                Player:movement(700, Cursor.tail.angle)
                self.dashCooldown = 0
            end
        end
    end
end

function Deadzone(a)
    if math.abs(a) < 0.1 then return 0
    else return a end
end

function Player:attack()
    local attackNeg = Cursor.tail.angle - math.pi/4
    local attackPos = Cursor.tail.angle + math.pi/4
    for i=1, #Enemies do
        local px, py = self.position.x , self.position.y
        local dx, dy = Enemies[i].x - px, Enemies[i].y - py
        local enemyAngle = math.atan2(dy, dx)
        if Distance(self.position.x, self.position.y, Enemies[i].x, Enemies[i].y) < self.hand.range and AngleOverlap(attackNeg, enemyAngle, attackPos) then
            Enemies[i].hp = Enemies[i].hp - self.hand.damage
        end
    end
    self.stats.xp = self.stats.xp + 10
    self.attackCooldown = true
end

function Player:attackTimeout(dt)
    self.attackTime = self.attackTime + dt
    if self.attackTime >= self.hand.cooldown then
        self.attackCooldown = false
        self.attackTime = 0
    end
end
