Joystick = love.joystick.getJoysticks()[1]
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

function Player:joystickMovement(dt)
    local x = Deadzone(Joystick:getGamepadAxis("leftx"))
    local y = Deadzone(Joystick:getGamepadAxis("lefty"))
    World:move(Player, Player.x+x*Player.stats.movementspeed*dt, Player.y+y*Player.stats.movementspeed*dt)
end

function Player:movement(distance, angle)
    local x = distance*math.cos(angle)
    local y = distance*math.sin(angle)
    self.body:setLinearVelocity(x,y)
end

function Player:setPosition()
        self.x, self.y, _, _ = World:getRect(self)
end

function Cursor:calcCrosshair()
    local px, py = Player.x , Player.y
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
    if trigger > 0 and not self.attackCooldown then self:attack() end
end

function Player:dash(power)
    local rx = power*math.cos(Cursor.tail.angle)
    local ry = power*math.sin(Cursor.tail.angle)
    if self.dashTime ~= nil and self.dashTime > 5 then
        self.collider:applyForce(rx,ry)
        self.dashTime = 0
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
        local px, py = self.x , self.y
        local dx, dy = Enemies[i].x - px, Enemies[i].y - py
        local enemyAngle = math.atan2(dy, dx)
        if Distance(px, py, Enemies[i].x, Enemies[i].y) < self.hand.range and AngleOverlap(attackNeg, enemyAngle, attackPos) then
            local crit = math.random(1,100)
            if crit <= self.hand.crit then
                Enemies[i].hp = Enemies[i].hp - self.hand.damage*3
                DamageIndicators:add(Enemies[i].x, Enemies[i].y, self.hand.damage*3)
            else
                Enemies[i].hp = Enemies[i].hp - self.hand.damage
                DamageIndicators:add(Enemies[i].x, Enemies[i].y, self.hand.damage)
            end
            love.audio.play(Audio.hitmark)
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
