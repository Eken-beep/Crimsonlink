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

function Attack()
    local attackNeg = Cursor.tail.angle - math.pi/4
    local attackPos = Cursor.tail.angle + math.pi/4
    for i=1, #Enemies do
        local px, py = Player.position.x , Player.position.y
        local dx, dy = Enemies[i].x - px, Enemies[i].y - py
        local enemyAngle = math.atan2(dy, dx)
        if Distance(Player.position.x, Player.position.y, Enemies[i].x, Enemies[i].y) < Player.hand.range and AngleOverlap(attackNeg, enemyAngle, attackPos) then
            Enemies[i].hp = Enemies[i].hp - Player.hand.damage
            Player.attackCooldown = true
        end
    end
end

function AttackTimeout(dt)
    Player.attackTime = Player.attackTime + dt
    if Player.attackTime >= Player.hand.cooldown then
        Player.attackCooldown = false
        Player.attackTime = 0
    end
end

function DrawHealth()
    local sx,sy = 32,32

	local c = Player.stats.hp/Player.stats.maxHp
	local color = {2-2*c,2*c,0}
	love.graphics.setColor(color)
	love.graphics.print('Health: ' .. math.floor(Player.stats.hp),sx,sy)
	love.graphics.rectangle('fill', sx,1.5*sy, Player.stats.hp, sy/2)

	love.graphics.setColor(1,1,1)
	love.graphics.rectangle('line', sx,1.5*sy, Player.stats.maxHp, sy/2)
end
