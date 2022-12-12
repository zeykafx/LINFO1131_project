functor
import
	GUI
	Input
	PlayerManager
	System
	OS
	Application
define
	StartGameController
	TreatGameControllerStream
	MatchHead
	DoListPlayer
	InitThreadForAll
	PlayersPorts
	SendToAll
	Main
	WindowPort
	GameControllerPort
	PlayTurn
	InitPlayersState
	PlayerStateModification
	ManhattanDistance

	proc {DrawFlags Flags Port}
		case Flags of nil then skip
		[] Flag|T then
			{Send Port putFlag(Flag)}
			{DrawFlags T Port}
		end
	end

	fun {GetMapPos X Y}
		{List.nth {List.nth Input.map X} Y}
	end
	
	PRINT_STEPS = true

	proc {PrintSteps Whatever}
		if PRINT_STEPS then
			{System.show Whatever}
		end
	end
in

	%%%% GAME CONTROLLER


	% InitPlayersState creates the state for all the players, returns a list of playerState tuples that contain ID, HP, Pos, Reloads, flag,...
	fun {InitPlayersState Nbr}
		if Nbr > Input.nbPlayer then
			nil
		else
			playerState(
					id:id(id:Nbr color:{List.nth Input.colors Nbr} name:_) 
					position:{List.nth Input.spawnPoints Nbr} 
					hp:Input.startHealth 
					mineReload:0 
					gunReload:0 
					flag:null
					speedBoost:false
				)|{InitPlayersState Nbr+1}
		end
	end

	fun{StartGameController}
		Stream
		Port
	in
		{NewPort Stream Port}
		thread
			{TreatGameControllerStream 
				Stream
				state(
					mines:nil
					flags:Input.flags 
					foodTimerRunning:false
					speedTimerRunning:false
					adrenalineTimerRunning:false
					food:nil
					speed:nil
					adrenaline:nil
					playersState:{InitPlayersState 1}
				)
			}
		end
		Port
	end


	% State is like state(mines:[mines] flags:[flags] shouldSpawnFood:boolean food:[food] speed:[speed] adrenaline:[adrenaline] playerState(id:id(id:Nbr color:Color) position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost))


	proc{TreatGameControllerStream Stream State}
		case Stream
			of H|T then {TreatGameControllerStream T {MatchHead H State}}
		end
	end

	fun {MatchHead Head State}

		%%% handles getPlayersState(?List) messages
		fun {GetPlayersState State ?List}
			List = State.playersState
			State
		end
		
		%%% handles setPlayersState(NewPlayersState) messages
		fun {SetPlayersState State NewPlayersState}
			{AdjoinAt State playersState NewPlayersState}
		end

		%%% handles getPlayerHP(ID ?HP) messages
		fun {GetPlayerHP State ID HP}
			HP = {List.nth State.playersState ID.id}.hp
			State
		end

		%%% handles movePlayer(ID Position ?Status) messages
		fun {MovePlayer State ID Position ?Status}
			% modifies the position inside the playersState list
			fun {ModPos PlayerState}
				playerState(id:LocalID position:_ hp:HP mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost) = PlayerState

			in
				playerState(id:LocalID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost)
			end
			NewState NewPosMapTileNbr CurrentPlayerState EnemyBaseTileNbr OtherPlayersAtPos MaxTravelDistance
		in
			% get the player n°ID's state
			CurrentPlayerState = {List.nth State.playersState ID.id}

			MaxTravelDistance = if CurrentPlayerState.speedBoost == true then 2 else 1 end

			% if the new position is in the map
			if (Position.x =< Input.nRow) andthen (Position.y =< Input.nColumn) andthen (Position.x > 0) andthen (Position.y > 0) then
	
				% walls (3) and enemy base are impenetrable, player 1 is red (1) and player 2 is blue (2)
				EnemyBaseTileNbr = if ID.color == red then 2 else 1 end 		
			
				% get the tile number for the new position, this is the integer as defined in Input.oz
				% 0 = Empty
				% 1 = Player 1's base (red)
				% 2 = Player 2's base (blue)
				% 3 = Walls
				NewPosMapTileNbr = {GetMapPos Position.x Position.y}
				
				% check if there are other players at the position that the player wants to go to, if there is, we refuse the move
				OtherPlayersAtPos = {List.filter State.playersState fun {$ Elem} Elem.position == Position andthen Elem.id.id \= CurrentPlayerState.id.id andthen Elem.hp > 0 end}


				% check that the player isn't moving more than MaxTravelDistance tile in both directions, and that he isn't moving onto a wall or in the enemy base
				% {Abs (CurrentPlayerState.position.x - Position.x)} =< 1 andthen {Abs (CurrentPlayerState.position.y - Position.y)} =< 1
				if {ManhattanDistance CurrentPlayerState.position Position} =< MaxTravelDistance andthen (NewPosMapTileNbr \= 3) andthen (NewPosMapTileNbr \= EnemyBaseTileNbr) andthen {List.length OtherPlayersAtPos} == 0 then

					% if the move is valid, move the player and bind Status to true
					NewState = {AdjoinAt State playersState {PlayerStateModification State.playersState ID ModPos}}
					Status = true

				else
					{System.show 'INVALID MOVE '#ID#' player wanted to move from'#CurrentPlayerState.position#' to '#Position#' Position had these players on it '#OtherPlayersAtPos# ' and was of tile nbr '#NewPosMapTileNbr}
					NewState = State
					Status = false
				end
			else
				{System.show 'Player '#ID#' at position '#CurrentPlayerState.position#' wanted to move to '#Position}
				NewState = State
				Status = false
			end
			NewState
		end

		%%% handles killPlayer(ID) messages
		fun {KillPlayer State ID}
			fun {ModDeath PlayerState}
				playerState(id:ID position:Position hp:_ mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost) = PlayerState
			in
				playerState(id:ID position:Position hp:0 mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost)
			end 
		in
			{AdjoinAt State playersState {PlayerStateModification State.playersState ID ModDeath}}
		end

		%%% handles respawnPlayer(ID) messages
		fun {RespawnPlayer State ID}
			fun {ModHp PlayerState}
				playerState(id:LocalID position:_ hp:_ mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost) = PlayerState
				NewPos
			in
				NewPos = {List.nth Input.spawnPoints LocalID.id}
				playerState(id:LocalID position:NewPos hp:Input.startHealth mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost)
			end 
		in
			{AdjoinAt State playersState {PlayerStateModification State.playersState ID ModHp}}
		end

		%%% handles sayDamageTaken(ID Damage LifeLeft) messages
		fun {SayDamageTaken State ID Damage LifeLeft}
			fun {ModHp PlayerState}
				playerState(id:LocalID position:Position hp:_ mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost) = PlayerState
			in
				playerState(id:LocalID position:Position hp:LifeLeft mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost)
			end 
		in
			{AdjoinAt State playersState {PlayerStateModification State.playersState ID ModHp}}
		end

		fun {CheckAllPlayersFlags PlayerState}
			case PlayerState
			of nil then 
				nil  % no player has the flag

			[] playerState(id:PlayerID position:PlayerPosition hp:_ mineReload:_ gunReload:_ flag:PlayerFlag speedBoost:_)|NextPlayer then
				% check the flag
				case PlayerFlag 
				of null then 
					% if its null, this player has no flags
					{CheckAllPlayersFlags NextPlayer}
				else
					% the player had a flag, return the flag along with the player ID, but also keep looking for more flags
					flagTaken(flag: PlayerFlag player:PlayerID)|{CheckAllPlayersFlags NextPlayer} 
				end
			end
		end

		%%% handles canGrabFlag(ID Flag ?Status) messages
		fun {CheckCanGrabFlag State ID Flag ?Status}

			fun {ModFlag PlayerState}
				playerState(id:LocalID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:_ speedBoost:SpeedBoost) = PlayerState
			in
				playerState(id:LocalID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost)
			end 

			CurrentPlayerState OutputState
		in

			% checks to see if the flag is in the flags list
			% and also check that no friendly already are already carrying the flag
			if {List.member Flag State.flags} andthen {List.length {List.filter {CheckAllPlayersFlags State.playersState} fun {$ Flag} Flag.flag.color \= ID.color end}} == 0 then
				
				CurrentPlayerState = {List.nth State.playersState ID.id}

				% the player has to stand on the same time as the flag to be able to grab it
				if Flag.pos == CurrentPlayerState.position andthen CurrentPlayerState.flag == null andthen Flag.color \= ID.color then

					% the player is on the tile, he can grab the flag
					{System.show 'Player ID '#ID#' grabs the flag'#Flag}

					% remove the flag from the flag list
					OutputState = {AdjoinAt {AdjoinAt State flags {List.filter State.flags fun {$ Elem} Elem \= Flag end}} playersState {PlayerStateModification State.playersState ID ModFlag}}
					Status = true

				else
					% the player is too far or already has a flag (impossible but we still check)
					OutputState = State
					Status = false
				end

			else
				% either the flag was not valid, or another player had the flag
				{System.show 'Player ID'#ID#' is unable to grab flag '#Flag#' because its invalid or already taken'}
				OutputState = State
				Status = false
			end
			
			OutputState
		end

		%%% handles dropFlag(ID Flag ?Status) messages
		fun {DropFlag State ID Flag ?Status}
			fun {ModFlag PlayerState}
				playerState(id:LocalID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:_ speedBoost:SpeedBoost) = PlayerState
			in
				Status = true
				playerState(id:LocalID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:null speedBoost:SpeedBoost)
			end

			InBase
		in
			if ID.color == red then
				if Flag.pos.x =< 2 andthen Flag.pos.y =< 3 then
					InBase = true
				else
					InBase = false
				end
			else
				if Flag.pos.x >= 11 andthen Flag.pos.y >= 10 then
					InBase = true
				else
					InBase = false
				end
			end

			if InBase then
				{System.show 'TEAM '#ID.color#' WON THE GAME'}
				thread {Delay 50} {Application.exit 0} end % its not ideal to just close the app like this when a team wins but it'll have to do
			else
				skip
			end
			{AdjoinAt {AdjoinAt State flags Flag|State.flags} playersState {PlayerStateModification State.playersState ID ModFlag}}
		end

		%%% handles wasPlayerCarryingFlag(ID ?Flag ?Status) messages
		fun {WasPlayerCarryingFlag State ID ?Flag ?Status}
			CurrentPlayerState
		in
			CurrentPlayerState = {List.nth State.playersState ID.id}

			if CurrentPlayerState.flag \= null then
				Status = true
				Flag = {AdjoinAt CurrentPlayerState.flag pos CurrentPlayerState.position} % change the flag position to the latest player's position 
			else 
				Status = false
				Flag = null
			end
			State
		end

		%%% handles startFoodTimer(?TimerStatus) messages
		fun {StartFoodTimer State ?TimerStatus}
			OutputState
		in
			% start the timer only if no other timer were already started
			if State.foodTimerRunning == false then
				thread 
					% after a random delay, send a message to the game controller to spawn food on a random tile
					{Delay ({OS.rand} mod (Input.foodDelayMax - Input.foodDelayMin) + Input.foodDelayMin)}
					{Send GameControllerPort spawnFood()}
				end
				OutputState = {AdjoinAt State foodTimerRunning true}
				TimerStatus = true
			else
				OutputState = State
				TimerStatus = false
			end
			OutputState
		end

		%%% handles spawnFood() messages
		fun {SpawnFood State}
			local
				fun {RandomPosOnMap}
					case ({OS.rand} mod 12) +1 % +1 because there is no pos 0 on the map
					of X then
						case ({OS.rand} mod 12) +1
						of Y then
							if {GetMapPos X Y} == 0 andthen {List.all State.speed fun {$ Elem} {GetMapPos X Y} \= Elem.pos end} andthen {List.all State.food fun {$ Elem} {GetMapPos X Y} \= Elem.pos end} andthen {List.all State.adrenaline fun {$ Elem} {GetMapPos X Y} \= Elem.pos end} then
								% if the random tile is not a wall or a base, and doesn't have speed/food/adrenaline on it, then we can spawn food there
									pt(x:X y:Y)
							else
								% if the position was a wall or a base, try again until we get a correct position
								% super efficient i know :)
								{RandomPosOnMap}
							end
						end
					end
				end

				OutputState RandomPos
			in
				RandomPos = {RandomPosOnMap}
				% add the new food in the food list, and also set the food timer gard to false
				OutputState = {AdjoinAt {AdjoinAt State food food(pos: RandomPos)|State.food} foodTimerRunning false}

				% broadcast that the food item appeared on the map
				{SendToAll sayFoodAppeared(food(pos: RandomPos))}
				{Send WindowPort putFood(food(pos: RandomPos))}

				OutputState
			end
		end

		%%% handles canEatFood(ID Food ?Status) messages
		fun {CanEatFood State ID  Food ?Status}
			local
				OutputState NewPlayersState
				fun {ModHp PlayerState}
					playerState(id:ID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost) = PlayerState
				in
					{Send WindowPort lifeUpdate(ID HP+1)}
					% Not sure if we need to limit the HP to startHealt or not. use this if yes -> {Max HP+1 Input.startHealth}
					playerState(id:ID position:Position hp:HP+1 mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost)
				end 
			in
				% check to see if the food is a valid food item, and to see if the player's position is the same as the food item's, then they can consume it
				if {List.member Food State.food} andthen Food.pos == {List.nth State.playersState ID.id}.position then

					{SendToAll sayFoodEaten(ID Food)}
					{Send WindowPort removeFood(Food)}
					
					% give one HP to the player
					NewPlayersState = {AdjoinAt State playersState {PlayerStateModification State.playersState ID ModHp}}

					% remove the food from the food list
					OutputState = {AdjoinAt NewPlayersState food {List.filter State.food fun {$ Elem} Elem \= Food end}}
					
					Status = true
				else
					OutputState = State
					Status = false
				end
				OutputState
			end
		end

		%%% SPEED and ADRENALINE

		%%% handles startSpeedTimer(?TimerStatus) and startAdrenalineTimer(?TimerStatus) messages
		fun {StartBoostTimer State SpeedOrAdrenaline ?TimerStatus}
			Timer DelayMax DelayMin Message OutputState
		in
			if SpeedOrAdrenaline == speed then
				Timer = speedTimerRunning
				DelayMax = Input.speedBoostDelayMax
				DelayMin = Input.speedBoostDelayMin
				Message = spawnSpeed()
			else
				Timer = adrenalineTimerRunning
				DelayMax = Input.adrenalineDelayMax
				DelayMin = Input.adrenalineDelayMin
				Message = spawnAdrenaline()
			end

			% start the timer only if no other timer were already started
			if State.Timer == false then
				OutputState = {AdjoinAt State Timer true}
				TimerStatus = true
				thread 
					% after a random delay, send a message to the game controller to spawn the boost on a random tile
					{Delay ({OS.rand} mod (DelayMax - DelayMin) + DelayMin)}
					{Send GameControllerPort Message}
				end
			else
				OutputState = State
				TimerStatus = false
			end
			OutputState
		end

		%%% handles spawnSpeed() and spawnAdrenaline() messages
		fun {SpawnBoost SpeedOrAdrenaline State}
			local
				fun {RandomPosOnMap}
					case ({OS.rand} mod 12) +1 % +1 because there is no pos 0 on the map
					of X then
						case ({OS.rand} mod 12) +1
						of Y then
							if {GetMapPos X Y} == 0 andthen {List.all State.speed fun {$ Elem} {GetMapPos X Y} \= Elem.pos end} andthen {List.all State.food fun {$ Elem} {GetMapPos X Y} \= Elem.pos end} andthen {List.all State.adrenaline fun {$ Elem} {GetMapPos X Y} \= Elem.pos end} then
									pt(x:X y:Y)
							else
								{RandomPosOnMap}
							end
						end
					end
				end
				OutputState RandomPos
			in
				RandomPos = {RandomPosOnMap}
				if SpeedOrAdrenaline == speed then
					OutputState = {AdjoinAt {AdjoinAt State speed speed(pos: RandomPos)|State.speed} speedTimerRunning false}
					{Send WindowPort putSpeed(speed(pos: RandomPos))}
				else
					OutputState = {AdjoinAt {AdjoinAt State adrenaline adrenaline(pos: RandomPos)|State.adrenaline} adrenalineTimerRunning false}
					{Send WindowPort putAdrenaline(adrenaline(pos: RandomPos))}
				end
				OutputState
			end
		end

		%%% handles canEatSpeed(ID Speed ?Status) and canEatAdrenaline(ID Adrenaline ?Status) messages
		fun {CanEatBoost State ID Item SpeedOrAdrenaline ?Status}
			local
				fun {ModSpeed PlayerState}
					playerState(id:ID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:_) = PlayerState
				in
					playerState(id:ID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:true)
				end 

				fun {ModAdrenaline PlayerState}
					playerState(id:ID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost) = PlayerState
					NewHp
				in
					NewHp = HP+Input.adrenalineBoostHP
					{Send WindowPort lifeUpdate(ID NewHp)}
					{SendToAll sayDamageTaken(ID ~2 NewHp)} % remove -2 dmg to give 2 hp to the player
					playerState(id:ID position:Position hp:NewHp mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost)
				end 

				OutputState NewPlayersState
			in

				if {List.member Item State.SpeedOrAdrenaline} andthen Item.pos == {List.nth State.playersState ID.id}.position then
					if SpeedOrAdrenaline == speed then
						{Send WindowPort removeSpeed(Item)}
						NewPlayersState = {AdjoinAt State playersState {PlayerStateModification State.playersState ID ModSpeed}}

					else
						{Send WindowPort removeAdrenaline(Item)}
						NewPlayersState = {AdjoinAt State playersState {PlayerStateModification State.playersState ID ModAdrenaline}}
					end

					OutputState = {AdjoinAt NewPlayersState SpeedOrAdrenaline {List.filter State.SpeedOrAdrenaline fun {$ Elem} Elem \= Item end}}
					Status = true

					thread 
						Message = if SpeedOrAdrenaline == speed then removeSpeedBoost(ID) else removeAdrenalineBoost(ID) end
						Message2 = if SpeedOrAdrenaline == speed then saySpeedBoostWoreOff() else sayAdrenalineWoreOff() end
					in
						{Delay Input.boostsDuration}
						{Send GameControllerPort Message}
						{Send {List.nth PlayersPorts ID.id}.2 Message2}
					end

				else
					OutputState = State
					Status = false
				end
				OutputState
			end
		end

		%%% handles removeSpeedBoost(ID) and removeAdrenalineBoost(ID) messages
		fun {RemoveBoost State ID SpeedOrAdrenaline}
			local
				fun {ModSpeed PlayerState}
					playerState(id:ID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:_) = PlayerState
				in
					playerState(id:ID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:false)
				end 

				fun {ModAdrenaline PlayerState}
					playerState(id:ID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost) = PlayerState
					NewHp
				in
					NewHp = (HP-Input.adrenalineBoostHP)
					{Send WindowPort lifeUpdate(ID NewHp)}
					{SendToAll sayDamageTaken(ID Input.adrenalineBoostHP NewHp)} 
					playerState(id:ID position:Position hp:NewHp mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost)
				end 
			in

				{AdjoinAt State playersState {PlayerStateModification State.playersState ID if SpeedOrAdrenaline == speed then ModSpeed else ModAdrenaline end}}
			end
		end
	

		%%% MINES
		
		%%% handles getMines(?Mines) messages
		fun {GetMines State ?Mines}
			Mines = State.mines
			State
		end


		% check if there is a mine at a given position, used in step 4
		fun {CheckMineAtPosHelper MineList Position Index}
			case MineList
			of nil then false
			[] mine(pos:MinePosition)|T then
				if MinePosition == Position then
					mineExploded(MinePosition Index)
				else
					{CheckMineAtPosHelper T Position Index+1}
				end
			end
		end

		%%% handles checkMineAtPos(Position ?HasMineExploded) messages
		fun {CheckMineAtPos State Position ?HasMineExploded}
			HasMineExploded = {CheckMineAtPosHelper State.mines Position 1}
			State
		end

		%% MineExploded and FireItem helper functions
		% removes the mine from the list of mines on the map
		fun {RemoveMine MineList WantedMine}
			case MineList
			of nil then nil
			[] MineInList|T then
				if MineInList == WantedMine then
					T
				else
					MineInList|{RemoveMine T WantedMine}
				end
			end
		end

		% function that applies the damage to the player
		fun {ApplyDmg PlayerState HpToRemove}
			playerState(id:LocalID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost) = PlayerState
			NewHp
		in
			NewHp = {Max HP-HpToRemove 0}
			{System.show 'Player id'#LocalID#' now has '#NewHp#' hp'}

			% broadcast that this player has taken damage
			{Send WindowPort lifeUpdate(LocalID NewHp)}
			{SendToAll sayDamageTaken(LocalID HpToRemove NewHp)}

			if NewHp == 0 then
				{SendToAll sayDeath(LocalID)}
			end

			playerState(id:LocalID position:Position hp:NewHp mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost)
		end 

		% apply damage to all players based on the range from the mine
		fun {ApplyDmgIfInRange PlayersState MinePos}
			DistanceFromMine 
		in
			case PlayersState
			of nil then nil
			[] playerState(id:ID position:Position hp:HP mineReload:_ gunReload:_ flag:_ speedBoost:_)|T then
						
				% get the manhattan distance from the mine
				DistanceFromMine = {ManhattanDistance MinePos Position}
				{System.show 'Player '#ID#' at position'#Position#' is at distance '#DistanceFromMine#' from the mine at position '#MinePos}

				% deal dmg based on the distance from the mine
				if DistanceFromMine == 0 andthen HP > 0 then
					% the mine deals two dmg if the player stepped on the mine 
					{ApplyDmg PlayersState.1 2}|{ApplyDmgIfInRange T MinePos} % continue looking for other players possibly hurt
				elseif DistanceFromMine == 1 andthen HP > 0 then
					% only deal one dmg if the player was in a one tile away
					{ApplyDmg PlayersState.1 1}|{ApplyDmgIfInRange T MinePos}
				else
					% dont apply dmg, the player was too far away from the explosion, or already dead
					PlayersState.1|{ApplyDmgIfInRange T MinePos}
				end

			end
		end

		%%% handles mineExploded(Mine ?Status) messages
		fun {MineExploded State Mine ?Status}
			NewState MinesNearby
		in
			NewState = {AdjoinAt State mines {List.filter State.mines fun {$ Elem} Elem \= Mine end}}

			{SendToAll sayMineExplode(Mine)}
			{Send WindowPort removeMine(Mine)}

			% check for other mines in the vicinity (chain reaction)
			MinesNearby = {List.filter NewState.mines fun {$ Elem} {ManhattanDistance Mine.pos Elem.pos} == 1 end}

			if {List.length MinesNearby} >= 1 then
				for I in MinesNearby do
					thread 
						{Wait Status}

						{Delay 500} % small delay to make the explosions look like a chain reaction
						% send a message to the gamecontroller in another thread to ask to make the mines nearby explode
						{Send GameControllerPort mineExploded(I _)}
					end
				end
			
			end

			Status = true
			{AdjoinAt NewState playersState {ApplyDmgIfInRange NewState.playersState Mine.pos}}

		end

		%%%% Items

		%%% handles chargeItem(ID Item ?Status) messages
		fun {ChargeItem State ID Item ?Status}
			fun {ModCharge PlayerState}
				playerState(id:LocalID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost) = PlayerState
				NewGunReload NewMineReload
			in
				if Item == gun then
					NewGunReload = {Min GunReload+1 Input.gunCharge}
					NewMineReload = MineReload
				else
					NewGunReload = GunReload
					NewMineReload = {Min MineReload+1 Input.mineCharge}
				end

				Status = true

				% update the mine/gun reload
				playerState(id:LocalID position:Position hp:HP mineReload:NewMineReload gunReload:NewGunReload flag:Flag speedBoost:SpeedBoost)
			end 
		in
			{AdjoinAt State playersState {PlayerStateModification State.playersState ID ModCharge}}
		end

		% check if there is a player at a given position, used in step 6 (when shooting a gun)
		fun {ShootPlayerAtPos PlayersState WantedPosition Function}
			case PlayersState
			of nil then nil
			[] playerState(id:ID position:PlayerPosition hp:HP mineReload:_ gunReload:_ flag:_ speedBoost:_)|T then
				% shoot player at WantedPosition, if they are alive
				if (PlayerPosition == WantedPosition) andthen HP > 0 then
					{Function PlayersState.1}|T
				else 
					PlayersState.1|{ShootPlayerAtPos T WantedPosition Function}
				end
			end
		end

		%%% handles fireItem(ID FiredItem ?Status) messages
		fun {FireItem State ID FiredItem ?Status}
			% check that the item can indeed be fired
			% then fire that weapon, guns have a range of 2 and mines are placed below the player
			local
				CurrentPlayerState DistanceFromWeaponPos HasMineExploded MinePosition Index
				OutputState NewStateMineExplosion

				fun {ModHp PlayerState}
					playerState(id:LocalID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost) = PlayerState
					NewHP
				in
					NewHP = {Max HP-1 0}

					{Send WindowPort lifeUpdate(LocalID NewHP)}
					{SendToAll sayDamageTaken(LocalID 1 NewHP)}

					{System.show 'Player '#LocalID#' got shot at position '#Position#' has '#NewHP#' Remaining hp'}

					if NewHP == 0 then
						{SendToAll sayDeath(LocalID)}
					end

					playerState(id:LocalID position:Position hp:NewHP mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost)
				end 

				fun {ModCharge PlayerState}
					playerState(id:LocalID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag speedBoost:SpeedBoost) = PlayerState
					NewGunCharge NewMineCharge
				in
					if {Record.label FiredItem} == gun then
						NewGunCharge = 0
						NewMineCharge = MineReload
					elseif {Record.label FiredItem} == mine then
						NewGunCharge = GunReload
						NewMineCharge = 0
					else
						NewGunCharge = GunReload
						NewMineCharge = MineReload
					end
					playerState(id:LocalID position:Position hp:HP mineReload:NewMineCharge gunReload:NewGunCharge flag:Flag speedBoost:SpeedBoost)
				end 
			in
				CurrentPlayerState = {List.nth State.playersState ID.id}
				DistanceFromWeaponPos = {ManhattanDistance CurrentPlayerState.position FiredItem.pos}

				if {Record.label FiredItem} == gun then

					% if the player has enough charges to fire, then the player can fire the gun
					if CurrentPlayerState.gunReload == Input.gunCharge andthen DistanceFromWeaponPos =< 2 andthen DistanceFromWeaponPos > 0  andthen CurrentPlayerState.hp > 0 then

						{SendToAll sayShoot(ID FiredItem.pos)}
						{System.show 'Player ID '#ID#' fired a gun at '#FiredItem.pos}

						% check for mines and detonate them if they were shot
						HasMineExploded = {CheckMineAtPosHelper State.mines FiredItem.pos 1}

						if HasMineExploded \= false then
							DmgState MinesNearby
						in
							mineExploded(MinePosition Index) = HasMineExploded
							{System.show 'Mine exploded when getting shot at, '#MinePosition}

							% remove the mine that exploded 
							DmgState = {AdjoinAt State mines {List.filter State.mines fun {$ Elem} Elem \= {List.nth State.mines Index} end}}
							
							{SendToAll sayMineExplode(mine(pos:MinePosition))}
							{Send WindowPort removeMine(mine(pos:MinePosition))}

							% check for other mines in the vicinity (chain reaction)
							MinesNearby = {List.filter DmgState.mines fun {$ Elem} {ManhattanDistance MinePosition Elem.pos} == 1 end}

							if {List.length MinesNearby} >= 1 then
								for I in MinesNearby do
									thread 
										% we wait for status to get bound here, so that we're sure that the state that we just changed above will be the state that all new messages get, including the message(s) that we're sending now
										{Wait Status}
										{Delay 500} % small delay to make the explosions look like a chain reaction
										% send a message to the gamecontroller in another thread to ask to make the mines nearby explode
										{Send GameControllerPort mineExploded(I _)}
									end
								end
							
							end
		

							% first apply the damage to the players, and then
							NewStateMineExplosion = {AdjoinAt DmgState playersState {ApplyDmgIfInRange DmgState.playersState MinePosition}}
							% NewStateMineExplosion = {AdjoinAt DmgState mines {RemoveMine DmgState.mines FiredItem}}
							
						else
							NewStateMineExplosion = State
						end

						local
							PlayersShotState
						in
							% check if there is any players at the position, if so, apply 1 dmg
							PlayersShotState = {AdjoinAt NewStateMineExplosion playersState {ShootPlayerAtPos NewStateMineExplosion.playersState FiredItem.pos ModHp}}
							% also remove the charge from the player that shot the gun
							OutputState = {AdjoinAt PlayersShotState playersState {PlayerStateModification PlayersShotState.playersState ID ModCharge}}
						end


						Status = true
					else
						% the player cannot fire the gun yet or is too far or player is dead
						OutputState = State
						Status = false
					end
					
				elseif {Record.label FiredItem} == mine then
					
					% if the player has enough charge for the mine and the player is at the same position as the mine that he wants to place
					if CurrentPlayerState.mineReload == Input.mineCharge andthen DistanceFromWeaponPos == 0 andthen CurrentPlayerState.hp > 0 then

						%  check that no other mines were placed there before
						if {List.member FiredItem State.mines} == false then

							% notify everyone that a mine was placed
							{SendToAll sayMinePlaced(ID FiredItem)}
							{Send WindowPort putMine(FiredItem)}
							{System.show 'Player ID '#ID#' placed a mine at position'#FiredItem.pos}

							% add the mine to the state and change the player's charge for the mine
							OutputState = {AdjoinAt {AdjoinAt State mines FiredItem|State.mines} playersState {PlayerStateModification State.playersState ID ModCharge}}
							Status = true
						else
							OutputState = State
							Status = false
						end

					else
						Status = false
						OutputState = State
					end

				else % else it was null, so do nothing
					Status = false
					OutputState = State
				end
				
				OutputState
			end
		end

	in
		case Head 
			of nil then nil

			[] getPlayerHP(ID ?HP) then
				{GetPlayerHP State ID HP}

			[] getPlayersState(?List) then
				{GetPlayersState State List}

			[] setPlayersState(NewPlayersState) then
				{SetPlayersState State NewPlayersState}

			[] movePlayer(ID Position ?Status) then
				{MovePlayer State ID Position Status}

			[] killPlayer(ID) then
				{KillPlayer State ID}

			[] respawnPlayer(ID) then
				{RespawnPlayer State ID}
			
			[] sayDamageTaken(ID Damage LifeLeft) then 
				{SayDamageTaken State ID Damage LifeLeft}
			
			[] getMines(?Mines) then
				{GetMines State Mines}
			
			[] checkMineAtPos(Position ?HasMineExploded) then
				{CheckMineAtPos State Position HasMineExploded}
				
			[] mineExploded(Mine ?Status) then
				{MineExploded State Mine Status}

			[] chargeItem(ID Item ?Status) then
				{ChargeItem State ID Item Status}

			[] fireItem(ID FiredItem ?Status) then
				{FireItem State ID FiredItem Status}

			[] canGrabFlag(ID Flag ?Status) then
				{CheckCanGrabFlag State ID Flag ?Status}

			[] dropFlag(ID Flag ?Status) then
				{DropFlag State ID Flag Status}

			[] wasPlayerCarryingFlag(ID ?Flag ?Status) then
				{WasPlayerCarryingFlag State ID Flag Status}

			[] startFoodTimer(?TimerStatus) then
				{StartFoodTimer State ?TimerStatus}
				
			[] spawnFood() then
				{SpawnFood State}

			[] canEatFood(ID Food ?Status) then
				{CanEatFood State ID Food Status}

			[] startSpeedTimer(?TimerStatus) then
				{StartBoostTimer State speed TimerStatus}

			[] startAdrenalineTimer(?TimerStatus) then
				{StartBoostTimer State adrenaline TimerStatus}

			[] spawnSpeed() then
				{SpawnBoost speed State}

			[] spawnAdrenaline() then
				{SpawnBoost adrenaline State}

			[] canEatSpeed(ID Speed ?Status) then
				{CanEatBoost State ID Speed speed Status}

			[] canEatAdrenaline(ID Adrenaline ?Status) then
				{CanEatBoost State ID Adrenaline adrenaline Status}

			[] removeSpeedBoost(ID) then
				{RemoveBoost State ID speed}

			[] removeAdrenalineBoost(ID) then
				{RemoveBoost State ID adrenaline}
		end
	end

	% PlayerStateModification is used to apply a function on PlayerState for a specific ID, it returns the modified state
	fun {PlayerStateModification PlayersState WantedID Function}
		case PlayersState
		of nil then nil
		[] playerState(id:ID position:_ hp:_ mineReload:_ gunReload:_ flag:_ speedBoost:_)|T then
			if (ID.id == WantedID.id) then
				{Function PlayersState.1}|T
			else 
				PlayersState.1|{PlayerStateModification T WantedID Function}
			end
		end
	end


	%%%% MAIN


    fun {DoListPlayer Players Colors ID}
		case Players#Colors
		of nil#nil then nil
		[] (Player|NextPlayers)#(Color|NextColors) then
			player(ID {PlayerManager.playerGenerator Player Color ID})|
			{DoListPlayer NextPlayers NextColors ID+1}
		end
	end


	% The distance between two points measured along axes at right angles. In a plane with p1 at (x1, y1) and p2 at (x2, y2), it is |x1 - x2| + |y1 - y2|. 
	fun {ManhattanDistance P1 P2}
		{Abs (P1.x - P2.x)} + {Abs (P1.y - P2.y)}
	end

	% send a message to all players
	proc {SendToAll Message} 
		for Nbr in 1..Input.nbPlayer do
			{Send {List.nth PlayersPorts Nbr}.2 Message}
		end
	end

	proc {PlayTurn PlayerPort ID TurnStep}
		case TurnStep
		of nil then skip
		[] step1 then
			local
				HP NewPlayersStateList
			in
				{PrintSteps step1#ID}
				%%%%%% STEP 1: if the player is dead, then update the GUI and send to all players that player#ID is dead
				%%%%%% wait for respawnDelay and then set the player's life count back to startHealth, 
				%%%%%% reset the player's position and broadcast that player#ID is alive with startHealth HP


				{Send GameControllerPort getPlayerHP(ID HP)}
				{Wait HP}

				if HP == 0 then
					Flag WasCarryingFlagStatus DropFlagStatus
				in
					{Send GameControllerPort wasPlayerCarryingFlag(ID Flag WasCarryingFlagStatus)}
					{Wait Flag}
					{Wait WasCarryingFlagStatus}
					if WasCarryingFlagStatus andthen Flag \= null then
						{System.show 'Player ID '#ID#' dropped the flag'#Flag#' when dying'}
						
						{Send GameControllerPort dropFlag(ID Flag DropFlagStatus)}

						if DropFlagStatus then
							{SendToAll sayFlagDropped(ID Flag)}
							{Send WindowPort putFlag(Flag)}
							{Send WindowPort removeSoldierHasFlag(ID)}
						else
							{System.show 'Player ID'#ID#' cannot drop flag '#Flag}
						end
					end

					{System.show 'Player '#ID#' is dead'}

					% set the life to 0 on the gui, and then remove the soldier from the map
					{Send WindowPort removeSoldier(ID)}
					{Send WindowPort lifeUpdate(ID 0)}

					{Send GameControllerPort killPlayer(ID)}

					% broadcast that player#ID is dead
					{SendToAll sayDeath(ID)}

					{Delay Input.respawnDelay}

					{Send GameControllerPort respawnPlayer(ID)}

					% make the player respawn and then broadcast that 
					{Send PlayerPort respawn()}
					{SendToAll sayRespawn(ID)}

					% reset the position of the player
					
					{Send WindowPort initSoldier(ID {List.nth Input.spawnPoints ID.id})}
					{Send WindowPort lifeUpdate(ID Input.startHealth)}
				else
					% player is alive, do nothing
					skip
				end

				{PlayTurn PlayerPort ID step234}
			end
		[] step234 then
			local	
				% list of variables used in step 2, 3, and 4
				NewPos PlayerID  HasMineExploded HasPlayerDied MoveStatus
			in
				%%%%%% STEP 2: if the player is alive ask where it wants to go
				{PrintSteps 'step 2'#ID}

				{Send PlayerPort move(PlayerID NewPos)}
				{Wait NewPos}

				%%%%%% STEP 3: check if the position the player wants to move to is a valid move, if it is not, the position stays the same,
				%%%%%% otherwise notify everyone of the player's new position
				{PrintSteps 'step 3'#ID}

				{Send GameControllerPort movePlayer(PlayerID NewPos MoveStatus)}
				{Wait MoveStatus}

				% if the move is valid, then broadcast the movement and continue on with step 4
				if MoveStatus then
					{SendToAll sayMoved(PlayerID NewPos)}
					{Send WindowPort moveSoldier(PlayerID NewPos)}

					%%%%%% STEP 4: check if the player has moved on a mine
					%%%%%% If so, apply the damage and notify everyone that the mine has exploded and notify everyone for each player that took damage.
					%%%%%% If a player dies as a result, notify everyone and skip the rest of the ”turn” for that player.
					{PrintSteps 'step 4'#ID}
					
					{Send GameControllerPort checkMineAtPos(NewPos HasMineExploded)}
					{Wait HasMineExploded}

					if HasMineExploded \= false then % HasMineExploded is a tuple when a mine has exploded and it's false when no mines exploded
						% player moved on a mine
						
						% a mine deals 2 dmg to any player on the tile and 1 dmg to players within a 1 tile radius (following manhattan distance)
						local
							MinePosition Index NewState Status
						in
							% destructure the tuple returned to get the mine that exploded
							mineExploded(MinePosition Index) = HasMineExploded

							{System.show 'Mine exploded'#MinePosition}

							{Send GameControllerPort mineExploded(mine(pos:MinePosition) Status)}
							{Wait Status}
						end
					end


					local FoodStatus SpeedStatus AdrenalineStatus in
						% check to see if the player can eat food at the new position, if they can, the food is removed and they gain 1 HP
						{Send GameControllerPort canEatFood(ID food(pos: NewPos) FoodStatus)}
						{Wait FoodStatus}
						if FoodStatus then
							{SendToAll sayFoodEaten(ID food(pos: NewPos))}
							{System.show 'Player ID'#ID#' ate food and gained 1 hp'}
						end

						{Send GameControllerPort canEatSpeed(ID speed(pos: NewPos) SpeedStatus)}
						{Wait SpeedStatus}
						if SpeedStatus then
							{Send PlayerPort saySpeedBoostTaken()} % the game controller takes care of sending the delayed message that removes the boost
							{System.show 'Player ID'#ID#' go the speed boost and gained 1 tile movement speed for 5 seconds'}
						end

						{Send GameControllerPort canEatAdrenaline(ID adrenaline(pos: NewPos) AdrenalineStatus)}
						{Wait AdrenalineStatus}
						if AdrenalineStatus then
							{Send PlayerPort sayAdrenalineTaken()} % the game controller takes care of sending the delayed message that removes the boost
							{System.show 'Player ID'#ID#' go the adrenaline boost and gained 2 hp for 5 seconds'}
						end
					end

					
				end

				local
					HP
				in
					{Send GameControllerPort getPlayerHP(ID HP)}
					{Wait HP}
					if HP == 0 then
						% if the current player died, then skip the rest of the turn
						{PlayTurn PlayerPort ID endTurn}
					else
						% continue the turn as usual if the player isn't dead
						{PlayTurn PlayerPort ID step5}
					end
				end
			end
		[] step5 then
			{PrintSteps step5#ID}
			
			%%%%%% STEP 5: ask the player what weapon it wants to charge (gun or mine)

			local
				PlayerID KindOfWeapon Status
			in
				{Send PlayerPort chargeItem(PlayerID KindOfWeapon)}
				{Wait KindOfWeapon}

				if KindOfWeapon == null then
					% player doesn't want to charge a gun or mine, so skip
					skip
				else
					% charge the item
					{Send GameControllerPort chargeItem(ID KindOfWeapon Status)}
					{Wait Status}
					
					% broadcast to all players (including this player) that his gun/mine was charged by 1
					{SendToAll sayCharge(ID KindOfWeapon)}
					
				end
			end

			{PlayTurn PlayerPort ID step6}

		[] step6 then
			{PrintSteps step6#ID}

			%%%%%% STEP 6: Ask the player what weapon it wants to use (place a mine or shoot at something). Check if the player
			%%%%%% can indeed use that weapon, and if so send a message notifying everyone, then reset the charge counter
			%%%%%% to 0 for that weapon. If a mine is exploded as a result, notify everyone that it has exploded and apply
			%%%%%% the damage. If a player has been shot, notify everyone.
			
			local
				PlayerID KindOfWeaponToFire Status
			in
				{Send PlayerPort fireItem(PlayerID KindOfWeaponToFire)}
				{Wait KindOfWeaponToFire}

				if KindOfWeaponToFire \= null then
					% check that the player can fire the weapon and fire it,...
					{Send GameControllerPort fireItem(ID KindOfWeaponToFire Status)}
					{Wait Status}

					if Status then
						{System.show 'Player '#ID#' Fired a gun/placed a mine'}
					end
				else
					% the player doesn't want to fire any weapon, so skip
					skip
				end
				
			end

			{PlayTurn PlayerPort ID step7}

		[] step7 then
			{PrintSteps step7#ID}

			%%%%%% STEP 7: Ask the player if it wants to grab the flag (only if it is possible).
			%%%%%% Notify everyone if the flag has been picked up.
			local
				Status PlayerID Flag
			in
				{Send PlayerPort takeFlag(PlayerID Flag)}
				{Wait Flag}

				if Flag \= null then
					{Send GameControllerPort canGrabFlag(ID Flag Status)}
					if Status then
						{SendToAll sayFlagTaken(PlayerID Flag)}
						{Send WindowPort removeFlag(Flag)}
						{Send WindowPort addSoldierHasFlag(ID)}
					else
						{System.show 'Player ID '#ID#' cannot grab flag'#Flag}
					end

				else
					% player doesn't want to grab the flag
					skip
				end
				
			end

			{PlayTurn PlayerPort ID step8}

		[] step8 then
			{PrintSteps step8#ID}

			%%%%%% STEP 8: if applicable, ask the player if they want to drop the flag. Notify everyone if they do.

			local
				Status PlayerID Flag
			in
				{Send PlayerPort dropFlag(PlayerID Flag)}
				{Wait Flag}

				% the player wants to drop the flag
				if Flag \= null then
					{Send GameControllerPort dropFlag(ID Flag Status)}
					if Status then
						{System.show 'Player ID '#ID#' has dropped the flag'#Flag#' at position '#Flag.pos}
						{SendToAll sayFlagDropped(ID Flag)}
						{Send WindowPort putFlag(Flag)}
						{Send WindowPort removeSoldierHasFlag(ID)}
					else
						{System.show 'Player ID'#ID#' cannot drop flag'#Flag}
					end
				end
				
			end

			
			{PlayTurn PlayerPort ID step9}

		[] step9 then
			{PrintSteps step9#ID}
			%%%%%% STEP 9: if a player has died, notify everyone and also notify them if the flag has been dropped as a result.

			local
				HP Flag WasCarryingFlagStatus DropFlagStatus
			in
				{Send GameControllerPort getPlayerHP(ID HP)}
				{Wait HP}
				if HP == 0 then
					{System.show 'Player '#ID#' is dead'}
					{SendToAll sayDeath(ID)}

					{Send GameControllerPort wasPlayerCarryingFlag(ID Flag WasCarryingFlagStatus)}
					{Wait Flag}
					{Wait WasCarryingFlagStatus}
					
					if WasCarryingFlagStatus andthen Flag \= null then
						{System.show 'Player ID '#ID#' dropped the flag'#Flag#' when dying'}
						
						{Send GameControllerPort dropFlag(ID Flag DropFlagStatus)}

						if DropFlagStatus then
							{SendToAll sayFlagDropped(ID Flag)}
							{Send WindowPort putFlag(Flag)}
							{Send WindowPort removeSoldierHasFlag(ID)}
						else
							% this shouldn't happen but who knows
							{System.show 'Player ID'#ID#' cannot drop flag '#Flag}
						end
					else
						skip % the player wasn't carrying any flags
					end
				end
			end
			
			
			{PlayTurn PlayerPort ID step10}

		[] step10 then
			{PrintSteps step10#ID}

			%%%%%% STEP 10: The game Controller is also responsible for spawning food randomly on the map after a random time
			%%%%%% between FoodDelayMin and FoodDelayMin has passed

			local
				Status
			in
				{Send GameControllerPort startFoodTimer(Status)}
				{Wait Status}

				if Status then
					{System.show 'Timer for food spawn started'}
				end
			end

			% Extension: speed boost (gives +1 tile movement for 5 seconds) and adrenaline boost (gives +2 hp for 5 seconds)

			local
				SpeedStatus
			in
				{Send GameControllerPort startSpeedTimer(SpeedStatus)}
				{Wait SpeedStatus}
				if SpeedStatus then
					{System.show 'Timer for speed spawn started'}
				end
			end

			local
				AdrenalineStatus
			in
				{Send GameControllerPort startAdrenalineTimer(AdrenalineStatus)}
				{Wait AdrenalineStatus}

				if AdrenalineStatus then
					{System.show 'Timer for adrenaline spawn started'}
				end
			end

			
			{PlayTurn PlayerPort ID endTurn}
		[] endTurn then
			{PrintSteps endTurn#ID}
		end
	end

	% this is the main loop for each thread
	proc {Main Port ID}
		{Wait ID}

		{PrintSteps startOfLoop(ID)}

		{PlayTurn Port ID step1}

		{PrintSteps endOfLoop(ID)}

		{Delay Input.guiDelay} % added a delay to make the GUI respond faster

		{Main Port ID}
	end

	proc {InitThreadForAll Players}
		case Players
		of nil then % all players have started, so start the game
			{Send WindowPort initSoldier(null pt(x:0 y:0))}
			{DrawFlags Input.flags WindowPort}
		[] player(_ Port)|Next then ID Position in
			{Send Port initPosition(ID Position)} % the player Binds ID and Position
			{Send WindowPort initSoldier(ID Position)} % draws the player #ID at position Position
			{Send WindowPort lifeUpdate(ID Input.startHealth)}
			thread
			 	{Main Port ID} % start the game loop for player #ID
			end
			{InitThreadForAll Next}
		end
	end

    thread
		GUIDoneBuilding
	in
		% Create port for window
		WindowPort = {GUI.portWindow}

		% Open window
		{Send WindowPort buildWindow(GUIDoneBuilding)}
		{System.show buildWindow}

		{Wait GUIDoneBuilding}

		GameControllerPort = {StartGameController}

        % Create port for players
		PlayersPorts = {DoListPlayer Input.players Input.colors 1}

		{InitThreadForAll PlayersPorts}
	end
end
