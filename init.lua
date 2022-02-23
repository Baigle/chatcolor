-- Techy5's colored chat CSM

local modDataStor = minetest.get_mod_storage()
local forms = {"chat", "me", "join", "leave", "irc_join", "irc_leave", "irc_nickname", "irc", "anticheat", "PM", "mention", "error", "warning", "online", "helping", "teleport_here", "teleport_there"}
local guiRow = 1 -- Which row in the GUI is selected.
local default = {"white", "orchid", "lightgreen", "salmon", "lightgreen", "salmon", "lime", "limegreen", "lightyellow", "deeppink", "springgreen", "red", "khaki", "aqua", "lightpink", "lightsalmon", "coral"}
local helpWords = {"killed me", "help me", " sad", "re mean", "please", "anyone", "hate", "feel", "stole", "need help", " admin"}
local noticeWords = {"sex", "s3x", "have s?x", "so wet", "im wet", "fucks", "re fucking", "fuck me", "fuck you", "fuck with", "sleep with", "bitch", " b?tch", "whore", "slut", "cunt", "nigg", " nig?r ", "lets fuck", "pussy", "vagin", "penis", "dick", "cock", "cum", "rape", " r?pe ", "moan", "horny", "poke", "nuts", "balls", "deep", "name is", "live at", "real name"} -- Bad words that should catch your attention if you're a moderator.
local warnedPlayers = {} -- Warnings matched exactly to an online player. A string:value map would be best.
local playerList = {} -- Initializing the player list for when raffle activates on .winner command
local silenceToggle = false -- Figure out how to get this on the modDataStor sqlite file for statefulness.
--local mename = minetest.localplayer:get_name() --minetest.setting_get("name") --minetest.get_player_name() --user:get_player_name()  -- none of these work in CSM
--local meprivs = minetest.get_player_privs(mename)
--local meprivsstr = minetest.privs_tostring(meprivs)

for i = 1,#default do -- Make sure all our defaults are in place.
	local key = "default_" .. forms[i]
	if not modDataStor:to_table().fields[key] then
        modDataStor:set_string(key,default[i]) end
end

--local function canKick() -- checks for kick privilege
--    if minetest.get_player_privs then
--        return string.match(meprivsstr, "kick") -- this doesn't work
--    else
--        return false
--    end
--end

