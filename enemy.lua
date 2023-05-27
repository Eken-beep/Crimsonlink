function DrawEnemies()
    for i=1, #Enemies do
        if Enemies[i] ~= nil then
            local e = Enemies[i]
            love.graphics.draw(e.image, e.x, e.y)
        end
    end
end

function EnemyDeath()
    for i=1, #Enemies do
        if Enemies[i].hp <= 0 then
            table.remove(Enemies, i)
        end
    end
end
