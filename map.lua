function MapDrawer()
    for i,v in ipairs(Currentmap.layers) do
        if v.type == "tilelayer" then
            Currentmap:drawLayer(v)
        end
    end
end

function InstantiateMap(map)
    Currentmap = map
    World = Bump.newWorld(32*Scale)
    map:bump_init(World)
    -- Create pairs of points where edge shapes should be drawn between
    --local px = map.layers[#map.layers].objects[1].x
    --local py = map.layers[#map.layers].objects[1].y
    World:add(Player, Scale*(MapXOffset+60*32)/2, Scale*(MapYOffset+33*32)/2, Player.character:getWidth(), Player.character:getHeight())
end

function DroppedItems:draw()
    for i,v in ipairs(self) do
        love.graphics.draw(v.image, v.x, v.y)
    end
end

function DroppedItems:add(item, x, y)
    local i = {item = item, x = x, y = y, time = 0}
    table.insert(self, i)
end

-- Called when you want to remove an item (duh) and the player picks it up, return value is the actual item that should be added or smth so used to add to backpack only
function DroppedItems:remove(i)
    table.remove(self, i)
    return i.item
end

function DroppedItems:update(dt)
    for i,v in ipairs(self) do
        v.time = v.time+dt
        v.y = v.y+10*math.cos(v.time)
    end
end

function DroppedItems:pickup()
    for i,v in ipairs(self) do
        if CheckCollision(Player.x, Player.y, Player.w, Player.h, i.x, i.y, 50,50) then
            if love.keyboard.isDown("lctrl") or Joystick:isGamepadDown("a") then
                for i2,v2 in ipairs(Player.backpack) do
                    if v2 == Items.empty then v2 = v end
                end
            end
        end
    end
end
