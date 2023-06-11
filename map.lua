function MapDrawer()
    for i,v in ipairs(Currentmap.layers) do
        if v.type == "tilelayer" then
            Currentmap:drawLayer(v)
        end
    end
    Currentmap:bump_draw()
end

function InstantiateMap(map)
    Currentmap = map
    World = Bump.newWorld(32)
    map:bump_init(World)
    -- Create pairs of points where edge shapes should be drawn between
    local px = map.layers[#map.layers].objects[1].x
    local py = map.layers[#map.layers].objects[1].y
    print("Player spawn: ",px,py)
    World:add(Player, px, py, 50, 50)
    --Enemies:spawn()
end
