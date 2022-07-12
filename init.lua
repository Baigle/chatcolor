-- Techy5's colored chat CSM

local modname = tostring(assert(core.get_current_modname(), "core.get_current_modname returned false or nil value type.")) -- From the clientmods examples file, used to test assert()
local modprepend = "["..modname.."] "
local sqlite = core.get_mod_storage() -- Loves to get corrupted!
local show_msg = core.display_chat_message -- Shorthand assignment.
local guiRow = 1 -- Which row in the GUI is selected.
local categoryColorMap = {chat = "white", me = "orchid", self = "slateblue", join = "lightgreen", leave = "salmon", irc_join = "lightgreen", irc_leave = "salmon", irc_nickname = "lime", irc = "limegreen", anticheat = "lightyellow", PM = "deeppink", mention = "springgreen", error = "red", warning = "khaki", spam = "darkkhaki", online = "aqua", helping = "lightpink", teleport_here = "lightsalmon", teleport_there = "coral", admin = "peachpuff"}
local helpWords = {"killed me", "help me", " sad", "re mean", "please", "anyone", "hate", " feel", "stole", "need help", " admin", "staff"}
local noticeWords = {"sex", "polvo", "s3x", "sxy", "have s?x", "porn", "s do it", "so wet", "im wet", "fucks", "re fucking", "fuck me", "fuck you", "fuck with", "sleep with", "hook up", " bf", " gf", "boyfriend", "girlfriend", " pregn", "birth", "love", " luv", " bitch", " b?tch", "whore", "puta", "slut", "cunt", " cono", "nigg", " nig?r ", " negr?", "lets fuck", "pussy", "vagin", "penis", "dick", "cock", "polla", " pija", "cum", " rape", "kill you", "shoot", " r?pe ", "moan", "horny", " poke", "nuts", " balls", "testic", "deep", "name is", "live at", "real name"} -- Bad words that should catch your attention if you're a moderator.
local warnedPlayerDB = {} -- Warnings matched exactly to a player. A string:value mapping would be best.
local warningScores = {sex = 6, race = 8, name = 5, spam = 6, agro = 4, grief = 5, hack = 4, date = 2, info = 4} -- Warning types with weighted scores out of 12.
PlayerList = {} -- Initializing the globally accessible player list for when raffle activates on .winner command
LocalPlayerName = "prototype_global_initialization"
LocalPlayerPos = "prototype_global_initialization"
LocalPlayerPrivsStr = "prototype_global_initialization"


--local function canKick() -- checks for kick privilege
--    if core.get_player_privs then
--		  local localPlayerPrivs =  core.get_player_privs()
--		  for priv = 1, #localPlayerPrivs do
--        	 return string.match(localPlayerPrivs[priv], "^kick") -- this doesn't work?
--    else
-- 		  local canKick_error_msg = core.colorize("red", "canKick did not detect the presence of core.get_player_privs.")
--        show_msg(canKick_error_msg)
--        return false
--    end
--end

