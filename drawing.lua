function DrawHealth()
    local sx,sy = 32,32

	local c = Player.stats.hp/Player.stats.maxHp
	local color = {2-2*c,2*c,0}
	love.graphics.setColor(color)
	love.graphics.print('Health: ' .. math.floor(Player.stats.hp),sx,sy)
	love.graphics.rectangle('fill', sx, 1.5*sy, Player.stats.hp, sy/2)

	love.graphics.setColor(1,1,1)
	love.graphics.rectangle('line', sx, 1.5*sy, Player.stats.maxHp, sy/2)
end

function DrawXp()
    local lx,ly = 1920*0.7, 20
    local x, y  = 1920/2 - lx/2, 60
    local xpPercentage = Player.stats.xp/CurrentXpMax

    love.graphics.setColor(0,0,0)
    love.graphics.rectangle("line", x, y, lx, ly)
    love.graphics.setColor(0,0,1)
    love.graphics.rectangle("fill", x, y, xpPercentage*lx, ly)
    love.graphics.setColor(0,0,0)
    love.graphics.print(Player.stats.xp .. ' / ' .. CurrentXpMax, (1920/2)-20, 64)
    love.graphics.print('Level ' .. Player.stats.level, W-50, 20)
    love.graphics.setColor(1,1,1)
end

function DrawDash()
    local h,w = 32,100
    local d = Player.dashData.dashMeter
    local dMax = Player.dashData.maxDashMeter
    local p = d/dMax
    love.graphics.setColor(1,0,0)
    love.graphics.rectangle("fill", 32, 180, p*w, h)
    love.graphics.setColor(0,0,0)
    love.graphics.rectangle("line", 32, 180, w, h)
    love.graphics.setColor(1,1,1)
end

function DamageIndicators:add(x, y, damage)
    local rx = math.random(x-Scale*50,x+Scale*50)
    local ry = math.random(y-Scale*50,y+Scale*50)
    table.insert(self, {rx,ry,0,damage,1})
end

function DamageIndicators:clean(dt)
    for i=1, #self do
        if self[i] ~= nil then
            self[i][3] = self[i][3] + dt
            self[i][2] = self[i][2] - 0.12
            self[i][5] = self[i][5] - dt
            if self[i][3] >= 1 then
                table.remove(self, i)
            end
        end
    end
end

function DamageIndicators:draw()
    for i=1, #self do
        if self[i] ~= nil then
            love.graphics.setColor(1,0,0,self[i][5])
            love.graphics.print('-'..self[i][4], self[i][1], self[i][2])
            love.graphics.setColor(1,1,1)
        end
    end
end

function Player.backpack:drawBackpack()
    for i,item in ipairs(self) do
        -- The slot x position, calculated by the position out of 4 slots where i is the index of the slot and -3 because the first slot begins 2 steps to the left of the middle of the screen
        local slotX = 1920/2-(50*(i-3))

        love.graphics.rectangle("line", slotX, 1080-50*Scale, 50, 50)
        love.graphics.draw(item.image, slotX, 1080-50*Scale)
    end
end
