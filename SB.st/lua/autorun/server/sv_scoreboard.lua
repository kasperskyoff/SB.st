util.AddNetworkString("RequestPlayerLink")

local function GetCountry( co, ip )
    http.Fetch('https://api.country.is/' .. ip, function(body, _, _, code)
        local result = util.JSONToTable(body)
        coroutine.resume(co, result['country'])
    end)
end

net.Receive("RequestPlayerLink", function(len, ply)
    local target = net.ReadEntity()
    if not IsValid(target) then return end

    local link = "http://example.com/profile/" .. target:SteamID()
    net.Start("RequestPlayerLink")
    net.WriteString(link)
    net.Send(ply)
end)

hook.Add( 'PlayerInitialSpawn', '_scoreboard_country', function(ply)

    local co = coroutine.create(function(country)
        ply:SetNW2String('scoreboard_country', country)
    end)

    local ip = string.Explode(':', ply:IPAddress())[1]
    GetCountry(co, ip)

end )