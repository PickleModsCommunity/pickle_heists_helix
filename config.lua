Config = {}
Config.Debug = true
Config.Framework = "qb" -- "qb" / "standalone"
Config.Default = {
    -- These are the default settings for the gates spawned in the heists.
    gateModel = "/Engine/BasicShapes/Cube.Cube",
    gateMaterial = "/Game/Items_HL/Materials/MI_Metal.MI_Metal",
    gateTransitionHeight = 125.0,
    gateTransitionDuration = 2.0,
    gateScale = vector3(0.05, 2.5, 2.5),
    -- These are the default settings for the power boxes spawned in the heists.
    powerBoxModel = "/Game/Items_HL/Assets/SM_PowerBox2.SM_PowerBox2",
    cooldown = 1, -- The cooldown in minutes for the heist to be started again.
    required = {
        {type = "item", name = "welding_torch", amount = 1}, -- This will only require the item from the player's inventory.
        {type = "item", name = "hacking_chip", amount = 1, remove = true}, -- This will remove the item from the player's inventory.
    },
}

Config.Loot = {
    money = {
        rewardType = "cash",
        model = "/Game/DarkRP/Assets/Meshes/SM_MoneyBag.SM_MoneyBag",
    },
}

Config.Heists = {
    {
        label = "Downtown Heist",
        minPlayers = 1, -- Minimum players to start the heist.
        maxPlayers = 4, -- Maximum players to join the heist.
        cooldown = Config.Default.cooldown, -- The cooldown in minutes for the heist to be started again.
        required = Config.Default.required,
        powerBoxes = {
            {
                targetGates = {"first_gate"}, 
                coords = vector3(-6624.000, 3975.644, -252.610), 
                heading = -89.231964111328,
                triggerAlarm = true, -- If true, the alarm will be triggered when the power box is disabled.
            },
            {
                targetGates = {"second_gate"}, 
                coords = vector3(-6699.985, 2623.986, -248.449), 
                heading = -49.261978149414,
            },
            {
                targetGates = {"third_gate"}, 
                coords = vector3(-7536.000, 3935.525, -239.528), 
                heading = -86.091979980469,
            },
        },
        gates = {
            -- vector3(-6312.385, 3688.548, -299.850),
            ["first_gate"] = {coords = vector3(-6633.779, 3821.220, -270.850), heading = -180.23, scale = vector3(0.05, 2.5, 2.5)},
            ["second_gate"] = {coords = vector3(-7033.779, 3821.220, -270.850), heading = -180.23, scale = vector3(0.05, 2.5, 2.5)},
            ["third_gate"] = {coords = vector3(-7543.779, 3821.220, -250.850), heading = -180.23, scale = vector3(0.05, 2.5, 2.5)},
        },
        loot = {
            {
                type = "money", -- Types: money
                amount = {min = 1000, max = 2000}, -- Or amount = 1000 for a fixed amount.
                coords = vector3(-8822.220, 4142.543, -300.000),
                heading = -180.0,
            },
            {
                type = "money", -- Types: money
                amount = {min = 1000, max = 2000}, -- Or amount = 1000 for a fixed amount.
                coords = vector3(-8822.476, 3960.129, -300.000),
                heading = -180.0,
            },
            {
                type = "money", -- Types: money
                amount = {min = 1000, max = 2000}, -- Or amount = 1000 for a fixed amount.
                coords = vector3(-8820.298, 3775.390, -300.000),
                heading = -180.0,
            },
            {
                type = "money", -- Types: money
                amount = {min = 1000, max = 2000}, -- Or amount = 1000 for a fixed amount.
                coords = vector3(-8824.301, 3595.939, -300.000),
                heading = -180.0,
            },
            {
                type = "money", -- Types: money
                amount = {min = 1000, max = 2000}, -- Or amount = 1000 for a fixed amount.
                coords = vector3(-8823.504, 3405.997, -300.000),
                heading = -180.0,
            },
            {
                type = "money", -- Types: money
                amount = {min = 1000, max = 2000}, -- Or amount = 1000 for a fixed amount.
                coords = vector3(-8821.833, 3218.650, -300.000),
                heading = -180.0,
            },
            {
                type = "money", -- Types: money
                amount = {min = 1000, max = 2000}, -- Or amount = 1000 for a fixed amount.
                coords = vector3(-8821.154, 3033.502, -300.000),
                heading = -180.0,
            },
            {
                type = "money", -- Types: money
                amount = {min = 1000, max = 2000}, -- Or amount = 1000 for a fixed amount.
                coords = vector3(-8826.410, 2849.310, -300.000),
                heading = -180.0,
            },
            {
                type = "money", -- Types: money
                amount = {min = 1000, max = 2000}, -- Or amount = 1000 for a fixed amount.
                coords = vector3(-5802.694, 2385.851, -392.000),
                heading = 178.48,
            },
        },
        sirens = {
            {
                coords = vector3(-8181.558, 3557.434, 20.850),
                heading = 0.0,
            },
            {
                coords = vector3(-7498.324, 3929.721, 20.850),
                heading = 0.0,
            },
            {
                coords = vector3(-6849.158, 3276.309, 20.850),
                heading = 0.0,
            },
            {
                coords = vector3(-6322.665, 3342.642, 20.850),
                heading = 0.0,
            },
        },
        startLocation = {
            size = vector3(200.0, 200.0, 40.0),
            areaSize = vector3(5000.0, 5000.0, 5000.0), -- The area size of the bank, when a player exits this area it will be considered as an escape.
            coords = vector3(-5312.177, 1756.956, -399.850),
            heading = 90.0,
        },
        fenceLocation = {
            size = vector3(200.0, 200.0, 40.0),
            areaSize = vector3(5000.0, 5000.0, 5000.0), -- The area size of the fence location, when a player exits this area it will be considered as the end of the heist.
            coords = vector3(-4060.799, 14955.302, -399.850),
            heading = 90.0,
        },
        getawayVehicle = {
            model = "/VehicleSystem/Blueprints/Vehicles/Bauhaus/BP_Bauhaus_Vehicle.BP_Bauhaus_Vehicle_C",
            coords = vector3(-5250.427, 2749.031, -408.000),
            heading = 90.0,
        },
    }
}