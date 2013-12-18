class("Roadtrip")

function Roadtrip:__init()
	self.playersAtWaypoint = nil
	self.totalMembers = nil
	self.inChat = false
	Network:Subscribe("RoadtripGetWaypoint", self, self.GetWaypoint)
	Network:Subscribe("RoadtripBroadcastWaypoint", self, self.SetWaypoint)
	Network:Subscribe("AtWaypointUpdate", self, self.AtWaypointUpdate)
	Network:Subscribe("RoadtripChatToggle", self, self.RoadtripChatToggle)
	Network:Subscribe("RoadtripChatMessage", self, self.RoadtripChatMessage)
    Events:Subscribe( "ModuleLoad", self, self.ModulesLoad )
    Events:Subscribe( "ModulesLoad", self, self.ModulesLoad )
    Events:Subscribe( "ModuleUnload", self, self.ModuleUnload )
    Events:Subscribe( "PlayerChat", self, self.PlayerChat)
	Events:Subscribe("Render", self, self.Draw)
end

function Roadtrip:PlayerChat(args)
	if self.inChat then
		return false
	end
	return true
end

function Roadtrip:GetWaypoint()
	local waypoint = Waypoint:GetPosition()
	if waypoint.y == 200 and waypoint.x < 0 and waypoint.x > -0.01 and waypoint.z < 0 and waypoint.z > -0.01 then
		Network:Send("RoadtripSetWaypoint", {LocalPlayer:GetId(), false})
	else
		Network:Send("RoadtripSetWaypoint", {LocalPlayer:GetId(), waypoint})
	end
end

function Roadtrip:SetWaypoint(waypoint)
	Waypoint:SetPosition(waypoint)
end

function Roadtrip:AtWaypointUpdate(args)
	self.playersAtWaypoint = args[1]
	self.totalMembers = args[2]
end

function Roadtrip:RoadtripChatToggle(inChat)
	self.inChat = inChat
	if inChat then
		Chat:Print('You are now in roadtrip chat.', Color(255,255,255))
	else
		Chat:Print('You are now in global chat.', Color(255,255,255))
	end
end

function Roadtrip:RoadtripChatMessage(args)
	Chat:Print('[Roadtrip] '..args[1]..': '..args[2], Color(255,255,255))
end

function Roadtrip:Draw()
	if self.playersAtWaypoint and self.totalMembers then
		local text = self.playersAtWaypoint .. '/'.. #self.totalMembers .. ' players at waypoint'
		local position = Vector2(9, Render.Height - 6)
		position.y = position.y - Render:GetTextHeight(text, TextSize.Default)
		Render:DrawText(position, text, Color(255,255,255))
	end
end

function Roadtrip:ModulesLoad()
    Events:FireRegisteredEvent( "HelpAddItem",
        {
            name = "Roadtrip",
            text = 
                "Roadtrip allows you to go roadtrips with other players " ..
                "as the faction did with great ease.\n \n" ..
                "Commands: (for leader commands see 'Roadtrip - Leader')\n" ..
                "/roadtrip - Enter or leave the roadtrip\n" ..
                "/roadtrip chat - Enter or leave the private roadtrip chat\n" ..
                "/roadtrip votekick <player name> - Vote to kick a player, minimum of half number of members or 5 votes (which ever is lower)\n" ..
                "/roadtrip goto <player name> - Teleport to another player in the roadtrip\n" ..
                "/roadtrip gotowp - Teleport to the waypoint if there is one\n" ..
                "/roadtrip list - Lists the people online and their distance from the waypoint\n\n" ..
                "Note, /rt can be used instad of /roadtrip"
        })

    Events:FireRegisteredEvent( "HelpAddItem",
        {
            name = "Roadtrip - Leader",
            text = 
                "The leader is responsible for settting the waypoint " ..
                "and ensure that none is misbehaving.\n If you no longer " ..
                "want to be leader, do /roadtrip resign.\n\n" ..
                "Commands:\n" ..
                "/roadtrip waypoint (or /roadtrip wp) - Sets the roadtrips waypoint to the one you set on your map (F1)\n" ..
                "/roadtrip resign - Pass the leadership to someone else\n" ..
                "/roadtrip kick <player name> - Kick a player\n" ..
                "/roadtrip ban <player name> - Ban a player (they can rejoin once the leader changes)\n" ..
                "/roadtrip transfer <player name> - Pass your leadership to someone else\n\n" ..
                "Note, /rt can be used instad of /roadtrip"
        } )
end

function Roadtrip:ModuleUnload()
    Events:FireRegisteredEvent( "HelpRemoveItem",
        {
            name = "Roadtrip"
        })
    Events:FireRegisteredEvent( "HelpRemoveItem",
        {
            name = "Roadtrip - Leader"
        })
end

roadtrip = Roadtrip()