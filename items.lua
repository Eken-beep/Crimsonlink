-- Weapon consists of a table: { Image, Damage, Range, Cooldown seconds, Critchance % }
Weapons = { hand = { image = nil, damage = 5, range = 250, cooldown = 1, crit = 8 }
          }

Items = {
    empty = { type = "empty", image = nil, use = function() return nil end },
    potionHp = { type = "potion", image = nil, heal = 30 },
    potionStrength = { type = "potion", image = nil, strength = 1.3 }
}
