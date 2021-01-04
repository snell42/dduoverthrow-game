--[[ items.lua ]]

--Spawns Bags of Gold in the middle
function COverthrowGameMode:ThinkGoldDrop()
	local r = RandomInt( 1, 100 )
	if r > ( 100 - self.m_GoldDropPercent ) then
		self:SpawnGold()
	end
end

function COverthrowGameMode:SpawnGold()
	local overBoss = Entities:FindByName( nil, "@overboss" )
	local throwCoin = nil
	local throwCoin2 = nil
	if overBoss then
		throwCoin = overBoss:FindAbilityByName( 'dota_ability_throw_coin' )
		throwCoin2 = overBoss:FindAbilityByName( 'dota_ability_throw_coin_long' )
	end

	-- sometimes play the long anim
	if throwCoin2 and RandomInt( 1, 100 ) > 80 then
		overBoss:CastAbilityNoTarget( throwCoin2, -1 )
	elseif throwCoin then
		overBoss:CastAbilityNoTarget( throwCoin, -1 )
	else
		self:SpawnGoldEntity( Vector( 0, 0, 0 ) )
	end
end

function COverthrowGameMode:SpawnGoldEntity( spawnPoint )
	EmitGlobalSound("Item.PickUpGemWorld")
	local newItem = CreateItem( "item_bag_of_gold", nil, nil )
	local drop = CreateItemOnPositionForLaunch( spawnPoint, newItem )
	local dropRadius = RandomFloat( self.m_GoldRadiusMin, self.m_GoldRadiusMax )
	newItem:LaunchLootInitialHeight( false, 0, 500, 0.75, spawnPoint + RandomVector( dropRadius ) )
	newItem:SetContextThink( "KillLoot", function() return self:KillLoot( newItem, drop ) end, 20 )
end


--Removes Bags of Gold after they expire
function COverthrowGameMode:KillLoot( item, drop )

	if drop:IsNull() then
		return
	end

	local nFXIndex = ParticleManager:CreateParticle( "particles/items2_fx/veil_of_discord.vpcf", PATTACH_CUSTOMORIGIN, drop )
	ParticleManager:SetParticleControl( nFXIndex, 0, drop:GetOrigin() )
	ParticleManager:SetParticleControl( nFXIndex, 1, Vector( 35, 35, 25 ) )
	ParticleManager:ReleaseParticleIndex( nFXIndex )
	EmitGlobalSound("Item.PickUpWorld")

	UTIL_Remove( item )
	UTIL_Remove( drop )
end

