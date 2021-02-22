package.path = package.path .. ";.\\mods\\discord_link\\lib\\?.lua"
package.cpath = package.cpath .. ";.\\mods\\discord_link\\bin\\?.dll"

dofile_once("mods/discord_link/lib/coroutines.lua")

local discordRPC = require("discordRPC")

local appId = "731521302006988890"

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
now = os.time(os.date("*t"))
presence = {
    state = "Playing noita",
    details = "This is a rich presence test.",
    startTimestamp = now,
    largeImageKey = "coverimage",
    smallImageKey = "goldnugget",
    smallImageText = "",
    largeImageText = "",
}

old_presence = {}

local rpc_initialized = false

function get_player()
    local players = EntityGetWithTag("player_unit")
    if(players[1] ~= nil)then
        return players[1]
    else
        return nil
    end
end

function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function match_tables(table1, table2)
    local matching = true
    for k, v in pairs(table1)do
        if(table2[k] ~= v)then
            matching = false
        end
    end
    return matching
end

function firstToUpper(str)
    return (str:gsub("^%l", string.upper))
end


function OnWorldPreUpdate() 
	wake_up_waiting_threads(1) 
end

function OnPlayerSpawned( player_entity )
    discordRPC.initialize(appId, true)
    rpc_initialized = true
    async_loop(function()
        
        local newgame_n = tonumber( SessionNumbersGetValue("NEW_GAME_PLUS_COUNT") )

        local t = os.date ("*t")
        if(t.month < 10)then
            t.month = "0"..tostring(t.month)
        end
        local seed = tostring(t.year)..tostring(t.month)..tostring(t.day)

        if(tostring(StatsGetValue("world_seed")) == tostring(seed) and newgame_n == 0)then
            presence.largeImageText = "Daily run"  
        elseif(newgame_n == 0)then
            presence.largeImageText = "Regular run"       
        else
            presence.largeImageText = "NG+ Cycle: "..tostring(newgame_n)
        end

        player = get_player()
        if(player ~= nil)then
            local x, y = EntityGetTransform(player)

            local current_biome = GameTextGetTranslatedOrNot( BiomeMapGetName(x, y) )

            if(current_biome == "_EMPTY_")then
                current_biome = "Overworld"
            end

            if(x < -17920)then
                current_biome = "West "..current_biome
            elseif(x > 17920)then
                current_biome = "East "..current_biome                
            end

            
            presence.details = "Biome: "..firstToUpper(current_biome)

            local damagemodels = EntityGetComponent(player, "DamageModelComponent")
            if (damagemodels ~= nil) then
                for i, damagemodel in ipairs(damagemodels) do
                    local max_hp = math.floor(tonumber(ComponentGetValue2(damagemodel, "max_hp")) * 25)
                    local cur_hp = math.floor(tonumber(ComponentGetValue2(damagemodel, "hp")) * 25)
                    
                    presence.state = "Health: "..tostring(cur_hp).." / "..tostring(max_hp)
                       
                    --GamePrint(presence.state)
                end
            end
            local wallet = EntityGetFirstComponent(player, "WalletComponent")
            if(wallet ~= nil)then
                local money = tonumber(ComponentGetValueInt(wallet, "money"))

                presence.smallImageText = "Gold: "..tostring(money)
            end
        end

        if(player == nil)then
            --if (tostring(cur_hp) == 0) then
            presence.state = "Dead!"
        end

        if(rpc_initialized)then
            if(not match_tables(presence, old_presence))then
                discordRPC.updatePresence(presence)
                old_presence = shallowcopy(presence)
            end
            discordRPC.runCallbacks()
        end
        wait(60) --885 --60
    end)
end

