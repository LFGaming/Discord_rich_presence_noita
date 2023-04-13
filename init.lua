package.path = package.path .. ";.\\mods\\Discord_rich_presence_noita\\lib\\?.lua"
package.cpath = package.cpath .. ";.\\mods\\Discord_rich_presence_noita\\bin\\?.dll"

dofile_once("mods/Discord_rich_presence_noita/lib/coroutines.lua")

local discordRPC = require("discordRPC")

local appId = "814077146904526858"

function discordRPC.ready(userId, username, discriminator, avatar)
    print(string.format("Discord: ready (%s, %s, %s, %s)", userId, username, discriminator, avatar))
end

function discordRPC.disconnected(errorCode, message)
    print(string.format("Discord: disconnected (%d: %s)", errorCode, message))
end

function discordRPC.errored(errorCode, message)
    print(string.format("Discord: error (%d: %s)", errorCode, message))
end

function discordRPC.joinGame(joinSecret)
    print(string.format("Discord: join (%s)", joinSecret))
end

function discordRPC.spectateGame(spectateSecret)
    print(string.format("Discord: spectate (%s)", spectateSecret))
end

function discordRPC.joinRequest(userId, username, discriminator, avatar)
    print(string.format("Discord: join request (%s, %s, %s, %s)", userId, username, discriminator, avatar))
    discordRPC.respond(userId, "yes")
end

local presence = {
    state = "Playing noita",
    details = "This is a rich presence test.",
    startTimestamp = os.time(),
    largeImageKey = "coverimage",
    smallImageKey = "goldnugget",
    smallImageText = "",
    largeImageText = "",
}

local old_presence = {}

local rpc_initialized = false

local function get_player()
    local players = EntityGetWithTag("player_unit")
    if players[1] ~= nil then
        return players[1]
    end
    return nil
end

local function shallowcopy(orig)
    if type(orig) == 'table' then
        local copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
        return copy
    end
    -- number, string, boolean, etc
    return orig
end

local function match_tables(table1, table2)
    for k, v in pairs(table1)do
        if table2[k] ~= v then
            return false
        end
    end
    return true
end

local function firstToUpper(str)
    return str:gsub("^%l", string.upper)
end

local function get_biome_name(entity)
    local x, y = EntityGetTransform(entity)

    local current_biome = GameTextGetTranslatedOrNot( BiomeMapGetName(x, y) )

    if current_biome == "_EMPTY_" then
        current_biome = "Overworld"
    end

    if x < -17920 then
        current_biome = "West "..current_biome
    elseif x > 17920 then
        current_biome = "East "..current_biome
    end

    return current_biome
end

function OnWorldPreUpdate()
	wake_up_waiting_threads(1)
end

local function update_discord()
    local newgame_n = tonumber( SessionNumbersGetValue("NEW_GAME_PLUS_COUNT") )

    local t = os.date("*t")
    local seed = string.format("%d%02d%d", t.year, t.month, t.day)

    if StatsGetValue("world_seed") == seed and newgame_n == 0 then
        presence.largeImageText = "Daily run"
    elseif newgame_n == 0 then
        presence.largeImageText = "Regular run"
    else
        presence.largeImageText = "NG+ Cycle: "..tostring(newgame_n)
    end

    local player = get_player()
    if player ~= nil then
        local biome_name = get_biome_name(player)
        presence.details = "Biome: "..firstToUpper(biome_name)

        local curbiome = biome_name:gsub("%s+", "_"):lower()
        presence.largeImageKey = curbiome

        local damagemodels = EntityGetComponent(player, "DamageModelComponent")
        if damagemodels ~= nil then
            for _, damagemodel in ipairs(damagemodels) do
                local max_hp = math.floor(ComponentGetValue2(damagemodel, "max_hp") * 25)
                local cur_hp = math.floor(ComponentGetValue2(damagemodel, "hp") * 25)

                presence.state = string.format("Health: %d / %d", cur_hp, max_hp)
            end
        end

        local wallet = EntityGetFirstComponent(player, "WalletComponent")
        if wallet ~= nil then
            local money = ComponentGetValue2(wallet, "money")
            presence.smallImageText = "Gold: "..tostring(money)
        end
    end

    if player == nil then
        presence.state = "Dead!"
    end

    local polymorphed_entities = EntityGetWithTag("polymorphed") or {}
    for _, entity_id in ipairs(polymorphed_entities) do
        local is_player = false
        local game_stats_comp = EntityGetFirstComponent(entity_id, "GameStatsComponent")
        if game_stats_comp ~= nil then 
            is_player = ComponentGetValue2(game_stats_comp, "is_player")
        end
        if is_player then
            --player is indeed polymorphed do your thing
            presence.state = "Polymorphed!"
        end
    end

    if rpc_initialized then
        if not match_tables(presence, old_presence) then
            discordRPC.updatePresence(presence)
            old_presence = shallowcopy(presence)
        end
        discordRPC.runCallbacks()
    end
end

function OnPlayerSpawned( player_entity )
    discordRPC.initialize(appId, true)
    rpc_initialized = true
    async_loop(function()
        local success, error_msg = pcall(update_discord)
        if not success then
            print_error("Lua script failed in coroutine: " .. error_msg)
        end
        wait(60) --885 --60
    end)
end