local function tDump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. tDump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function COverthrowGameMode:SpecialItemAdd( event )
	
	local item = EntIndexToHScript( event.ItemEntityIndex )
	local owner = EntIndexToHScript( event.HeroEntityIndex )
	local hero = owner:GetClassname()
	local ownerTeam = owner:GetTeamNumber()
	print ( ownerTeam )
	local sortedTeams = {}
	for _, team in pairs( self.m_GatheredShuffledTeams ) do
		table.insert( sortedTeams, { teamID = team, teamScore = GetTeamHeroKills( team ) } )
	end

	teamItemsCollected[ownerTeam] = teamItemsCollected[ownerTeam] or {}

	-- reverse-sort by score
	table.sort( sortedTeams, function(a,b) return ( a.teamScore > b.teamScore ) end )
	local n = TableCount( sortedTeams )
	local leader = sortedTeams[1].teamID
	local lastPlace = sortedTeams[n].teamID

	local neutralItems = {}
	neutralItems[1] = {
		"item_satchel",
		"item_satchel",
		"item_satchel",
		"item_ancient_perseverance",
		"item_overflowing_elixir",
		"item_imp_claw",
	}
	neutralItems[2] = {
		"item_quickening_charm",
		"item_titan_sliver",
		"item_mind_breaker",
		"item_flicker",
		"item_helm_of_the_undying",
	}
	neutralItems[3] = {
		"item_spell_prism",
		"item_minotaur_horn",
		"item_princes_knife",
		"item_fusion_rune",
		"item_seer_stone",
	}
	neutralItems[4] = {
		"item_apex",
		"item_demonicon",
		"item_pirate_hat",
		"item_ballista",
	}
	neutralItems[5] = {
		"item_desolator_2",
		"item_mirror_shield",
		"item_trident",
		"item_giants_ring"
	}

	-- Code :)
	local cGameTime = GameRules:GetDOTATime(false, true)
	local tierToGive = 1
	
	if cGameTime > 60 * 15 then tierToGive = 5
	elseif cGameTime > 60 * 12 then tierToGive = 4
	elseif cGameTime > 60 * 7 then tierToGive = 3
	elseif cGameTime > 60 * 4 then tierToGive = 2
	else tierToGive = 1 end

	-- non leaders get a bonus - every 6 points behind the leader you get a point upgrade (rounded down)
	tierToGive = tierToGive + math.floor ( (sortedTeams[1].teamScore - sortedTeams[n].teamScore) / 6 )
	
	-- handle errors
	if tierToGive > 5 then tierToGive = 5 end
	if tierToGive < 1 then tierToGive = 1 end
	
	-- seeds very well :)
	local seed = tonumber ( string.gsub ( GetSystemDate (), "/", "" ) .. string.gsub ( GetSystemTime (), ":", "" ) )
	math.randomseed ( seed )
	
	local itemToGive = ""
	local originalTierToGive = tierToGive
	
	local function pickItemToGive ( tier )
	
		if tier == 0 then
			return 375 * math.pow ( 2, originalTierToGive-1 )
		end
		
		-- Gets a list of items which the player can receive
		local itemsToGive = {}
		local tableEntries = 0
		for k, v in pairs ( neutralItems[tier] ) do
			
			if teamItemsCollected[ownerTeam][v] then
				-- this team has already collected this item
			else
				table.insert ( itemsToGive, v )
				tableEntries = tableEntries + 1
			end
			
		end
		
		if tableEntries == 0 then		
			
			local rng5 = math.random ( 8 )
			if rng5 == 1 then
				print ( "giving money" )
				return 375 * math.pow ( 2, tier-1 )
			else
				return pickItemToGive ( tier-1 )
			end

		else
			local itemIndex = math.random ( #itemsToGive )
			teamItemsCollected[ownerTeam][itemsToGive[itemIndex]] = true
			return itemsToGive[itemIndex]
		end
		
	end
	
	itemToGive = pickItemToGive ( tierToGive )

	if type ( itemToGive ) == "string" then
		owner:AddItemByName( itemToGive )
		EmitGlobalSound("powerup_04")
		local overthrow_item_drop =
		{
			hero_id = hero,
			dropped_item = itemToGive
		}
		CustomGameEventManager:Send_ServerToAllClients( "overthrow_item_drop", overthrow_item_drop )
		
		if itemToGive == "item_branches" then
			owner:ModifyGold ( 200 * ( cGameTime / 60 ), true, 0 )
		end
	else
		owner:ModifyGold ( itemToGive, true, 0 )
		EmitGlobalSound("powerup_04")

		local overthrow_item_drop =
		{
			hero_id = hero,
			dropped_item = "item_bag_of_gold2"
		}
		CustomGameEventManager:Send_ServerToAllClients( "overthrow_item_drop", overthrow_item_drop )
	end
	
end

function COverthrowGameMode:ThinkSpecialItemDrop()
	-- Stop spawning items after 15
	--if self.nNextSpawnItemNumber >= 15 then
	--	return
	--end
	-- Don't spawn if the game is about to end
	if nCOUNTDOWNTIMER < 20 then
		return
	end
	local t = GameRules:GetDOTATime( false, false )
	local tSpawn = ( self.spawnTime * self.nNextSpawnItemNumber )
	local tWarn = tSpawn - 15

	if not self.hasWarnedSpawn and t >= tWarn then
		-- warn the item is about to spawn
		self:WarnItem()
		self.hasWarnedSpawn = true
	elseif t >= tSpawn then
		-- spawn the item
		self:SpawnItem()
		self.nNextSpawnItemNumber = self.nNextSpawnItemNumber + 1
		self.hasWarnedSpawn = false
	end
end

function COverthrowGameMode:PlanNextSpawn()
	local missingSpawnPoint =
	{
		origin = "0 0 384",
		targetname = "item_spawn_missing"
	}

	local r = RandomInt( 1, 8 )
	if GetMapName() == "desert_quintet" then
		print("map is desert_quintet")
		r = RandomInt( 1, 6 )
	elseif GetMapName() == "temple_quartet" then
		print("map is temple_quartet")
		r = RandomInt( 1, 4 )
	end
	local path_track = "item_spawn_" .. r
	local spawnPoint = Vector( 0, 0, 700 )
	local spawnLocation = Entities:FindByName( nil, path_track )

	if spawnLocation == nil then
		spawnLocation = SpawnEntityFromTableSynchronous( "path_track", missingSpawnPoint )
		spawnLocation:SetAbsOrigin(spawnPoint)
	end

	self.itemSpawnLocation = spawnLocation
	self.itemSpawnIndex = r
end

function COverthrowGameMode:WarnItem()
	-- find the spawn point
	self:PlanNextSpawn()

	local spawnLocation = self.itemSpawnLocation:GetAbsOrigin();

	-- notify everyone
	CustomGameEventManager:Send_ServerToAllClients( "item_will_spawn", { spawn_location = spawnLocation } )
	EmitGlobalSound( "powerup_03" )

	-- fire the destination particles
	DoEntFire( "item_spawn_particle_" .. self.itemSpawnIndex, "Start", "0", 0, self, self )

	-- Give vision to the spawn area (unit is on goodguys, but shared vision)
	local visionRevealer = CreateUnitByName( "npc_vision_revealer", spawnLocation, false, nil, nil, DOTA_TEAM_GOODGUYS )
	visionRevealer:SetContextThink( "KillVisionRevealer", function() return visionRevealer:RemoveSelf() end, 35 )
	local trueSight = ParticleManager:CreateParticle( "particles/econ/wards/f2p/f2p_ward/f2p_ward_true_sight_ambient.vpcf", PATTACH_ABSORIGIN, visionRevealer )
	ParticleManager:SetParticleControlEnt( trueSight, PATTACH_ABSORIGIN, visionRevealer, PATTACH_ABSORIGIN, "attach_origin", visionRevealer:GetAbsOrigin(), true )
	visionRevealer:SetContextThink( "KillVisionParticle", function() return trueSight:RemoveSelf() end, 35 )
end

function COverthrowGameMode:SpawnItem()
	-- notify everyone
	CustomGameEventManager:Send_ServerToAllClients( "item_has_spawned", {} )
	EmitGlobalSound( "powerup_05" )

	-- spawn the item
	--local startLocation = Vector( 0, 0, 700 )
	local startLocation = Entities:FindByName( nil, "@overboss" )
	if startLocation then startLocation=startLocation:GetOrigin () else startLocation = Vector( 0, 0, 700 ) end
	local treasureCourier = CreateUnitByName( "npc_dota_treasure_courier" , startLocation, true, nil, nil, DOTA_TEAM_NEUTRALS )
	local treasureAbility = treasureCourier:FindAbilityByName( "dota_ability_treasure_courier" )
	treasureAbility:SetLevel( 1 )
    --print ("Spawning Treasure")
    targetSpawnLocation = self.itemSpawnLocation
    treasureCourier:SetInitialGoalEntity(targetSpawnLocation)
    --local particleTreasure = ParticleManager:CreateParticle( "particles/items_fx/black_king_bar_avatar.vpcf", PATTACH_ABSORIGIN, treasureCourier )
	--ParticleManager:SetParticleControlEnt( particleTreasure, PATTACH_ABSORIGIN, treasureCourier, PATTACH_ABSORIGIN, "attach_origin", treasureCourier:GetAbsOrigin(), true )
	--treasureCourier:Attribute_SetIntValue( "particleID", particleTreasure )
end

function COverthrowGameMode:ForceSpawnItem()
	self:WarnItem()
	self:SpawnItem()
end

function COverthrowGameMode:KnockBackFromTreasure( center, radius, knockback_duration, knockback_distance, knockback_height )
	local targetType = bit.bor( DOTA_UNIT_TARGET_CREEP, DOTA_UNIT_TARGET_HERO )
	local knockBackUnits = FindUnitsInRadius( DOTA_TEAM_NOTEAM, center, nil, radius, DOTA_UNIT_TARGET_TEAM_BOTH, targetType, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false )

	local modifierKnockback =
	{
		center_x = center.x,
		center_y = center.y,
		center_z = center.z,
		duration = knockback_duration,
		knockback_duration = knockback_duration,
		knockback_distance = knockback_distance,
		knockback_height = knockback_height,
	}

	for _,unit in pairs(knockBackUnits) do
--		print( "knock back unit: " .. unit:GetName() )
		unit:AddNewModifier( unit, nil, "modifier_knockback", modifierKnockback );
	end
end


function COverthrowGameMode:TreasureDrop( treasureCourier )
	--Create the death effect for the courier
	local spawnPoint = treasureCourier:GetInitialGoalEntity():GetAbsOrigin()
	spawnPoint.z = 400
	local fxPoint = treasureCourier:GetInitialGoalEntity():GetAbsOrigin()
	fxPoint.z = 400
	local deathEffects = ParticleManager:CreateParticle( "particles/treasure_courier_death.vpcf", PATTACH_CUSTOMORIGIN, nil)
	ParticleManager:SetParticleControl( deathEffects, 0, fxPoint )
	ParticleManager:SetParticleControlOrientation( deathEffects, 0, treasureCourier:GetForwardVector(), treasureCourier:GetRightVector(), treasureCourier:GetUpVector() )
	EmitGlobalSound( "lockjaw_Courier.Impact" )
	EmitGlobalSound( "lockjaw_Courier.gold_big" )

	--Spawn the treasure chest at the selected item spawn location
	local newItem = CreateItem( "item_treasure_chest", nil, nil )
	local drop = CreateItemOnPositionForLaunch( spawnPoint, newItem )
	drop:SetForwardVector( treasureCourier:GetRightVector() ) -- oriented differently
	newItem:LaunchLootInitialHeight( false, 0, 50, 0.25, spawnPoint )

	--Stop the particle effect
	DoEntFire( "item_spawn_particle_" .. self.itemSpawnIndex, "stopplayendcap", "0", 0, self, self )

	--Knock people back from the treasure
	self:KnockBackFromTreasure( spawnPoint, 375, 0.25, 750, 100 )

	--Destroy the courier
	UTIL_Remove( treasureCourier )
end

function COverthrowGameMode:ForceSpawnGold()
	self:SpawnGold()
end
