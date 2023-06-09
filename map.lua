function MapDrawer()
    -- Translate world so that player is always centred
	local tx = math.floor(Player.x - W / 2)
	local ty = math.floor(Player.y - H / 2)

	-- Draw world with translation and scaling
	Currentmap:draw(0, 0, Scale)
    Currentmap:bump_draw()
end

function InstantiateMap(map)
    Currentmap = map
    World = Bump.newWorld(32)
    map:bump_init(World)
    -- Create pairs of points where edge shapes should be drawn between
    local enemySpawns = {}
    local enemyLayer = map.layers[#map.layers-1].objects
    for i, v in ipairs(enemyLayer) do
        enemySpawns[i] = {x = v.x, y = v.y}
        print("enemy position ".. i .. " got", v.x, v.y)
    end
    print("enemy1 position", enemySpawns[1].x)
    local px = map.layers[#map.layers].objects[1].x
    local py = map.layers[#map.layers].objects[1].y
    print("Player spawn: ",px,py)
    World:add(Player, px, py, 50, 50)
    Enemies:spawn(enemySpawns)
end