--on_death()
--  activate deathWaypoint function -- (https://appgurueu.github.io/lua_api.html#gheader72)
--      local function deathWaypoint()
--          get death coordinates and save them
--          show death waypoint on screen
--          remove waypoint when quaternions are within 2 meters or after a long time
--end

local getLocalName = function() -- tries to get local player name for name highlighting, currently doesn't correctly match playername
            if minetest.get_server_info().protocol_version <29 then -- copied from another script
                localPlayerName = tostring(minetest.localplayer:get_name())
                return true
            end
end

local noticeWordsCheck = function(msgLower)
            --local enabled = true
            for n = 1,#noticeWords do -- go through notice words string array one at a time until it ends
                if msgLower and string.match(msgLower, tostring(noticeWords[n])) then -- if cleaned message exists and theres a matched word
                    --local badword = string.match(msgLower, noticeWords[n])
                    return true --, badwordLocationBounds
                end
            end
end

local playerMentionCheck = function(msgLower) -- we want to match our name even if they dont use capitalization
            if msgLower and localPlayerName and string.match(msgLower, localPlayerName) then
                return true --, playerNameLocationBounds playername found
            end
end
local helpWordsCheck = function(msgLower)
            --local enabled = true
            for h = 1,#helpWords do -- go through help words string array one at a time until it ends
                if msgLower and string.match(msgLower, tostring(helpWords[h])) then -- if cleaned message exists and theres a matched word
                    --local helpword = string.match(msgLower, helpWords[h])
                    return true
                end
            end
end

local chatSource = function(msgLower, msgPlain) -- Find the source type of the message
	--if string.sub(msgLower, 1, 1) == "<" then -- Normal chat messages
	--	local parts = string.split(msgLower, ">") -- Split it at the closing >
	--	return {form = "chat", name = string.sub(parts[1], 2)} -- Return the first part excluding the first character
	if string.sub(msgLower, 1, 2) == "* " then -- /me messages frog update
		local parts = string.split(msgLower, " ") -- Split the message before and after the name
	--?print("ME: " .. tostring(parts[2]))?
		return {form = "me", name = parts[2]}
    elseif string.sub(msgPlain, 1, 8) == "PM from " then
        local parts = string.split(msgPlain, ":")
        return {form = "PM", name = parts[1]}
    elseif string.match(msgPlain, " Online: ") then
        local parts = string.split(msgPlain, ": ")
        return {form = "online", name = parts[2]}
	elseif string.sub(msgLower, 1, 3) == "<= " then
		local parts = string.split(msgLower, " ") -- Split the message before and after the name
	--?print("JOIN/LEAVE: " .. tostring(parts[2]))
		return {form = "leave", name = parts[2]}
	--?end
    elseif string.sub(msgLower, 1, 3) == "=> " then -- Default Join messages
        local parts = string.split(msgLower, " ")
        return {form = "join", name = parts[2]}
    elseif string.sub(msgLower, 1, 12) == "#anticheat: " then
        local parts = string.split(msgLower, " ")
        return {form = "anticheat", name = parts[2]}
    elseif string.match(msgLower, " is requesting ") and string.match(msgLower, " teleport to ") and string.match(msgLower, " /tpy to accept") then
        if string.match(msgLower, " is requesting to teleport to you. /tpy to accept.") then
            local parts = string.split(msgLower, " ")
            return {form = "teleport_here", name = parts[1]}
        elseif string.match(msgLower, " is requesting that you teleport to them. /tpy to accept; /tpn to deny") then
            local parts = string.split(msgLower, " ")
            return {form = "teleport_there", name = parts[1]}
        end
    elseif string.sub(msgLower, 1, 1) == "<" or string.match(msgLower, 1, 4) == "@IRC" then -- IRC message format on catlandia
        if noticeWordsCheck(msgLower) then -- marks messages with possible bad actions
            local parts = string.split(msgPlain, ">")
            return {form = "warning", name = parts[1]}
        elseif playerMentionCheck(msgLower) then -- highlights messages with your name in it
            local parts = string.split(msgPlain, ">")
            return {form = "mention", name = parts[1]}
        elseif helpWordsCheck(msgLower) then
            local parts = string.split(msgPlain, ">")
            return {form = "helping", name = parts[1]}
        end
        local parts = string.split(msgLower, ">")
        return {form = "irc", name = string.sub(parts[1], 2)} -- the IRC names can have crazy characters and spaces
    elseif string.sub(msgLower, 1, 3) == "-!-" then -- bridged IRC joins and leaves, catlandia formatting
        --if string.sub(msgLower, 1, 6) == "joined" then
        if string.match(msgLower, " joined ") then
            local parts = string.split(msgLower, "> ")
            return {form = "irc_join", name = string.sub(parts[1], 2)}
        --elseif string.sub(msgLower, 1, 4) == "left" or string.sub(msgLower, 1, 4) == "quit" then
        elseif string.match(msgLower, "has left") or string.match(msgLower, "has quit") then
            local parts = string.split(msgLower, "> ")
            return {form = "irc_leave", name = string.sub(parts[1], 2)}
        elseif string.match(msgLower, " changed ") or string.match(msgLower, "known as") then
            local parts = string.split(msgLower, "> ")
            return {form = "irc_nickname", name = string.sub(parts[1], 2)} -- Baigle doubts these work if name specified
        else return {form = "error", name = "error"}
        end
    elseif string.split(msgPlain, ":") then --and silenceToggle == false then -- Normal chat messages frog edit
        --if canKick() then --and noticeWordsCheck().enabled == true then -- if they have kick privileges
            if noticeWordsCheck(msgLower) then -- marks messages with bad words
                local parts = string.split(msgPlain, ":") -- Split it at the : instead of the <
                return {form = "warning", name = parts[1]}
            elseif playerMentionCheck(msgLower) then -- highlights messages with your name in it
                local parts = string.split(msgPlain, ">")
                return {form = "mention", name = parts[1]}
            elseif helpWordsCheck(msgLower) then
                local parts = string.split(msgPlain, ":")
                return {form = "helping", name = parts[1]}
            end
        --else local parts = string.split(msgLower, ":")
        local parts = string.split(msgLower, ":")
	--?print("CHAT: " .. string.sub(parts[1], 1))
		--?return {form = "chat", name = string.sub(parts[1], 1)} -- Return the first part
        return {form = "chat", name = parts[1]} -- Return the first part
        --end
    --elseif  silenceToggle == false then return {form = "error", name = "error"}
    else return {form = "error", name = "error"}
    end
    --return false -- fail to white
end

local setColor = function(name, value)
	local str, key
	if not name or name == "" then -- Reject bad input
		minetest.display_chat_message("Invalid setting name.")
		return
	end
	if string.len(name) > 8 and string.sub(name, 1, 8) == "default_" then -- If we are setting a default colour
		if not value then -- Can't delete defaults
			minetest.display_chat_message("Cannot delete defaults!")
			return
		end
		key = name
	else -- If we are setting a player colour
		key = "player_" .. name -- Append player prefix
	end
	modDataStor:set_string(key, value) -- Set colour
	if value then str = "set" else str = "deleted" end -- Nil values indicate deletion
	minetest.display_chat_message("Color " .. str .. " sucessfully! (" .. name  .. ")")
end

local getList = function(readable) -- Return nicely sorted array of colour defenitions (if readable is true, player prefix will be excluded)
	local list = modDataStor:to_table().fields
	local arr = {}
	for key,value in pairs(list) do -- Get key and value for all pairs
		if string.sub(key, 1, 7) == "player_" then -- Exclude defaults
			if readable then key = string.sub(key, 8) end -- Isolate the player name
			arr[#arr+1] = key .. "," .. value
		end
	end
	table.sort(arr) -- Sort alphabetically.
	for i = 1,#default do -- List defaults at end
		local key = "default_" .. forms[i] -- Get default setting key
		local value = list[key] -- Get value for key
		arr[#arr+1] = key .. "," .. value
	end
	return arr -- Numerical index table in key,value format. Must be numerical index for sorting.
end

local getFormspec = function(modify, defaultText)
	if not modify then -- Fetch main screen
		local tableDef = ""
		local list = getList(true) -- Get list of players
		for i = 1,#list do -- Convert to formspec-friendly format
			local item = string.split(list[i], ",")
			tableDef = tableDef .. item[1] .. ",".. item[2] .. "," .. item[2] .. ","
		end
		tableDef = string.sub(tableDef, 1, string.len(tableDef)-1) -- Remove trailing comma
		return [[
			size[8,9, false]
			label[1,0.5;Techy5's Colored Chat]
			button[1,1;2,1;main_modify;Modify...]
			button[3,1;2,1;main_delete;Delete]
			button[5,1;2,1;main_add;Add...]
			tablecolumns[text;color;text]
			table[1,2;6,6;main_table;]] .. tableDef .. [[;]] .. tostring(guiRow) .. [[]
			button_exit[1,8;2,1;exit;Exit]
			tooltip[main_modify;Change the color for the selected element]
			tooltip[main_delete;Delete the selected element]
			tooltip[main_add;Add a color definition]
		]]
	else -- Fetch modify screen
		return [[size[8,3, false]
			field[1.3,1.3;2,1;mod_player;Player;]] .. defaultText .. [[]
			field[3.3,1.3;2,1;mod_color;HTML/hex color;]
			button[5,1;2,1;mod_set;Set]
			button[1,2;2,1;mod_back;<- Back]
		]]
	end
end


--local function warn(warnedplayer, warningtype)
--    if not canKick() then
--        minetest.display_chat_message("You need 'kick' privileges in order to warn players.")
--        return
--    else
--
--    end
--end

--minetest.register_chatcommand("warn", { -- warn a player when they break the rules
--    params = "<warnedplayer> <warningtype>",
--    description = "Warn a specified player twice before kicking so they know they broke the rules."
--    func = function()
--
--    end
--})

-- player login detection somehwere
--      one section is notification of user using PM, chat message, and stored message from user to that player using minetest.after or alternative scheduling mechanism
--      other section is artificial temp-ban using automated kicking that gives more kicks based on how many warnings the player has, using tiers

minetest.register_chatcommand("winner", {
    params = "",
    description = "Pick a winning online player from the list!",
    func = function()
        if playerList and minetest.get_connected_players then
            local playerList = minetest.get_connected_players() -- get playerlist array
            local numPlayers = #playerList -- count elements in array
            local winningPlayerIndex = math.random(1, numPlayers) -- pick random number between 1st player to last player
            -- attempt to call field get_connected_players a nil value
            local winnerPlayer = tostring(playerList[winningPlayerIndex]) -- pick player string out using index position
            message = minetest.colorize("gold", "And the Winning Player is: [" .. winnerPlayer .. "] !") -- craft message
            minetest.display_chat_message(message) -- display message in chat
        else
            winnerFuncError = minetest.colorize("red", "The winner function did not detect the existence of minetest.get_connected_players().")
            minetest.display_chat_message(winnerFuncError)
        end
    end
})

minetest.register_chatcommand("silence", {
    params = "",
    description = "Toggle all public chat messages, keeping private and local messages.",
    func = function()
        if silenceToggle then
            if silenceToggle == false then
                local silenceToggle = true
                silenceToggleMsg = minetest.colorize("blue", "The existing silence feature has been toggled ON.")
                minetest.display_chat_message(silenceToggleMsg)
            elseif silenceToggle == true then
                local silenceToggle = false
                silenceToggleMsg = minetest.colorize("blue", "The existing silence feature has been toggled OFF.")
                minetest.display_chat_message(silenceToggleMsg)
            end
        else local silenceToggle = true -- this is always called for some reason
            silenceToggleMsg = minetest.colorize("blue", "The silence feature has been toggled ON.")
            minetest.display_chat_message(silenceToggleMsg)
        end
end
})

minetest.register_chatcommand("setcolor", { -- Assign a colour to chat messages from a specific person
	params = "<name> <color>",
	description = "Colourize a specified player's chat messages.",
	func = function(param)
		local args = string.split(param, " ") -- Split up the arguments
		setColor(args[1], args[2])
	end
})

minetest.register_chatcommand("delcolor", {
	params = "<name>",
	description = "Set a specified player's chat messages to the default color.",
	func = function(param)
		setColor(param, nil) -- Setting a colour to nil deletes it.
	end
})

minetest.register_chatcommand("listcolors", {
	params = "",
	description = "List current player/color pairs.",
	func = function(param)
		local list = getList(true)
		for i = 1,#list do -- Print list to chat
			local item = string.split(list[i], ",")
			minetest.display_chat_message(item[1] .. ", ".. minetest.colorize(item[2], item[2]))
		end
	end
})

minetest.register_chatcommand("gui", {
	params = "",
	description = "Display colorchat formspec GUI.",
	func = function(param)
		guiRow = 1 -- Select first row of table
		minetest.show_formspec("chatcolor:maingui", getFormspec())
	end
})

minetest.register_on_formspec_input(function(formname, fields)
	if not string.find(formname, "chatcolor") then return end -- Avoid conflicts
	if fields.main_table then guiRow = tonumber(string.match(fields.main_table, "%d+")) end -- Get the selected table row on change.

	if fields.main_delete then
		local list = getList(true)
		local key = string.split(list[guiRow], ",")[1] -- From selected row number, find what entry is selected
		setColor(key, nil)
		minetest.show_formspec("chatcolor:maingui", getFormspec())
	elseif fields.main_modify then
		local list = getList(true)
		local key = string.split(list[guiRow], ",")[1]  -- Same as above
		minetest.show_formspec("chatcolor:modify", getFormspec(true, key)) -- Get formspec and send selected name to modify screen
	elseif fields.main_add then
		minetest.show_formspec("chatcolor:modify", getFormspec(true, ""))
	elseif fields.mod_set and fields.mod_player and fields.mod_color then
		setColor(fields.mod_player, fields.mod_color)
		minetest.show_formspec("chatcolor:maingui", getFormspec())
	elseif fields.mod_back then
		minetest.show_formspec("chatcolor:maingui", getFormspec())
	end
end)

--minetest.register_on_connect(function()
--	minetest.register_on_receiving_chat_messages(function(message)
minetest.register_on_mods_loaded(function()
	minetest.register_on_receiving_chat_message(function(message)
		local msgPlain = minetest.strip_colors(message)
        local msgLower = string.lower(msgPlain) -- lowercase for word matching
        --local msgClean = string.gsub(msgLower) -- rubenwardy said https://github.com/minetest/minetest/issues/7291#issuecomment-1042376491
        local msgTrim = string.trim(msgLower) -- msgClean) -- remove escape characters and pre-spaces
        local source = chatSource(msgLower, msgPlain)

        	--message = minetest.colorize(color, msgPlain .. " and the Winning Player is : " .. winnerPlayer .. " !")
        if source then -- Normal chat/me/join messages
            local key = "player_" .. source.name -- The setting name
			local color = modDataStor:get_string(key) -- Get the desired colour
			if color == "" then -- If no colour, set to default
				color = modDataStor:get_string("default_" .. source.form)
			end
			message = minetest.colorize(color, msgPlain)
			minetest.display_chat_message(message)
			return true -- Override the original chat
		elseif string.sub(msgPlain, 1, 2) == "# " then -- /status message
			local list = modDataStor:to_table().fields
			for key,value in pairs(list) do -- Get key and value for all pairs
				if string.sub(key, 1, 7) == "player_" then -- Exclude default settings
					key = string.sub(key, 8) -- Isolate the player name
					msgPlain = string.gsub(msgPlain, key, minetest.colorize(value, key)) -- Replace plain name with coloured version
				end
        end
			minetest.display_chat_message(msgPlain) -- if it doesn't match source or /players, just show plain message with no color
			return true -- Override the original chat
		end
	end)
end)
