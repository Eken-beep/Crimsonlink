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
        local enemy = EnemyTypes[math.random(1, #EnemyTypes)]
        enemy.x = v.x
        enemy.y = v.y
        enemy.time = 0
        table.insert(self, enemy)
        World:add(#self, v.x, v.y, enemy.image:getWidth(), enemy.image:getHeight())
    end
end

function Enemies:attack()
    for i, v in ipairs(self) do
        if Distance(v.x+25, v.y+25, Player.x+Player.w/2, Player.y+Player.h/2) < v.range and v.time > 2 then
            Player.stats.hp = Player.stats.hp - v.damage
            v.time = 0
        end
    end
end

function Enemies:onDeath()
    for i=1, #self do
        if self[i] ~= nil then
            if self[i].hp <= 0 then
                table.remove(self, i)
                World:remove(i)
            end
        end
    end
end

function Enemies:move(dt)
    for i, v in ipairs(self) do
        if Distance(v.x, v.y, Player.x, Player.y) < 4000 then
            local dx = v.x - Player.x
            local dy = v.y - Player.y
            local a = math.atan2(-dy, -dx)
            local ex = dt*10*math.cos(a)
            local ey = dt*10*math.sin(a)
            World:move(i, v.x + ex, v.y + ey)
        end
    end
end

function Enemies:update(dt)
    for i, v in ipairs(self) do
        local x, y, _, _ = World:getRect(i)
        v.x, v.y = x, y
        v.time = v.time + dt
    end
end

