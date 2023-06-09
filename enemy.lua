function Enemies:draw()
    for i=1, #self do
        if self[i] ~= nil then
            local e = self[i]
            love.graphics.draw(e.image, e.x, e.y)
        end
    end
end

function Enemies:spawn(enemySpawns)
    for i,v in ipairs(enemySpawns) do
        local enemy = math.random(1, #EnemyTypes)
        self[i] = EnemyTypes[1]
        self[i].x = v.x
        self[i].y = v.y
        print("Enemy spawned at", v.x, v.y)
    end
end

function Enemies:onDeath()
    for i=1, #self do
        if self[i] ~= nil then
            if self[i].hp <= 0 then
                table.remove(self, i)
            end
        end
    end
end
