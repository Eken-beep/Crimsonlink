function Enemies:draw()
    for _, e in ipairs(self) do
        if e ~= nil then
            love.graphics.draw(e.image, e.x, e.y)
        end
    end
end

function Enemies:spawn(dt, n, x, y)
    if not (x and y) then
        for i=0, n do

        end
    else
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
