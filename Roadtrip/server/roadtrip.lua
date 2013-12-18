class("Roadtrip")

ChatColours = {
	Error = Color(240,0,0),
	Info = Color(36,126,240),
	Waypoint = Color(66,255,66),
	Leader = Color(255,66,230),
	JoinLeave = Color(255,183,66)
}

function Roadtrip:__init()
	self.roadtripMembers = {}
	self.roadtripLeader = nil
	self.waypointLocation = nil
	self.kickVotes = {}
	self.bans = {}
	self.atWaypointTimer = Timer()
	self.membersInChat = {}

	Events:Register("AuthedCommand")
	Events:Subscribe("AuthedCommand", self, self.Command)
	Events:Subscribe("PlayerSpawn", self, self.PlayerSpawn)
	Events:Subscribe("PostTick", self, self.Tick)
    Events:Subscribe( "PlayerChat", self, self.PlayerChat)
	Network:Subscribe("RoadtripSetWaypoint", self, self.PlayerSetWaypoint)
end

function Roadtrip:PlayerChat(args)
	if (args.text:sub(1, 1) == '/') then
		return true
	end
	if IsValid(args.player) and self:IsMember(args.player) and self:IsInChat(args.player) then
		for i, player in ipairs(self.roadtripMembers) do
			Network:Send(Player.GetById(player), "RoadtripChatMessage", {args.player:GetName(), args.text})
		end
	end
	return true
end


function Roadtrip:Tick(args)
	if #self.roadtripMembers > 0 then
		if self.waypointLocation and self.atWaypointTimer:GetSeconds() > 4 then
			local playersAtWaypoint = 0
			for i, player in ipairs(self.roadtripMembers) do
				if IsValid(player) and self:PlayerDistanceFromWaypoint(Player.GetById(player)) <= 150 then
					playersAtWaypoint = playersAtWaypoint + 1
		 		end
			end
			for i, player in ipairs(self.roadtripMembers) do
				if IsValid(Player.GetById(player)) then
					Network:Send(Player.GetById(player), "AtWaypointUpdate", {playersAtWaypoint, self.roadtripMembers})
				else
					self.roadtripMembers[i] = nil
				end
			end
			self.atWaypointTimer:Restart()
		elseif not self.waypointLocation then
			for i, player in ipairs(self.roadtripMembers) do
				if IsValid(Player.GetById(player)) then
					Network:Send(Player.GetById(player), "AtWaypointUpdate", {})
				else
					self.roadtripMembers[i] = nil
				end
			end
		end
	end
end

