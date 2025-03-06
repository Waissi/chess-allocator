local enet = require "enet"
local host = enet.host_create("0.0.0.0:6790")
local subsribers = {}

function love.quit()
    print "===== Stoping Chess PubSub ====="
end

function love.update()
    if not host then return end
    local event = host:service(100)
    while event do
        if event.type == "receive" then
            for _, subsriber in ipairs(subsribers) do
                subsriber:send(event.data)
            end
        elseif event.type == "connect" then
            subsribers[#subsribers + 1] = event.peer
        elseif event.type == "disconnect" then
            for i, subsriber in ipairs(subsribers) do
                if event.peer == subsriber then
                    table.remove(subsribers, i)
                    break
                end
            end
        end
        event = host:service()
    end
end

print "===== Starting Chess PubSub ====="
