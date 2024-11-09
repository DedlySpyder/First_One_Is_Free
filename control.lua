local MINIME_REMOTE_ACTIVE = false

script.on_init(function()
	global.inventory_slots = global.inventory_slots or {}
	global.opened_changes = global.opened_changes or {}
	checkForRemotes()
end)

script.on_load(function()
	checkForRemotes()
end)

script.on_configuration_changed(function(event)
	local FoF = event.mod_changes["First_One_Is_Free"]
	if FoF and FoF.old_version == "0.0.2" then
		global.opened_changes = global.opened_changes or {}
	end
	checkForRemotes()
end)

function checkForRemotes()
	MINIME_REMOTE_ACTIVE = remote.interfaces.minime and remote.interfaces.minime.main_inventory_resized
end

script.on_event(defines.events.on_player_died, function(event)
	local player = game.players[event.player_index]
	global.inventory_slots[player.name] = 0
end)

script.on_event(defines.events.on_player_main_inventory_changed, function(event)
	local player = game.players[event.player_index]
	if player and player.character then
		if isSafeToChange(player) then
			changeInventorySlots(player)
		else
			global.opened_changes[player.name] = true
		end
	end
end)

script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
	local player = game.players[event.player_index]
	if player and player.character and not getPlayerCursorStackName(player) then
		if isSafeToChange(player) then
			changeInventorySlots(player)
		end
	end
end)

script.on_event(defines.events.on_tick, function(event)
	if game.tick % 60 == 6 then
		for playerName, flag in pairs(global.opened_changes) do
			if flag then
				local player = game.players[playerName]
				if player and 
				   player.valid and 
				   player.connected and 
				   player.character and 
				   isSafeToChange(player) then
					if changeInventorySlots(player) then
						global.opened_changes[playerName] = false
					end
				end
			end
		end
	end
end)

function getPlayerCursorStackName(player)
	local cursorStack = player.cursor_stack
	if cursorStack and cursorStack.valid and cursorStack.valid_for_read then
		return cursorStack.name
	end
end

function changeInventorySlots(player)
	local main_inventory = player.get_main_inventory()
	local contents = main_inventory.get_contents()
	local cursorItemName = getPlayerCursorStackName(player)
	local itemCount = 0
	for itemName, _ in pairs(contents) do
		itemCount = itemCount + 1

		if cursorItemName == itemName then
			cursorItemName = nil
		end
	end

	if cursorItemName then
		itemCount = itemCount + 1
	end

	local currentSlots = global.inventory_slots[player.name] or 0
	local change = itemCount - currentSlots
	local newBonus = player.character_inventory_slots_bonus + change

	-- If the last item slot that will be removed has an item in it, then don't scale down
	local lastIndex = #main_inventory + change + 1
	if change < 0 and lastIndex > 0 and main_inventory[lastIndex].valid_for_read then
		return false
	end

	if change ~= 0 and newBonus >= 0 then
		player.character_inventory_slots_bonus = newBonus
		emitInventoryResized(player)
	end
	
	global.inventory_slots[player.name] = itemCount
	return true
end

function isSafeToChange(player)
	return player.opened_gui_type == defines.gui_type.none
end

function emitInventoryResized(player)
	if MINIME_REMOTE_ACTIVE then
		remote.call("minime", "main_inventory_resized", player.index)
	end
end