function Roadtrip:Command(cmd)
	if cmd.name == "roadtrip" or cmd.name == "rt" then
		if not cmd.args[1] then
			if self:IsMember(cmd.player) then
				self:RemovePlayer(cmd.player, 'Player left with command')
			else
				self:AddPlayer(cmd.player)
			end
			return
		elseif not self:IsMember(cmd.player) then
			SendChatMessage(cmd.player, 'You are not a member of the roadtrip, do /roadtrip (or /rt) to join!', ChatColours.Error)
		elseif (cmd.args[1] == 'waypoint' or cmd.args[1] == 'wp') and self:IsPlayerLeader(cmd.player) then
			self:GetLeaderWaypoint()
		elseif cmd.args[1] == 'chat' then
			if self:IsInChat(cmd.player) then
				self:LeaveChat(cmd.player)
			else
				self:EnterChat(cmd.player)
			end
		elseif cmd.args[1] == 'resign' and self:IsPlayerLeader(cmd.player) then
			self:ReassignLeader()
		elseif cmd.args[1] == 'kick' and self:IsPlayerLeader(cmd.player) then
			if not cmd.args[2] then
				SendChatMessage(cmd.player, 'Usage: /roadtrip kick <player name>', ChatColours.Error)
			else
				if not Player.Match(cmd.args[2])[1] then
					SendChatMessage(cmd.player, 'Could not find that player!', ChatColours.Error)	
				elseif not self:IsMember(Player.Match(cmd.args[2])[1]) then
					SendChatMessage(cmd.player, newLeader:GetName()..' is not part of the roadtrip!', ChatColours.Error)
				else	
					self:RemovePlayer(Player.Match(cmd.args[2])[1], 'Kicked')
				end
			end
		elseif cmd.args[1] == 'ban' and self:IsPlayerLeader(cmd.player) then
			if not cmd.args[2] then
				SendChatMessage(cmd.player, 'Usage: /roadtrip ban <player name>', ChatColours.Error)
			else
				if not Player.Match(cmd.args[2])[1] then
					SendChatMessage(cmd.player, 'Could not find that player!', ChatColours.Error)	
				elseif not self:IsMember(Player.Match(cmd.args[2])[1]) then
					SendChatMessage(cmd.player, newLeader:GetName()..' is not part of the roadtrip!', ChatColours.Error)
				else	
					self:RemovePlayer(Player.Match(cmd.args[2])[1], 'Banned')
					table.insert(self.bans, (Player.Match(cmd.args[2])[1]):GetSteamId())
				end
			end
		elseif cmd.args[1] == 'votekick' then
			if not cmd.args[2] then
				SendChatMessage(cmd.player, 'Usage: /roadtrip votekick <player name>', ChatColours.Error)
			else
				if not Player.Match(cmd.args[2])[1] then
					SendChatMessage(cmd.player, 'Could not find that player!', ChatColours.Error)	
				elseif not self:IsMember(Player.Match(cmd.args[2])[1]) then
					SendChatMessage(cmd.player, newLeader:GetName()..' is not part of the roadtrip!', ChatColours.Error)
				else	
					local kickingPlayer = Player.Match(cmd.args[2])[1]:GetId()
					if not self.kickVotes[kickingPlayer] then
						self.kickVotes[kickingPlayer] = {}
					end

					local hasVoted = false
                    for _, value in pairs(self.kickVotes[kickingPlayer]) do
                        if value == cmd.player:GetId() then
                            hasVoted = true
                        end
                    end
                    
                    if hasVoted == false then 
                        table.insert(self.kickVotes[kickingPlayer], cmd.player:GetId())
						local voteCount = #self.kickVotes[kickingPlayer]
						SendChatMessage(cmd.player, Player.Match(cmd.args[2])[1]:GetName()..' now has '..voteCount..' vote(s) against him.')
						print((#self.roadtripMembers)/2)
						local voteThreshold = math.floor(((#self.roadtripMembers)/2)*((#self.roadtripMembers)^0.25)+0.5)
						if voteCount > voteThreshold then
							self:RemovePlayer(Player.Match(cmd.args[2])[1], 'Vote Kicked')
	                        self.kickVotes[kickingPlayer] = nil
						end
                    else
                        SendChatMessage(cmd.player, 'You have already voted to kick that person.', ChatColours.Error) 
                    end
				end
			end
		elseif cmd.args[1] == 'transfer' and self:IsPlayerLeader(cmd.player) then
			if not cmd.args[2] then
				SendChatMessage(cmd.player, 'Usage: /roadtrip transfer <player name>', ChatColours.Error)
			else
				local newLeader = Player.Match(cmd.args[2])[1]
				if not newLeader then
					SendChatMessage(cmd.player, 'Could not find that player!', ChatColours.Error)					
				elseif self:IsMember(newLeader) then
					if newLeader:GetId() == self.roadtripLeader then
						SendChatMessage(cmd.player, 'You are already the leader!', ChatColours.Error)						
					else
						self:SetLeader(newLeader)
					end
				else
					SendChatMessage(cmd.player, newLeader:GetName()..' is not part of the roadtrip!', ChatColours.Error)
				end
			end
		elseif (cmd.args[1] == 'goto' or cmd.args[1] == 'tp') then
			if not cmd.args[2] then
				SendChatMessage(cmd.player, 'Usage: /roadtrip goto <player name>', ChatColours.Error)
			else
				if not Player.Match(cmd.args[2])[1] then
					SendChatMessage(cmd.player, 'Could not find that player!', ChatColours.Error)	
				elseif not self:IsMember(Player.Match(cmd.args[2])[1]) then
					SendChatMessage(cmd.player, (Player.Match(cmd.args[2])[1]):GetName()..' is not part of the roadtrip!', ChatColours.Error)
				else
					self:TeleportPlayerToPlayer(cmd.player, Player.Match(cmd.args[2])[1])
				end
			end
		elseif (cmd.args[1] == 'gotowp' or cmd.args[1] == 'tpwp' or cmd.args[1] == 'gotowaypoint' or cmd.args[1] == 'tpwaypoint') then
			if self.waypointLocation then
				local vector = self.waypointLocation
				vector.y = vector.y + 2
				vector.x = vector.x + 8
				self:TeleportPlayer(cmd.player, vector)
				SendChatMessage(cmd.player, 'Teleported you to the waypoint.')
			else
				SendChatMessage(cmd.player, 'The leader, '..(self:GetLeader()):GetName()..', has not set a waypoint.', ChatColours.Error)
			end
		elseif cmd.args[1] == 'list' then
			self:PlayerList(cmd.player)
		elseif cmd.args[1] == 'help' then
			SendChatMessage(cmd.player, 'Use F5 for roadtrip help.')
		end
	end
end

function Roadtrip:LeaveChat(player)
	local playerId = player:GetId()
	for i, id in ipairs(self.membersInChat) do
		if id == playerId then
			table.remove(self.membersInChat, i)
			break
		end
	end
	Network:Send(player, "RoadtripChatToggle", false)
end

function Roadtrip:EnterChat(player)
	local playerId = player:GetId()
	table.insert(self.membersInChat, playerId)
	Network:Send(player, "RoadtripChatToggle", true)
end

function Roadtrip:IsInChat(player)
	for i, _player in ipairs(self.membersInChat) do
		if _player == player:GetId() then
			return true
		end
	end
	return false
end

function Roadtrip:IsMember(player)
	local playerId = player:GetId()
	for i, id in ipairs(self.roadtripMembers) do
		if id == playerId then
			return true
		end
	end
	return false
end

function Roadtrip:RemovePlayer(player, reason)
	reason = reason or 'Unkown reason'
	self:BroadcastChatMessageToMembers(player:GetName()..' is leaving the roadtrip! (Reason: '..reason..')', ChatColours.JoinLeave)

	local playerId = player:GetId()
	self:LeaveChat(player)
	for i, id in ipairs(self.roadtripMembers) do
		if id == playerId then
			table.remove(self.roadtripMembers, i)
			break
		end
	end
	if playerId == self.roadtripLeader then
		self:ReassignLeader()
	end

	Network:Send(player, "AtWaypointUpdate", {})
	SendChatMessage(player, 'You have left the roadtrip.')
end

function Roadtrip:AddPlayer(player)
	if IsValid(player) then
		for i, steamid in ipairs(self.bans) do
			if steamid == player:GetSteamId() then
				SendChatMessage(player, 'You are banned from the roadtrip until a new leader joins.', ChatColours.Error)
				return
			end
		end
		self:BroadcastChatMessageToMembers(player:GetName()..' is joining the roadtrip!', ChatColours.JoinLeave)
		table.insert(self.roadtripMembers, player:GetId())
		SendChatMessage(player, 'Welcome to the roadtrip, '..player:GetName()..'!', ChatColours.JoinLeave)

		if #self.roadtripMembers == 1 then
			self:SetLeader(player)
		end
	end
end

function Roadtrip:GetLeaderWaypoint()
	Network:Send(self:GetLeader(), "RoadtripGetWaypoint")
end

function Roadtrip:PlayerSetWaypoint(obj)
	if Player.GetById(obj[1]) ==  self:GetLeader() then
		if obj[2] then
			self.waypointLocation = obj[2]
			self:BroadcastWaypoint()
			self:BroadcastChatMessageToMembers(Player.GetById(obj[1]):GetName()..' has a set a new waypoint!', ChatColours.Waypoint)
		else
			SendChatMessage(self:GetLeader(), 'Set a waypoint in you map first! (F1)', ChatColours.Error)
		end
	end
end

function Roadtrip:PlayerDistanceFromWaypoint(player)
	if self.waypointLocation then
		return Vector3.Distance(player:GetPosition(), self.waypointLocation)
	end
end

function FormatDistance(distance)
	if distance < 1000 then
		return string.format('%i', distance) .. 'm'
	else
		return string.format('%.2f', distance/1000) .. 'km'
	end
end

function Roadtrip:PlayerList(requestingPlayer)
	local responseLines = {'Roadtrip members ('..#self.roadtripMembers..'):'}
	local function insertPlayer(player, isLeader)
		local leaderString = ''
		if isLeader then
			leaderString = 'Leader: '
		end
		local distanceString = ''
		local distance = self:PlayerDistanceFromWaypoint(player)
		if distance then
			distanceString = ' (at waypoint)'
			if distance > 150 then
				distanceString =  ' (' .. FormatDistance(distance) .. ' from wp)'
			end
		end

		return '   ' .. leaderString .. player:GetName() .. distanceString
	end

	table.insert(responseLines, insertPlayer(self:GetLeader(), true))
	local line = ''
	for i, player in ipairs(self.roadtripMembers) do
		if IsValid(player) and player ~= self.roadtripLeader then
			line = line .. insertPlayer(Player.GetById(player)) .. ', '
			if i%3 == 0 then
				table.insert(responseLines, line)
				line = ''
			end
		end
	end
	if line ~= '' then
		table.insert(responseLines, line)
	end

	SendChatMessages(requestingPlayer, responseLines)
end

function Roadtrip:BroadcastWaypoint()
	for i, id in ipairs(self.roadtripMembers) do
		self:SendWaypoint(Player.GetById(id))
	end
end

function Roadtrip:SendWaypoint(player)
	Network:Send(player, "RoadtripBroadcastWaypoint", self.waypointLocation)
end

function Roadtrip:PlayerSpawn(args)
	if self:IsMember(args.player) then
		self:SendWaypoint(args.player)
	end
end

function Roadtrip:PlayerLeave(player)
	self:RemovePlayer(player, 'Disconnected')
end

function Roadtrip:ReassignLeader()
	if #self.roadtripMembers > 0 then
		local oldLeader = self.roadtripLeader
		for i, player in ipairs(self.roadtripMembers) do
			if player ~= self.roadtripLeader then
				self:SetLeader(Player.GetById(player))
			end
		end
		if oldLeader == self.roadtripLeader then
			SendChatMessage(self:GetLeader(), 'You can\'t resign, you\'re the last member. Use /roadtrip to leave.', ChatColours.Error)
		else
			for i,v in ipairs(self.bans) do
				self.bans[i] = nil
			end
			self:BroadcastChatMessageToMembers('Bans have been reset.')
		end
	else
		self.roadtripLeader = nil
		for i,v in ipairs(self.bans) do
			self.bans[i] = nil
		end
		print('Reset bans')
	end
end

function Roadtrip:TeleportPlayer(player, destination)
	if destination then
		player:Teleport(destination, Angle())
	end
end

function Roadtrip:TeleportPlayerToPlayer(player, destinationPlayer)
	local vector = destinationPlayer:GetPosition()
	vector.y = vector.y + 2
	vector.x = vector.x + 2
	self:TeleportPlayer(player, vector)
end

function Roadtrip:SetLeader(player)
	if player ~= self:GetLeader() then
		SendChatMessage(player, 'You are now the roadtrip leader, view leader commands with F5.', ChatColours.Leader)
		self.roadtripLeader = player:GetId()

		local leaderName = player:GetName()
		for i, _player in ipairs(self.roadtripMembers) do
			if _player ~= self.roadtripLeader then
				SendChatMessage(Player.GetById(_player), player:GetName()..' is now the roadtrip leader!', ChatColours.Leader)
			end
		end

		if not self.waypointLocation then
			SendChatMessage(player, 'There is no waypoint, set one using /roadtrip waypoint (or /rt wp)', ChatColours.Leader)
		end
	end
end

function Roadtrip:GetLeader()
	if self.roadtripLeader then
		return Player.GetById(self.roadtripLeader)
	else
		return nil
	end
end

function Roadtrip:IsPlayerLeader(player)
	if player == self:GetLeader() then
		return true
	else
		SendChatMessage(player, 'You are not the leader. Ask the leader, '..(self:GetLeader()):GetName()..', to do that instead.', ChatColours.Error)
		SendChatMessage(player, 'If you don\'t belive that '..(self:GetLeader()):GetName()..' should be the leader, do /roadtrip votekick '..(self:GetLeader()):GetName(), ChatColours.Leader)
		return false
	end
end

function Roadtrip:BroadcastChatMessageToMembers(message, colour)
	for i, id in ipairs(self.roadtripMembers) do
		SendChatMessage(Player.GetById(id), message, colour)
	end
end

function SendChatMessage(player, message, colour)
	colour = colour or ChatColours.Info
	player:SendChatMessage(message, colour)
end

function SendChatMessages(player, messages)
	for i, message in ipairs(messages) do
		SendChatMessage(player, message)
	end
end

roadtrip = Roadtrip()