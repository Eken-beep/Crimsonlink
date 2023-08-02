function Enemies:draw()
    for _, e in ipairs(self) do
        if e ~= nil then
            love.graphics.draw(e.image, e.x, e.y)
        end
    end
end

function Enemies:spawn()
    local enemyLayer = Currentmap.layers[#Currentmap.layers-1].objects
    for i, v in ipairs(enemyLayer) do
        local enemy = EnemyTypes[math.random(#EnemyTypes)]
        enemy.x = v.x
        enemy.y = v.y
        enemy.w = enemy.image:getWidth()
        enemy.h = enemy.image:getHeight()
        enemy.time = 0
        if #Enemies == 0 then
            enemy.id = 1
        else
            enemy.id = Enemies[#Enemies].id + 1
        end
        print("Enemy ".. i .. " spawned with id", enemy.id, "at position", enemy.x, enemy.y)
        table.insert(self, enemy)
        World:add(enemy, v.x*Scale, v.y*Scale, enemy.w, enemy.h)
    end
end

function Enemies:attack()
    for i, v in ipairs(self) do
        if Distance(v.x+v.w/2, v.y+v.h/2, Player.x+Player.w/2, Player.y+Player.h/2) < v.range and v.time > 2 then
            Player:addHealth(-v.damage)
            v.time = 0
            love.audio.play(Audio.oof)
        end
    end
end

function Enemies:onDeath()
    for i, v in ipairs(self) do
        if v.hp <= 0 then
            table.remove(self, i)
            World:remove(v.id)
        end
    end
end

function Enemies:move(dt)
    for i, v in ipairs(self) do
        local dx = v.x - Player.x
        local dy = v.y - Player.y
        local a = math.atan2(-dy, -dx)
        local ex = Scale*dt*40*math.cos(a)
        local ey = Scale*dt*40*math.sin(a)
        World:move(v.id, v.x + ex, v.y + ey)
        v.x, v.y = v.x+ex, v.y+ey
        --print("Enemy: ", v.id, "moved to " .. v.x+ex .. v.y+ey)
    end
end

function Enemies:update(dt)
    for i, v in ipairs(self) do
        v.x, v.y, v.w, v.h = World:getRect(v.id)
        v.time = v.time + dt
    end
end