--core.localplayer.on_death()
--  activate deathWaypoint function -- (https://appgurueu.github.io/lua_api.html#gheader72)
--      local function deathWaypoint()
--          get death coordinates and save them
--          show death waypoint on screen
--          remove waypoint when vector/math.distance quaternions are within 2 meters or after a long time
--end

local noticeWordsCheck = function(msg_lowercase)
            --local enabled = true
            for n = 1,#noticeWords do -- go through notice words string array one at a time until it ends
                if msg_lowercase and string.match(msg_lowercase, tostring(noticeWords[n])) then -- if cleaned message exists and theres a matched word
                    --local badword = string.match(msg_lowercase, noticeWords[n])
                    return true --, badwordLocationBounds
                end
            end
end

--[[Msg_Letter_Array = {}
Last_Letter = {}
local spamCheck = function(msg_lowercase) -- Only checks chat messages for lots of repeating characters
	if (string.len(msg_lowercase) > 11) then
		local msg_lowercase_split = string.split(msg_lowercase, ":", false, 1)
		msg_lowercase = tostring(msg_lowercase_split[2])
		Msg_Letter_Array = string.split(msg_lowercase, ".")
		Last_Letter = {}
		for index =  1,#Msg_Letter_Array do
			if Msg_Letter_Array[index] == Last_Letter then
				table.remove(Msg_Letter_Array, index)
			else
				Last_Letter = Msg_Letter_Array[index]
			end
		end
		local msg_repeats_removed = tostring(Msg_Letter_Array)
		if ((#msg_lowercase / #msg_repeats_removed) > 3) then
			return true
		else
			return false
		end
	end
	return false
end--]]

local playerMentionCheck = function(msg_lowercase)
            if msg_lowercase and LocalPlayerName and string.match(msg_lowercase, LocalPlayerName) then
                return true --, playerNameLocationBounds -- The message did have the playername in it.
            end
end
local helpWordsCheck = function(msg_lowercase)
            --local enabled = true
            for h = 1,#helpWords do -- go through help words string array one at a time until it ends
                if msg_lowercase and string.match(msg_lowercase, tostring(helpWords[h])) then -- if cleaned message exists and theres a matched word
                    --local helpword = string.match(msg_lowercase, helpWords[h])
                    return true
                end
            end
end

local chatSource = function(msg_no_color, msg_lowercase) -- Find the category type of the message and extract sender's name
	--if string.sub(msg_lowercase, 1, 1) == "<" then -- Normal chat messages
	--	local parts = string.split(msg_lowercase, ">") -- Split it at the closing >
	--	return {category = "chat", name = string.sub(parts[1], 2)} -- Return the first part excluding the first character
	if (string.sub(msg_no_color, 1, #LocalPlayerName) == LocalPlayerName) then
		local parts = string.split(msg_no_color, ":")
		return {category = "self", name = parts[1]}
	elseif string.sub(msg_lowercase, 1, 2) == "* " then -- /me messages frog update
		local parts = string.split(msg_lowercase, " ") -- Split the message before and after the name
		return {category = "me", name = parts[2]}
    elseif string.sub(msg_no_color, 1, 8) == "PM from " then
        local parts = string.split(msg_no_color, ":")
        return {category = "PM", name = parts[1]}
    elseif string.match(msg_no_color, "%d Online: ") then
        local parts = string.split(msg_no_color, ": ")
        return {category = "online", name = parts[2]}
	elseif string.sub(msg_lowercase, 1, 3) == "<= " then
		local parts = string.split(msg_lowercase, " ") -- Split the message before and after the name
		return {category = "leave", name = parts[2]}
    elseif string.sub(msg_lowercase, 1, 3) == "=> " then -- Default Join messages
        local parts = string.split(msg_lowercase, " ")
        return {category = "join", name = parts[2]}
    elseif string.sub(msg_lowercase, 1, 12) == "#anticheat: " then
        local parts = string.split(msg_lowercase, " ")
        return {category = "anticheat", name = parts[2]}
    elseif string.match(msg_lowercase, " is requesting ") and string.match(msg_lowercase, " teleport to ") and string.match(msg_lowercase, " /tpy to accept") then
        if string.match(msg_lowercase, " is requesting to teleport to you. /tpy to accept") then
            local parts = string.split(msg_lowercase, " ")
            return {category = "teleport_here", name = parts[1]}
        elseif string.match(msg_lowercase, " is requesting that you teleport to them. /tpy to accept; /tpn to deny") then
            local parts = string.split(msg_lowercase, " ")
            return {category = "teleport_there", name = parts[1]}
		else return {category = "error", name = "error"}
        end
    elseif string.sub(msg_lowercase, 1, 1) == "<" or string.match(msg_lowercase, 1, 4) == "@IRC" then -- IRC message format on catlandia
        if noticeWordsCheck(msg_lowercase) then -- marks messages with possible bad actions
            local parts = string.split(msg_no_color, ">")
            return {category = "warning", name = parts[1]}
		--elseif spamCheck(msg_lowercase) then
		--	local parts = string.split(msg_no_color, ">")
		--	return {category = "spam", name = parts[1]}
        elseif playerMentionCheck(msg_lowercase) then -- highlights messages with your name in it
            local parts = string.split(msg_no_color, ">")
            return {category = "mention", name = parts[1]}
        elseif helpWordsCheck(msg_lowercase) then
            local parts = string.split(msg_no_color, ">")
            return {category = "helping", name = parts[1]}
        end
        local parts = string.split(msg_lowercase, ">")
        return {category = "irc", name = string.sub(parts[1], 2)} -- the IRC names can have crazy characters and spaces
    elseif string.sub(msg_lowercase, 1, 3) == "-!-" then -- bridged IRC joins and leaves, catlandia formatting
        --if string.sub(msg_lowercase, 1, 6) == "joined" then
        if string.match(msg_lowercase, " joined ") then
            local parts = string.split(msg_lowercase, "> ")
            return {category = "irc_join", name = string.sub(parts[1], 2)}
        --elseif string.sub(msg_lowercase, 1, 4) == "left" or string.sub(msg_lowercase, 1, 4) == "quit" then
        elseif string.match(msg_lowercase, " has left") or string.match(msg_lowercase, " has quit") then
            local parts = string.split(msg_lowercase, "> ")
            return {category = "irc_leave", name = string.sub(parts[1], 2)}
        elseif string.match(msg_lowercase, " changed ") or string.match(msg_lowercase, " known as ") then
            local parts = string.split(msg_lowercase, "> ")
            return {category = "irc_nickname", name = string.sub(parts[1], 2)} -- Baigle doubts these work if name specified
        else return {category = "error", name = "error"}
        end
	elseif (string.sub(msg_no_color, 1, 1) == "[") then -- Either detect admins and mods by looking up their privileges or checking for things like [A]
		local parts = string.split(msg_no_color, ":")
		if string.split(parts[1], " ") then
			local nameparts = string.split(parts[1], " ")
			return {category = "admin", name = nameparts[#nameparts]} -- Last element in nameparts, closest to the : should be their name
		else
			local nameparts = string.split(parts[1], "]")
			return {category = "admin", name = nameparts[#nameparts]}
		end
    elseif string.split(msg_no_color, ":") then -- Normal chat messages frog edit
        --if canKick() then --and noticeWordsCheck().enabled == true then -- if they have kick privileges
            if noticeWordsCheck(msg_lowercase) then -- marks messages with bad words
                local parts = string.split(msg_no_color, ":") -- Split it at the : instead of the <
                return {category = "warning", name = parts[1]}
			--elseif spamCheck(msg_lowercase) then
			--	local parts = string.split(msg_no_color, ":")
			--	return {category = "spam", name = parts[1]}
            elseif playerMentionCheck(msg_lowercase) then -- highlights messages with your name in it
                local parts = string.split(msg_no_color, ":")
                return {category = "mention", name = parts[1]}
            elseif helpWordsCheck(msg_lowercase) then
                local parts = string.split(msg_no_color, ":")
                return {category = "helping", name = parts[1]}
            end
		--end
        local parts = string.split(msg_no_color, ":")
        return {category = "chat", name = parts[1]} -- Return the first part
    else return {category = "error", name = "error"} -- Fail to category error with name error and color red in a couple places
    end
end

local setColor = function(player_name, color_value)
	local set_or_del, player_listing -- Initialize these variables for use
	if not player_name or player_name == "" then -- Reject bad input
		local setColor_error = core.colorize("red", "Invalid player name.")
		show_msg(setColor_error)
		return
	end
	if string.len(player_name) > 9 and string.sub(player_name, 1, 9) == "default_" then -- If we are setting a default colour
		if not color_value then -- Can't delete defaults
			local setColor_error = core.colorize("red", "Cannot delete hardcoded defaults.")
			show_msg(setColor_error)
			return
		end
		player_listing = player_name
	else -- If we are setting a player colour
		player_listing = "player_"..player_name -- Append player prefix
	end
	sqlite:set_string(player_listing, color_value) -- Set colour
	if color_value then set_or_del = "set" else set_or_del = "deleted" end -- Nil values indicate deletion
	local setColor_success = core.colorize("dodgerblue", "Color for "..player_name.." "..set_or_del.." sucessfully!")
	show_msg(setColor_success)
end

local getList = function(remove_listing_prefix) -- Return nicely sorted array of configured colours (if readable is true, player prefix will be excluded)
	local retreived_list = sqlite:to_table().fields
	local playerListingArray = {}
	for player_listing,color_value in pairs(retreived_list) do -- Get key and value for all pairs
		if string.sub(player_listing, 1, 7) == "player_" then -- Exclude defaults
			if remove_listing_prefix then player_listing = string.sub(player_listing, 8) end -- Isolate the player name
			playerListingArray[#playerListingArray+1] = player_listing..","..color_value
		end
	end
	table.sort(playerListingArray) -- Sort configured players alphabetically.
	for i = 1,#categoryColorMap do -- List defaults at end
		-- local key = "default_"..categories[i] -- Get default setting key
		local dflt_listing = "default_"..categoryColorMap[i]
		local color_value = retreived_list[dflt_listing] -- Get value for key
		playerListingArray[#playerListingArray+1] = dflt_listing..","..color_value
	end
	return playerListingArray -- Numerical index table in key,value format. Must be numerical index for sorting.
end

local getFormspec = function(modify, defaultText)
	if not modify then -- Fetch main screen
		local tableDef = ""
		local list = getList(true) -- Get list of players
		for i = 1,#list do -- Convert to formspec-friendly format
			local item = string.split(list[i], ",")
			tableDef = tableDef..item[1]..",".. item[2]..","..item[2]..","
		end
		tableDef = string.sub(tableDef, 1, string.len(tableDef)-1) -- Remove trailing comma
		return [[
			size[8,9, false]
			label[1,0.5;Techy5's Colored Chat]
			button[1,1;2,1;main_modify;Modify...]
			button[3,1;2,1;main_delete;Delete]
			button[5,1;2,1;main_add;Add...]
			tablecolumns[text;color;text]
			table[1,2;6,6;main_table;]]..tableDef..[[;]]..tostring(guiRow)..[[]
			button_exit[1,8;2,1;exit;Exit]
			tooltip[main_modify;Change the color for the selected element]
			tooltip[main_delete;Delete the selected element]
			tooltip[main_add;Add a color definition]
		]]
	else -- Fetch modify screen
		return [[size[8,3, false]
			field[1.3,1.3;2,1;mod_player;Player;]]..defaultText..[[]
			field[3.3,1.3;2,1;mod_color;HTML/hex color;]
			button[5,1;2,1;mod_set;Set]
			button[1,2;2,1;mod_back;<- Back]
		]]
	end
end

-- player login detection somehwere
--      one section is notification of user using PM, chat message, and stored message from user to that player using core.after or alternative scheduling mechanism
--      other section is artificial temp-ban using automated kicking that gives more kicks based on how many warnings the player has, using tiers

core.register_chatcommand("winner", {
    params = "",
    description = modprepend.."Pick a winning online player from the list!",
    func = function()
        if PlayerList and core.get_connected_players then -- if the array and function exist
			if #core.get_connected_players() > 0 then
				PlayerList = core.get_connected_players() -- get playerlist array and make sure its not nil value type
            	local numPlayers = #PlayerList -- count elements in array
            	local winningPlayerIndex = math.random(1, numPlayers) -- pick random number between 1st player to last player
				local winnerPlayer = tostring(PlayerList[winningPlayerIndex]) -- pick player string out using index position
				local winning_message = core.colorize("gold", "And the Winning Player is: ["..winnerPlayer.."] !") -- craft message
            	show_msg(winning_message) -- display message in chat
			else
				local winner_func_error = core.colorize("red", "The winner function could not count core.get_connected_players().")
				show_msg(winner_func_error)
			end
		else
            local winner_func_error = core.colorize("red", "The winner function did not detect the existence of core.get_connected_players().")
            show_msg(winner_func_error)
        end
    end
})

Silence_Toggle = "OFF" -- Find a way to share these globals within certain ranges, not just local to a block or global to every script, or change coding style, like functional programming.
core.register_chatcommand("silence", {
    params = "",
    description = modprepend.."Hide all public chat messages.",
    func = function()
        if Silence_Toggle then
			--local silence_status_msg = core.colorize("dodgerblue", "Current Silence_Toggle status is "..Silence_Toggle)
			--show_msg(silence_status_msg)
            if Silence_Toggle == "OFF" then
                Silence_Toggle = "ON"
                local silence_toggle_msg = core.colorize("dodgerblue", "The existing silence feature has been toggled ON.")
                show_msg(silence_toggle_msg)
				return true
            elseif Silence_Toggle == "ON" then
                Silence_Toggle = "OFF"
                local silence_toggle_msg = core.colorize("dodgerblue", "The existing silence feature has been toggled OFF.")
                show_msg(silence_toggle_msg)
				return true
            end
        else
			Silence_Toggle = "ON"
            local silence_toggle_msg = core.colorize("dodgerblue", "The silence feature has been created and toggled ON.")
            show_msg(silence_toggle_msg)
			return true
        end
	end
})

Debug_Toggle = "OFF"
core.register_chatcommand("debug", {
    params = "",
    description = modprepend.."Show message source categories before all messages.",
    func = function()
        if Debug_Toggle then
			--local debug_status_msg = core.colorize("dodgerblue", "Current Debug_Toggle status is "..Debug_Toggle)
			--show_msg(debug_status_msg)
            if Debug_Toggle == "OFF" then
                Debug_Toggle = "ON"
                local debug_toggle_msg = core.colorize("dodgerblue", "The existing debug feature has been toggled ON.")
                show_msg(debug_toggle_msg)
				return true
            elseif Debug_Toggle == "ON" then
                Debug_Toggle = "OFF"
                local debug_toggle_msg = core.colorize("dodgerblue", "The existing debug feature has been toggled OFF.")
                show_msg(debug_toggle_msg)
				return true
            end
        else
			Debug_Toggle = "ON"
            local debug_toggle_msg = core.colorize("dodgerblue", "The debug feature has been created and toggled ON.")
            show_msg(debug_toggle_msg)
			return true
        end
	end
})

core.register_chatcommand("test", {
	params = "<func()/tbl.a/var>",
	description = modprepend.."See the returned data from a function, array, or variable.",
	func = function(args)
		local split = string.split(args, " ")
		local object = split[1]
		if #split > 1 then
			show_msg("Only enter one argument with no spaces.")
			return false
		elseif #args < 1 then
			show_msg("Give me more to work with.")
			return false
		elseif (tonumber(args) ~= nil) then
			show_msg("A number is not something you can run or assign, tmk.")
			return false
		elseif string.match(args, "%(") and string.match(args, "%)") and not string.match(args, "%.") then -- Function
				local fname = string.split(object, "(")[1] -- Everything before the (
				local fargs = string.sub(fname[2], 1, (#fname[2] - 1)) -- Everything after the ( and before the )
				if (type(fname) == 'function') then
					local returned = tostring(fname(fargs))
					show_msg("Function returned: "..returned)
					return true
				else
					show_msg("That function doesn't exist or isn't a function.")
					return false
				end
		elseif (string.match(args, "%.")) then -- Array/Table
				if (object ~= nil) and (type(object) == 'table') then
					local contains_type = type(object)
					local contains = tostring(object)
					show_msg("Table contains: "..contains_type.."-"..contains)
					return true
				else
					show_msg("That table doesn't exist or isn't a table.")
					return false
				end
		elseif (string.len(args) > 0) then
				if (object ~= nil) and (type(object) == 'variable') then
					local contents_type = type(object)
					local contents = tostring(object)
					show_msg("Variable contents are: "..contents_type.."-"..contents)
					return true
				else
					show_msg("That variable doesn't exist or isn't a variable.")
					return false
				end
		else
			show_msg("Did not match a func(), array.stringindex.sub, or variable_name.")
			return false
		end
		show_msg("Arguments weren't too big or small, and didn't match to anything.")
		return false
	end
})

core.register_chatcommand("warn", {
    params = "<warnedplayer> <warningtype>",
    description = modprepend.."Warn a specified player before kicking so they know they broke the rules.",
	func = function(args)
		show_msg("This .warn function isn't set up yet.")
		return false
		end})
		--[[
		--if not canKick() then
        	--show_msg("[CnKck]You need 'kick' privileges in order to warn players.")
		--end
		local args = string.split(args, " ") -- Split up command arguments
		local warnee = args[1] -- Send the first argument to the playername
		for a in 2,#args do -- Go through 2nd and later arguments checking all for explicit validity
			if (args[a] == "sex" or "race" or "spam" or "agro" or "grief" or "hack" or "date" or "info") then -- Correct matches
			else
				local warn_error = core.colorize("red", "One of your offense type arguments was spelled incorrectly.")
				show_msg("[WrnErr]"..warn_error)
				return false
			end
		end
		local warningTypesTally = {} -- Set to blank array for tallying
		for a in 2,#args do -- Go through each one again, this time taking their variables into a map
			local warningTypesTally = warningTypesTally..","..args[a] -- Add current match to tally
		end
		-- count how many warnings of each type there were
		-- get each type's points and multiply that by the count to get score
		-- save the score into the warnee.warningtypes either iteratively or mapkey value arrays
	end
})--]]

core.register_chatcommand("setcolor", { -- Assign a colour to chat messages from a specific person
	params = "<name> <color>",
	description = modprepend.."Colourize a specified player's chat messages.",
	func = function(param)
		local args = string.split(param, " ") -- Split up the arguments
		setColor(args[1], args[2])
	end
})

core.register_chatcommand("delcolor", {
	params = "<name>",
	description = modprepend.."Set a specified player's chat messages to the default color.",
	func = function(param)
		setColor(param, nil) -- Setting a colour to nil value type deletes it.
	end
})

core.register_chatcommand("listcolors", {
	params = "",
	description = modprepend.."List current player/color pairs.",
	func = function(param)
		local list = getList(true)
		for i = 1,#list do -- Print list to chat
			local item = string.split(list[i], ",")
			show_msg(item[1]..", ".. core.colorize(item[2], item[2]))
		end
	end
})

core.register_chatcommand("gui", {
	params = "",
	description = modprepend.."Display colorchat formspec GUI.",
	func = function(param)
		guiRow = 1 -- Select first row of table
		core.show_formspec("chatcolor:maingui", getFormspec())
	end
})

core.register_on_formspec_input(function(formname, fields)
	if not string.find(formname, "chatcolor") then return end -- Avoid conflicts
	if fields.main_table then guiRow = tonumber(string.match(fields.main_table, "%d+")) end -- Get the selected table row on change.

	if fields.main_delete then
		local list = getList(true)
		local key = string.split(list[guiRow], ",")[1] -- From selected row number, find what entry is selected
		setColor(key, nil)
		core.show_formspec("chatcolor:maingui", getFormspec())
	elseif fields.main_modify then
		local list = getList(true)
		local key = string.split(list[guiRow], ",")[1]  -- Same as above
		core.show_formspec("chatcolor:modify", getFormspec(true, key)) -- Get formspec and send selected name to modify screen
	elseif fields.main_add then
		core.show_formspec("chatcolor:modify", getFormspec(true, ""))
	elseif fields.mod_set and fields.mod_player and fields.mod_color then
		setColor(fields.mod_player, fields.mod_color)
		core.show_formspec("chatcolor:maingui", getFormspec())
	elseif fields.mod_back then
		core.show_formspec("chatcolor:maingui", getFormspec())
	end
end)

core.register_on_mods_loaded(function()
	core.register_on_receiving_chat_message(function(Message) -- Capitalize the imported Message Global for use in script
		local msg_no_color = core.strip_colors(Message)
		local is_msg_colored = (Message ~= msg_no_color)
        local msg_lowercase = string.lower(msg_no_color) -- word and informal name matching
        --local msg_repeats_removed = string.gsub(msg_lowercase) -- rubenwardy said https://github.com/minetest/minetest/issues/7291#issuecomment-1042376491 , figure out how to use to strip weird chars or internal duplicates
		--local msg_escapes_removed = string.trim(msg_no_color) -- msg_repeats_removed) -- remove escape characters and pre-spaces
        local msg_category_and_name = chatSource(msg_no_color, msg_lowercase)
		local msg_category= msg_category_and_name.category
		local msg_category_color = categoryColorMap[msg_category]
		local msg_sendername = msg_category_and_name.name

		--[[if msg_category and (msg_category == "chat") then -- For each message, check to see if the playername is within 90 blocks, and add an [L] proximity prepend
			if core.get_player_radius_area and core.get_player_by_name then -- If the core engine functions exist
				local is_sender_in_range = tostring(core.get_player_radius_area(msg_sendername, 90)) -- Attempt to detect if the player is in the radius
				if (is_sender_in_range == true) then
					local msg_no_color = "[L]"..msg_no_color -- Add the stringed results of the function to the beginning of the message.
			--else
				-- msg_no_color = "[Far?]"..msg_no_color -- Failed nearby detection indicator
			end
		end--]]

		if msg_category and ((msg_category == "chat") or (msg_category == "irc")) and (Silence_Toggle == "ON") then -- If the Silence Toggle is ON, then throw away standard chat messages by category type
			return ""
		end

		if msg_category and (Debug_Toggle == "ON") then
			Message = "["..msg_category.."]"..Message
			msg_no_color = "["..msg_category.."]"..msg_no_color
		end

        if msg_category_and_name then -- Every other message
            local player_listing = "player_"..msg_sendername -- Take returned array and put it into player_ string
			local player_listing_color = sqlite:get_string(player_listing) -- Get the desired color of the player_listing from storage each message
			if player_listing_color == "" then -- If no stored player listing, either color whole line or first half with the category color
				if (msg_category == "chat") and (is_msg_colored == true) then -- Color first part, last part keeps original color
					local msg_uncolored_table = string.split(msg_no_color, ":", false, 1)
					local msg_colored_table = string.split(Message, ":", false, 1)
					local msg_first_part = core.colorize(msg_category_color, msg_uncolored_table[1])
					local msg_last_part = tostring(msg_colored_table[2])
					show_msg(msg_first_part..":"..msg_last_part)
					return true
				else -- Color the whole line
					local recolored_msg = core.colorize(msg_category_color, msg_no_color)
					show_msg(recolored_msg)
					return true
				end
			else -- A player record was found
				if msg_category and ((msg_category == "warning") or (msg_category == "mention") or (msg_category == "spam") or (msg_category == "helping")) then -- Can this be simplified with the rest later?
					local recolored_msg = core.colorize(msg_category_color, msg_no_color)
					show_msg(recolored_msg)
					return true
				elseif (msg_category == "chat") and (is_msg_colored == true) then -- Color first part, last part keeps original color
					local msg_uncolored_table = string.split(msg_no_color, ":", false, 1)
					local msg_colored_table = string.split(Message, ":", false, 1)
					local msg_first_part = core.colorize(player_listing_color, msg_uncolored_table[1])
					local msg_last_part = tostring(msg_colored_table[2])
					local msg_recombined = msg_first_part..":"..msg_last_part
					show_msg(msg_recombined)
					return true
				else -- Color the whole line
					local recolored_msg = core.colorize(player_listing_color, msg_no_color)
					show_msg(recolored_msg)
					return true
				end
			end
		end
		--[[elseif (string.sub(msg_no_color, 1, 2) == "# ") then -- /status message, should never activate as msg_category should always be something
			local list = sqlite:to_table().fields
			for player_listing,color_value in pairs(list) do -- Get key and value for all pairs
				if string.sub(player_listing, 1, 7) == "player_" then -- Only allows player_categorytype.playername keys instead of default_
					player_listing = string.sub(player_listing, 8) -- Isolate the player name
					local recolored_msg = string.gsub(msg_no_color, player_listing, core.colorize(color_value, player_listing)) -- Replace plain name with coloured version
					show_msg("[# ]"..recolored_msg)
					return true
				end
        	end
		end--]]
			show_msg("[!Ctgry="..msg_category.."]"..Message) -- if it doesn't match to any assigned message category
			return true -- Override the original chat
		--end
	end)

	core.after( 7,  function() -- Wait for Minetest to initialize player before getting name and privs
		if core.get_server_info().protocol_version < 29 then
			LocalPlayerName = tostring(core.localplayer:get_name())
		end
		--LocalPlayerPrivsStr = 	-- need this to work for canKick()
		--if core.settings:get("basic_privs") then
		--	tostring(core.settings:get("basic_privs"))
		--else
		--	LocalPlayerPrivsStr = "error"
		--end
	end)

end)
