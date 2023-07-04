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
        love.graphics.draw(v.item.image, v.x, v.y, 0, 1, 1, 0, v.ry)
    end
end

function DroppedItems:add(item, x, y)
    local i = {item = item, x = x, y = y, ry = y, time = 0}
    table.insert(self, i)
    print("Item " .. i.item.id .. " spawned at:", i.x, i.y)
end

-- Called when you want to remove an item (duh) and the player picks it up, return value is the actual item that should be added or smth so used to add to backpack only
function DroppedItems:remove(i)
    local item = self[i].item
    table.remove(self, i)
    return item
end

function DroppedItems:update(dt)
    for i,v in ipairs(self) do
        v.time = v.time+dt
        v.ry = 10*math.cos(2*v.time)
    end
end

function DroppedItems:pickup()
    for i,droppedItem in ipairs(self) do
        if CheckCollision(Player.x, Player.y, Player.w, Player.h, droppedItem.x, droppedItem.y, 50,50) then
            if love.keyboard.isDown(Keybinds.keyboard.pickupMode) or Joystick:isGamepadDown(Keybinds.controller.pickupMode) then
                -- Check whether the item already is in the backpack and then pick it up automatically and return the function
                for j,backpackSlot in ipairs(Player.backpack) do
                    if backpackSlot.id == droppedItem.item.id then backpackSlot.ammount = backpackSlot.ammount + 1 DroppedItems:remove(i) return end
                end

                -- Otherwise if the item isnt already in the backpack, then if some of the keys/buttons of the backpack slots are pressed then put the item in that slot and drop the old item if the slot wasn't empty
                for j=1,4 do
                    if Joystick:isGamepadDown(Keybinds.controller.backpack[j]) then
                        if Player.backpack[j] == Items.empty then
                            Player.backpack[j] = droppedItem.item
                        else
                            local x = math.random(droppedItem.x-25, droppedItem.x+25)
                            local y = math.random(droppedItem.y-25, droppedItem.y+25)
                            Player.backpack[j] = droppedItem.item
                            DroppedItems:add(Player.backpack[j], x, y)
                            return
                        end
                    end
                end
            end
        end
    end
end
