-- If you don't understand this, don't modify it.
-- If you do understand it, only change it if you know what you're doing.

-- Collect identifiers for a player
local function collectIdentifiers(src)
    local id = {
        steam = nil,
        discord = nil,
        license = nil,
        license2 = nil,
        live = nil,
        xbl = nil,
        hwid2 = nil,
        hwid4_1 = nil,
        hwid4_2 = nil,
        hwid4_3 = nil
    }
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local identifier = GetPlayerIdentifier(src, i)
        if string.find(identifier, "steam:") then id.steam = identifier end
        if string.find(identifier, "discord:") then id.discord = identifier end
        if string.find(identifier, "license:") and not id.license then id.license = identifier end
        if string.find(identifier, "license2:") then id.license2 = identifier end
        if string.find(identifier, "live:") then id.live = identifier end
        if string.find(identifier, "xbl:") then id.xbl = identifier end
        if string.find(identifier, "hwid2:") then id.hwid2 = identifier end
        if string.find(identifier, "hwid4:") then
            if not id.hwid4_1 then id.hwid4_1 = identifier
            elseif not id.hwid4_2 then id.hwid4_2 = identifier
            elseif not id.hwid4_3 then id.hwid4_3 = identifier end
        end
    end
    return id
end

local player_pings = {}
local player_warnings = {}
local player_connect_times = {}

AddEventHandler('playerDropped', function()
    local src = tostring(source)
    player_pings[src] = nil
    player_warnings[src] = nil
    player_connect_times[src] = nil
end)

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = tostring(source)
    player_connect_times[src] = os.time()
end)

-- event spam protection
local last_ping_time = {}
local min_ping_interval = 2 -- seconds

-- discord webhook for logs
local DISCORD_WEBHOOK = "YOUR_DISCORD_WEBHOOK_URL_HERE" -- replace with your webhook URL

local function sendDiscordLog(msg)
    PerformHttpRequest(DISCORD_WEBHOOK, function(err, text, headers) end, 'POST', json.encode({content = msg}), {['Content-Type'] = 'application/json'})
end

local function sendDiscordKickEmbed(playerId, reason)
    local id = collectIdentifiers(playerId)
    local name = GetPlayerName(playerId) or "unknown"
    local ip = id.ip or "-"
    local embed = {
        {
            ["title"] = "🛡️ vehicle-fight anticheat log",
            ["color"] = 16711680, -- red
            ["description"] = table.concat({
                ":bust_in_silhouette: **Name:** " .. name,
                ":id: **PlayerID:** " .. tostring(playerId),
                ":hash: **Discord:** " .. (id.discord or "-"),
                ":video_game: **Steam:** " .. ((id.steam and id.steam ~= "steam:00000000000000000" and id.steam) or "None/Hidden"),
                ":key: **License:** " .. (id.license or "-"),
                ":key: **License2:** " .. (id.license2 or "-"),
                ":satellite: **Live:** " .. (id.live or "-"),
                ":x: **XBL:** " .. (id.xbl or "-"),
                ":desktop_computer: **IP:** " .. ip,
                ":no_entry: **Reason:** " .. (reason or "-")
            }, "\n"),
            ["timestamp"] = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }
    }
    PerformHttpRequest(DISCORD_WEBHOOK, function(err, text, headers) end, 'POST', json.encode({embeds = embed}), {['Content-Type'] = 'application/json'})
end

Citizen.CreateThread(function()
    while true do
        local now = os.time()
        local activePlayers = {}
        for _, playerId in ipairs(GetPlayers()) do
            playerId = tostring(playerId)
            activePlayers[playerId] = true
            local connectedAt = player_connect_times[playerId] or now
            if now - connectedAt > 30 then -- 30s grace
                local lastPing = player_pings[playerId] or 0
                local warnCount = player_warnings[playerId] or 0
                if now - lastPing > 7 then
                    player_warnings[playerId] = warnCount + 1
                    if player_warnings[playerId] >= 3 then
                        local reason = "Resource stopper detected (3x missing heartbeat)"
                        sendDiscordKickEmbed(playerId, reason)
                        DropPlayer(playerId, 'vehicle-fight 🛡️ You have been kicked from the server: RESOURCE STOPPER detected')
                    end
                else
                    player_warnings[playerId] = 0
                end
            end
        end
        -- cleanup tables for disconnected players
        for k in pairs(player_pings) do if not activePlayers[k] then player_pings[k] = nil end end
        for k in pairs(player_warnings) do if not activePlayers[k] then player_warnings[k] = nil end end
        for k in pairs(player_connect_times) do if not activePlayers[k] then player_connect_times[k] = nil end end
        Citizen.Wait(5000)
    end
end)

local function handlePingEvent()
    local src = tostring(source)
    local now = os.time()
    if last_ping_time[src] and (now - last_ping_time[src]) < min_ping_interval then
        player_warnings[src] = (player_warnings[src] or 0) + 1
            if player_warnings[src] >= 3 then
            local reason = "Event spam detected (3x fast event triggers)"
            sendDiscordKickEmbed(src, reason)
            DropPlayer(src, 'vehicle-fight 🛡️ You have been kicked from the server: EVENT SPAM detected')
        end
        return
    end
    last_ping_time[src] = now
    player_pings[src] = now
    player_warnings[src] = 0
    if not player_connect_times[src] then player_connect_times[src] = now end
end

RegisterNetEvent('vehiclefight_ping')
AddEventHandler('vehiclefight_ping', handlePingEvent)

RegisterCommand("vehiclefight_logtest", function(source, args, raw)
    if source == 0 then -- only from server console
        local testPlayerId = 1
        local testReason = table.concat(args, " ")
        if testReason == "" then testReason = "test kick log from server console" end
        sendDiscordKickEmbed(testPlayerId, testReason)
        print("test kick log sent to Discord (PlayerID: " .. tostring(testPlayerId) .. ") reason: " .. testReason)
    else
        print("this command can only be used from the server console")
    end
end, false)
