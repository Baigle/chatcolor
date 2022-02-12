-- Techy5's colored chat CSM

local data = minetest.get_mod_storage()
local forms = {"chat", "me", "join", "leave", "irc_join", "irc_leave", "irc_nickname", "irc", "anticheat", "PM", "error", "warning"}
local guiRow = 1 -- Which row in the GUI is selected
--local default = "#FFFFFF"
local default = {"white", "orchid", "lightgreen", "salmon", "lightgreen", "salmon", "lime", "limegreen", "khaki", "deeppink", "red", "yellow"}
--local warn = {0} -- Default number of warnings for all players in the key array

for i = 1,12 do -- Make sure all our defaults are in place.
	local key = "default_" .. forms[i]
	if not data:to_table().fields[key] then --data:set_string(key, default) end
        data:set_string(key,default[i]) end
end

local chatSource = function(msg) -- Find the source type of the message
	--if string.sub(msg, 1, 1) == "<" then -- Normal chat messages
	--	local parts = string.split(msg, ">") -- Split it at the closing >
	--	return {form = "chat", name = string.sub(parts[1], 2)} -- Return the first part excluding the first character
	if string.sub(msg, 1, 2) == "* " then -- /me messages frog update
		local parts = string.split(msg, " ") -- Split the message before and after the name
	--?print("ME: " .. tostring(parts[2]))?
		return {form = "me", name = parts[2]}
    elseif string.sub(msg, 1, 3) == "PM " then
        local parts = string.split(msg, " ")
        return {form = "PM", name = parts[3]}
	elseif string.sub(msg, 1, 3) == "<= " then
		local parts = string.split(msg, " ") -- Split the message before and after the name
	--?print("JOIN/LEAVE: " .. tostring(parts[2]))
		return {form = "leave", name = parts[2]}
	--?end
    elseif string.sub(msg, 1, 3) == "=> " then -- Default Join messages
        local parts = string.split(msg, " ")
        return {form = "join", name = parts[2]}
    elseif string.sub(msg, 1, 1) == "<" or string.match(msg, 1, 4) == "@IRC" then -- IRC message format on catlandia
        local parts = string.split(msg, ">")
        return {form = "irc", name = string.sub(parts[1], 2)} -- the IRC names can have crazy characters and spaces
    elseif string.sub(msg, 1, 3) == "-!-" then -- bridged IRC joins and leaves, catlandia formatting
        --if string.sub(msg, 1, 6) == "joined" then
        if string.match(msg, " joined ") then
            local parts = string.split(msg, "> ")
            return {form = "irc_join", name = string.sub(parts[1], 2)}
        --elseif string.sub(msg, 1, 4) == "left" or string.sub(msg, 1, 4) == "quit" then
        elseif string.match(msg, "has left") or string.match(msg, "has quit") then
            local parts = string.split(msg, "> ")
            return {form = "irc_leave", name = string.sub(parts[1], 2)}
        elseif string.match(msg, " changed ") or string.match(msg, "known as") then
            local parts = string.split(msg, "> ")
            return {form = "irc_nickname", name = string.sub(parts[1], 2)} -- Baigle doubts these work if name specified
        else return {form = "error", name = "error"}
        end
    elseif string.sub(msg, 1, 10) == "#anticheat" then
        local parts = string.split(msg, " ")
        return {form = "anticheat", name = parts[2]}
    elseif string.split(msg, ":") then -- Normal chat messages frog edit
        --if canKick() then -- if they have kick privileges
        if string.match(msg, "fucks") or string.match(msg, "sex") or string.match(msg, "s3x") or string.match(msg, "fuck me") then -- marks messages with possible sexual actions in default yellow
            local parts = string.split(msg, ":") -- Split it at the : instead of the <
            return {form = "warning", name = parts[1]}
        --end
        else local parts = string.split(msg, ":")
	--?print("CHAT: " .. string.sub(parts[1], 1))
		--?return {form = "chat", name = string.sub(parts[1], 1)} -- Return the first part
        return {form = "chat", name = parts[1]} -- Return the first part
        end
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
	data:set_string(key, value) -- Set colour
	if value then str = "set" else str = "deleted" end -- Nil values indicate deletion
	minetest.display_chat_message("Color " .. str .. " sucessfully! (" .. name  .. ")")
end

local getList = function(readable) -- Return nicely sorted array of colour defenitions (if readable is true, player prefix will be excluded)
	local list = data:to_table().fields
	local arr = {}
	for key,value in pairs(list) do -- Get key and value for all pairs
		if string.sub(key, 1, 7) == "player_" then -- Exclude defaults
			if readable then key = string.sub(key, 8) end -- Isolate the player name
			arr[#arr+1] = key .. "," .. value
		end
	end
	table.sort(arr) -- Sort alphabetically.
	for i = 1,12 do -- List defaults at end
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

local function canKick() -- checks for kick privilege
    if minetest.get_player_privs().kick == "true" then
        return true
    else
        return false
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
		local source = chatSource(msgPlain)

		if source then -- Normal chat/me/join messages
			local key = "player_" .. source.name -- The setting name
			local color = data:get_string(key) -- Get the desired colour
			if color == "" then -- If no colour, set to default
				color = data:get_string("default_" .. source.form)
			end
			message = minetest.colorize(color, msgPlain)
			minetest.display_chat_message(message)
			return true -- Override the original chat
		elseif string.sub(msgPlain, 1, 2) == "# " then -- /status message
			local list = data:to_table().fields
			for key,value in pairs(list) do -- Get key and value for all pairs
				if string.sub(key, 1, 7) == "player_" then -- Exclude default settings
					key = string.sub(key, 8) -- Isolate the player name
					msgPlain = string.gsub(msgPlain, key, minetest.colorize(value, key)) -- Replace plain name with coloured version
				end
			end
			minetest.display_chat_message(msgPlain)
			return true -- Override the original chat
		end
	end)
end)
