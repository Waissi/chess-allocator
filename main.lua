local enet = require "enet"
local host = enet.host_create("0.0.0.0:6790", 64, 5)
local rng = love.math.newRandomGenerator(os.time())

local servers = {}
local players = {}
local pendingPlayer

local serverChannels = {
    ["init"] = 1,
    ["new_game"] = 2,
    ["update"] = 3
}

function love.load()
    print "===== Starting Chess Allocator ====="
end

function love.quit()
    print "===== Stoping Chess Allocator ====="
end

local get_peer = function(playerId)
    for peer, ids in pairs(players) do
        for _, id in ipairs(ids) do
            if id == playerId then return peer end
        end
    end
end

--- channel 1 => dispatch new players |
--- channel 2 => init new game |
--- channel 3 => game update
--- channel 4 => delete player
---@type fun(channel: number, data: string, peer: userdata)
local handle_event = {

    ---dispatch new players
    function(playerId, peer)
        if not pendingPlayer then
            pendingPlayer = { id = playerId, server = peer }
            players[peer] = players[peer] or {}
            players[peer][#players[peer] + 1] = playerId
            return
        end
        players[peer] = players[peer] or {}
        players[peer][#players[peer] + 1] = playerId
        local randomNumber = rng:random(1, 2)
        local whitePlayer = randomNumber == 1 and playerId or pendingPlayer.id
        local blackPlayer = playerId == whitePlayer and pendingPlayer.id or playerId
        local gameId = "w" .. whitePlayer .. "b" .. blackPlayer
        peer:send("w" .. whitePlayer, serverChannels["init"])
        pendingPlayer.server:send("b" .. blackPlayer, serverChannels["init"])
        peer:send(gameId, serverChannels["new_game"])
        pendingPlayer = nil
    end,

    ---init new game
    function(oldId, peer)
        local whitePlayerId = string.match(oldId, "w(.-)b")
        local blackPlayerId = string.match(oldId, "b(.*)")
        local whitePeer = get_peer(whitePlayerId)
        local blackPeer = get_peer(blackPlayerId)
        if not pendingPlayer then
            local randomNumber = rng:random(1, 2)
            local whitePlayer = randomNumber == 1 and whitePlayerId or blackPlayerId
            local blackPlayer = whitePlayerId == whitePlayer and blackPlayerId or whitePlayerId
            local gameId = "w" .. whitePlayer .. "b" .. blackPlayer
            peer:send("w" .. whitePlayer, serverChannels["init"])
            local pendingPeer = peer == whitePeer and blackPeer or whitePeer
            pendingPeer:send("b" .. blackPlayer, serverChannels["init"])
            peer:send(gameId, serverChannels["new_game"])
            return
        end
        local playerId = players[peer][whitePlayerId] and whitePlayerId or blackPlayerId
        local randomNumber = rng:random(1, 2)
        local whitePlayer = randomNumber == 1 and playerId or pendingPlayer.id
        local blackPlayer = whitePlayer == playerId and pendingPlayer.id or playerId
        local gameId = "w" .. whitePlayer .. "b" .. blackPlayer
        peer:send("w" .. whitePlayer, serverChannels["init"])
        pendingPlayer.server:send("b" .. blackPlayer, serverChannels["init"])
        peer:send(gameId, serverChannels["new_game"])
        pendingPlayer = {
            id = playerId == whitePlayerId and blackPlayerId or whitePlayerId,
            peer = peer == whitePeer and blackPeer or whitePeer
        }
    end,

    ---send update to server
    function(playerId)
        local peer = get_peer(playerId)
        peer:send(playerId, serverChannels["update"])
    end,

    ---delete player
    function(playerId, peer)
        if pendingPlayer and pendingPlayer.id == playerId then
            pendingPlayer = nil
        end
        for i, id in ipairs(players[peer]) do
            if id == playerId then
                table.remove(players[peer], i)
                break
            end
        end
    end
}

function love.update()
    if not host then return end
    local event = host:service()
    while event do
        if event.type == "receive" then
            handle_event[event.channel](event.data, event.peer)
        elseif event.type == "connect" then
            servers[#servers + 1] = event.peer
        elseif event.type == "disconnect" then
            for i, server in ipairs(servers) do
                if event.peer == server then
                    table.remove(servers, i)
                    break
                end
            end
            players[event.peer] = nil
        end
        event = host:service()
    end
end
