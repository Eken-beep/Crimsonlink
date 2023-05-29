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

function DrawXp()
    local lx,ly = W*0.7,20
    local x, y  = W/2-lx/2, 60
    local xpPercentage = Player.stats.xp/CurrentXpMax

    love.graphics.setColor(0,0,0)
    love.graphics.rectangle("line", x, y, lx, ly)
    love.graphics.setColor(0,0,1)
    love.graphics.rectangle("fill", x, y, xpPercentage*lx, ly)
    love.graphics.setColor(0,0,0)
    love.graphics.print(Player.stats.xp .. ' / ' .. CurrentXpMax, (W/2)-20, 64)
    love.graphics.print('Level ' .. Player.stats.level, W-50, 20)
    love.graphics.setColor(1,1,1)
end

function DamageIndicators:add(x, y, damage)
    local rx = math.random(x-50,x+50)
    local ry = math.random(y-50,y+50)
    table.insert(self, {rx,ry,0,damage})
end

function DamageIndicators:clean(dt)
    for i=1, #self do
        if self[i] ~= nil then
            self[i][3] = self[i][3] + dt
            if self[i][3] >= 2 then
                table.remove(self, i)
            end
        end
    end
end

function DamageIndicators:draw()
    for i=1, #self do
        if self[i] ~= nil then
            love.graphics.setColor(1,0,0)
            love.graphics.print('-'..self[i][4], self[i][1], self[i][2])
            love.graphics.setColor(1,1,1)
        end
    end
end