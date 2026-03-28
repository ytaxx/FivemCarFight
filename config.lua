Config = {
    -- Allowed vehicles (you can shoot backwards in these)
    -- Keep trailing commas on lines except the last one.
    allowedVehicles = {
        ["example"] = true,
        ["perfspytt"] = true,
        ["abhawk"] = true,
        ["18performante"] = true,
        ["fer488beast"] = true,
        ["p1lbwk"] = true,
        ["perfspytt"] = true,
        ["jeslbwk"] = true
    },

    -- Angle restriction range (degrees)
    restrictionAngleMin = 230, -- default: 230
    restrictionAngleMax = 330, -- default: 330

    -- Speed threshold (km/h)
    restrictionSpeed = 20, -- default: 20

    -- Collision system and threshold
    collisionSystem = true, -- true/false
    collisionSpeed = 70, -- default: 70 (km/h)

    -- Icons used for 3D indicators
    icons = {
        Speed = "❌",
        Angle = "❌",
        PassengerAngle = "❌"
    },

    -- Debug: keep false on production servers
    Debug = true,

    -- Disable action mode (toggle)
    ActionModeDisable = true
}
