functor
import
	GUI
	Input
	PlayerManager
	System
	OS
define
	StartGameController
	TreatGameControllerStream
	MatchHead
	DoListPlayer
	InitThreadForAll
	PlayersPorts
	SendToAll
	SimulatedThinking
	Main
	WindowPort
	GameControllerPort
	PlayTurn
	InitPlayersState
	PlayerStateModification
	ManhattanDistance
	Max

	proc {DrawFlags Flags Port}
		case Flags of nil then
			{Send WindowPort putMine(mine(pos:pt(x:8 y:10)))} % TODO: REMOVE
		[] Flag|T then
			{Send Port putFlag(Flag)}
			{DrawFlags T Port}
		end
	end
in

	%%%% GAME CONTROLLER


	% InitPlayersState creates the state for all the players, returns a list of playerState tuples that contain ID, HP, Pos, Reloads, flag,...
	fun {InitPlayersState Nbr}
		if Nbr > Input.nbPlayer then
			nil
		else
			playerState(id:id(id:Nbr color:{List.nth Input.colors Nbr} name:_) position:{List.nth Input.spawnPoints Nbr} hp:Input.startHealth mineReload:0 gunReload:0 flag:null)|{InitPlayersState Nbr+1}
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
					mines:[mine(pos:pt(x:8 y:10))] 	% TODO: remove the mine, this is just for testing step 4
					flags:Input.flags 
					playersState:{InitPlayersState 1}
				)
			}
		end
		Port
	end


	% State is like state(miense:[mines] flags:[flags] playerState(id:id(id:Nbr color:Color) position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag))


	proc{TreatGameControllerStream Stream State}
		case Stream
			of H|T then {TreatGameControllerStream T {MatchHead H State}}
		end
	end

	fun {MatchHead Head State}

		fun {GetPlayersState State ?List}
			List = State.playersState
			State
		end

		fun {SetPlayersState State NewPlayersState}
			{AdjoinAt State playersState NewPlayersState}
		end

		fun {MovePlayer State ID Position}
			% modifies the position inside the playersState list
			fun {ModPos PlayerState}
				ID OldPosition HP MineReload GunReload Flag
			in
				playerState(id:ID position:OldPosition hp:HP mineReload:MineReload gunReload:GunReload flag:Flag) = PlayerState
				playerState(id:ID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag)
			end
			
		in

			% this returns a modified version of State where the playerState list in State (record) is replaced with the updated state 
			{AdjoinAt State playersState {PlayerStateModification State.playersState ID ModPos}}
		end


		fun {KillPlayer State ID}
			fun {ModDeath PlayerState}
				playerState(id:ID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag) = PlayerState
			in
				playerState(id:ID position:Position hp:0 mineReload:MineReload gunReload:GunReload flag:Flag)
			end 
		in

			{AdjoinAt State playersState {PlayerStateModification State.playersState ID ModDeath}}
		end


		fun {RespawnPlayer State ID}
			fun {ModHp PlayerState}
				playerState(id:ID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag) = PlayerState
				NewPos = {List.nth Input.spawnPoints ID.id}
			in
				playerState(id:ID position:NewPos hp:Input.startHealth mineReload:MineReload gunReload:GunReload flag:Flag)
			end 
		in
			{AdjoinAt State playersState {PlayerStateModification State.playersState ID ModHp}}
		end

		fun {SayDamageTaken State ID Damage LifeLeft}
			fun {ModHp PlayerState}
				playerState(id:ID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag) = PlayerState
			in
				playerState(id:ID position:Position hp:LifeLeft mineReload:MineReload gunReload:GunReload flag:Flag)
			end 
		in
			{AdjoinAt State playersState {PlayerStateModification State.playersState ID ModHp}}
		end

		%%% MINES

		fun {GetMines State ?Mines}
			Mines = State.mines
			State
		end

		fun {CheckMineAtPos State Position ?HasMineExploded}
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
		in
			HasMineExploded = {CheckMineAtPosHelper State.mines Position 1}
			State
		end

		fun {MineExploded State Mine ?Status}
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
				playerState(id:LocalID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag) = PlayerState
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

				playerState(id:LocalID position:Position hp:NewHp mineReload:MineReload gunReload:GunReload flag:Flag)
			end 

			% apply damage to all players based on the range from the mine
			fun {ApplyDmgIfInRange PlayersState MinePos}
				DistanceFromMine 
			in
				case PlayersState
				of nil then nil
				[] playerState(id:ID position:Position hp:_ mineReload:_ gunReload:_ flag:_)|T then
					% get the manhattan distance from the mine
					DistanceFromMine = {ManhattanDistance MinePos Position}
					{System.show 'Player '#ID#' at position'#Position#' is at distance '#DistanceFromMine#' from the mine at position '#MinePos}

					if DistanceFromMine == 0 then
						% the mine deals two dmg if the player stepped on the mine 
						{ApplyDmg PlayersState.1 2}|{ApplyDmgIfInRange T MinePos} % continue looking for other players possibly hurt
					elseif DistanceFromMine == 1 then
						% only deal one dmg if the player was in a one tile away
						{ApplyDmg PlayersState.1 1}|{ApplyDmgIfInRange T MinePos}
					else
						% dont apply dmg, the player was too far away from the explosion
						PlayersState.1|{ApplyDmgIfInRange T MinePos}
					end
				end
			end

			NewState
		in
			NewState = {AdjoinAt State playersState {ApplyDmgIfInRange State.playersState Mine.pos}}
			{System.show 'New state after applying damage'#NewState}
			Status = true
			{AdjoinAt NewState mines {RemoveMine NewState.mines Mine}}
		end

	in
		case Head 
			of nil then nil
			[] getPlayersState(?List) then
				{GetPlayersState State List}

			[] setPlayersState(NewPlayersState) then
				{SetPlayersState State NewPlayersState}

			[] movePlayer(ID Position) then
				{MovePlayer State ID Position}

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
		end
	end

	% PlayerStateModification is used to apply a function on PlayerState for a specific ID, it returns the modified state
	fun {PlayerStateModification PlayersState WantedID Function}
		case PlayersState
		of nil then nil
		[] playerState(id:ID position:_ hp:_ mineReload:_ gunReload:_ flag:_)|T then
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

	fun {Max X Y}
		if X > Y then X else Y end
	end

	SimulatedThinking = proc{$} {Delay ({OS.rand} mod (Input.thinkMax - Input.thinkMin) + Input.thinkMin)} end

	% The distance between two points measured along axes at right angles. In a plane with p1 at (x1, y1) and p2 at (x2, y2), it is |x1 - x2| + |y1 - y2|. 
	fun {ManhattanDistance P1 P2}
		{Abs (P1.x - P2.x)} + {Abs (P1.y - P2.y)}
	end

	% send a message to all players
	proc {SendToAll Message} 
	% 	PlayersStateList
	% in
		
		% {Send GameControllerPort getPlayersState(PlayersStateList)}
		% {Wait PlayersStateList}

		for Nbr in 1..Input.nbPlayer do
			{Send {List.nth PlayersPorts Nbr}.2 Message}
			
			% send to all alive players
			% if {List.nth PlayersStateList Nbr}.hp \= 0 then
			% 	{Send {List.nth PlayersPorts Nbr}.2 Message}
			% else 
			% 	skip
			% end
		end
	end

	proc {PlayTurn PlayerPort ID TurnStep}
		case TurnStep
		of nil then skip
		[] step1 then
			PlayersStateList NewPlayersStateList
		in

			{System.show step1#ID}
			% if the player is dead, then update the GUI and send to all players that player#ID is dead
			% wait for respawnDelay and then set the player's life count back to startHealth, 
			% reset the player's position and broadcast that player#ID is alive with startHealth HP


			{Send GameControllerPort getPlayersState(PlayersStateList)}
			{Wait PlayersStateList}

			if {List.nth PlayersStateList ID.id}.hp == 0 then
				{System.show isDead(ID)}

				% set the life to 0 on the gui, and then remove the soldier from the map
				{Send WindowPort lifeUpdate(ID 0)}
				{Send WindowPort removeSoldier(ID)}

				% broadcast that player#ID is dead
				{SendToAll sayDeath(ID)}

				{Delay Input.respawnDelay}

				% make the player respawn and then broadcast that 
				{Send PlayerPort respawn()}
				{SendToAll sayRespawn(ID)}

				% reset the position of the player
				{Send GameControllerPort respawnPlayer(ID)}

				{Send GameControllerPort getPlayersState(NewPlayersStateList)}
				{Wait NewPlayersStateList}
				
				{Send WindowPort initSoldier(ID {List.nth NewPlayersStateList ID.id}.position)}
				{Send WindowPort lifeUpdate(ID {List.nth NewPlayersStateList ID.id}.hp)}
			
				
			else
				% player is alive, do nothing
				skip
			end

			{PlayTurn PlayerPort ID step234}

		[] step234 then
			% list of variables used in step 2, 3, and 4
			NewPos PlayerID CurrentPlayerState EnemyBaseTileNbr NewPosMapTileNbr HasMineExploded HasPlayerDied
			PlayersStateList NewPlayerStateList

		in
			{System.show 'step 2, 3, and 4'#ID}

			%%%%%% STEP 2: if the player is alive ask where it wants to go
			{Send PlayerPort move(PlayerID NewPos)}
			{Wait PlayerID}
			{Wait NewPos}

			% get the current state
			{Send GameControllerPort getPlayersState(PlayersStateList)}
			{Wait PlayersStateList}

			%%%%%% STEP 3: check if the position the player wants to move to is a valid move, if it is not, the position stays the same,
			%%%%%% otherwise notify everyone of the player's new position

			CurrentPlayerState = {List.nth PlayersStateList ID.id}

			% walls (3) and enemy base are impenetrable, player 1 is red (1) and player 2 is blue (2)
			EnemyBaseTileNbr = if ID.color == red then 2 else 1 end 

			% check that the position is in the map
			if (NewPos.x =< Input.nRow) andthen (NewPos.y =< Input.nColumn) andthen (NewPos.x > 0) andthen (NewPos.y > 0) then
				
				% get the tile number for the new position, this is the integer as defined in Input.oz
				% 0 = Empty
				% 1 = Player 1's base (red)
				% 2 = Player 2's base (blue)
				% 3 = Walls
				NewPosMapTileNbr = {List.nth {List.nth Input.map NewPos.x} NewPos.y}

				% check that the player isn't moving more than one tiles in both directions, and that he isn't moving onto a wall or onto the enemy base
				if {Abs (CurrentPlayerState.position.x - NewPos.x)} =< 1 andthen {Abs (CurrentPlayerState.position.y - NewPos.y)} =< 1 andthen (NewPosMapTileNbr \= 3) andthen (NewPosMapTileNbr \= EnemyBaseTileNbr) then
					
					% the move is valid, so broadcast it to everyone and update the state
					{Send GameControllerPort movePlayer(ID NewPos)}
					{SendToAll sayMoved(ID NewPos)}
					{Send WindowPort moveSoldier(ID NewPos)}
					
					
					%%%%%% STEP 4: check if the player has moved on a mine
					%%%%%% If so, apply the damage and notify everyone that the mine has exploded and notify everyone for each player that took damage.
					%%%%%% If a player dies as a result, notify everyone and skip the rest of the ”turn” for that player.
					
						{Send GameControllerPort checkMineAtPos(NewPos HasMineExploded)}
					{Wait HasMineExploded}

					% HasMineExploded = {CheckMineAtPos MinesList NewPos 1}
					if HasMineExploded \= false then % HasMineExploded is a tuple when a mine has exploded and it's false when no mines exploded
						% player moved on a mine
						
						% a mine deals 2 dmg to any player on the tile and 1 dmg to players within a 1 tile radius (following manhattan distance)
						local
							MinePosition Index NewState Status

							% % function that applies the damage to the player
							% fun {ApplyDmg PlayerState HpToRemove}
							% 	NewHp
							% 	playerState(id:LocalID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag) = PlayerState
							% in
							% 	NewHp = {Max HP-HpToRemove 0}

							% 	% broadcast that this player has taken damage
							% 	{Send GameControllerPort sayDamageTaken(LocalID HpToRemove NewHp)}

							% 	{Send WindowPort lifeUpdate(LocalID NewHp)}
							% 	{SendToAll sayDamageTaken(LocalID HpToRemove NewHp)}

							% 	if NewHp == 0 andthen LocalID.id == ID.id then
							% 		HasPlayerDied = true

							% 		{SendToAll sayDeath(LocalID)}
							% 		{Send GameControllerPort killPlayer(LocalID)}

							% 	elseif NewHp == 0 andthen LocalID.id \= ID.id then
							% 		if {IsDet HasPlayerDied} == false then
							% 			HasPlayerDied = false
							% 		else
							% 			skip
							% 		end

							% 		{SendToAll sayDeath(LocalID)}
							% 		{Send GameControllerPort killPlayer(LocalID)}

							% 	else 
							% 		if {IsDet HasPlayerDied} == false then
							% 			HasPlayerDied = false
							% 		else
							% 			skip
							% 		end
							% 	end

							% 	playerState(id:LocalID position:Position hp:NewHp mineReload:MineReload gunReload:GunReload flag:Flag)
							% end 

							% % apply damage to all players based on the range from the mine
							% fun {ApplyDmgIfInRange PlayersState MinePos}
							% 	DistanceFromMine 
							% in
							% 	case PlayersState
							% 	of nil then nil
							% 	[] playerState(id:ID position:Position hp:_ mineReload:_ gunReload:_ flag:_)|T then
							% 		% get the manhattan distance from the mine
							% 		DistanceFromMine = {ManhattanDistance MinePos Position}
							% 		{System.show 'Player '#ID#' at position'#Position#' is at distance '#DistanceFromMine#' from the mine at position '#MinePos}

							% 		if DistanceFromMine == 0 then
							% 			% the mine deals two dmg if the player stepped on the mine 
							% 			{ApplyDmg PlayersState.1 2}|{ApplyDmgIfInRange T MinePos} % continue looking for other players possibly hurt
							% 		elseif DistanceFromMine == 1 then
							% 			% only deal one dmg if the player was in a one tile away
							% 			{ApplyDmg PlayersState.1 1}|{ApplyDmgIfInRange T MinePos}
							% 		else
							% 			% dont apply dmg, the player was too far away from the explosion
							% 			PlayersState.1|{ApplyDmgIfInRange T MinePos}
							% 		end
							% 	end
							% end
						in
							% destructure the tuple returned to get the mine that exploded
							mineExploded(MinePosition Index) = HasMineExploded

							{System.show 'Mine exploded'#MinePosition}

							% get the latest state
							% {Send GameControllerPort getPlayersState(NewPlayerStateList)}
							% {Wait NewPlayerStateList}

							{Send GameControllerPort mineExploded(mine(pos:MinePosition) Status)}
							{Wait Status}

							{SendToAll sayMineExplode(mine(pos:MinePosition))}
							{Send WindowPort removeMine(mine(pos:MinePosition))}

							%% check if the current player died as a result of the explosion, if so, we'll skip the rest of the turn
							local
								PlayersStateAfterMineExplosion
							in
								{Send GameControllerPort getPlayersState(PlayersStateAfterMineExplosion)}
								{Wait PlayersStateAfterMineExplosion}
								if {List.nth PlayersStateAfterMineExplosion ID.id}.hp == 0 then
									HasPlayerDied = true
								else
									HasPlayerDied = false
								end
							end
							
							
							% NewState = {ApplyDmgIfInRange NewPlayerStateList MinePosition}

							% go through the players and find all the players that are near the mine and then set the new state
							% {Send GameControllerPort setPlayersState(NewState)}
						end
						
					else
						% player is ok
						HasPlayerDied = false
					end

				else
					% if the move is not valid then do nothing
					{System.show 'INVALID MOVE'#ID}
					HasPlayerDied = false
				end

			else
				{System.show 'Cannot move out of map'#ID}
				HasPlayerDied = false
			end

			if HasPlayerDied then
				% if the current player died, then skip the rest of the turn
				{PlayTurn PlayerPort ID endTurn}
			else
				% continue the turn as usual if the player isn't dead
				{PlayTurn PlayerPort ID step5}
			end
		[] step5 then
			{System.show step5#ID}
			% ask the player what weapon it wants to charge (gun or mine)
			{PlayTurn PlayerPort ID step6}

		[] step6 then
			{System.show step6#ID}
			% Ask the player what weapon it wants to use (place a mine or shoot at something). Check if the player
			% can indeed use that weapon, and if so send a message notifying everyone, then reset the charge counter
			% to 0 for that weapon. If a mine is exploded as a result, notify everyone that it has exploded and apply
			% the damage. If a player has been shot, notify everyone.
			{PlayTurn PlayerPort ID step7}

		[] step7 then
			{System.show step7#ID}
			% Ask the player if it wants to grab the flag (only if it is possible). Notify everyone if the flag has been picked up.
			{PlayTurn PlayerPort ID step8}

		[] step8 then
			{System.show step8#ID}
			% if applicable, ask the player if they want to drop the flag. Notify everyone if they do.
			{PlayTurn PlayerPort ID step9}

		[] step9 then
			{System.show step9#ID}
			% if a player has died, notify everyone and also notify them if the flag has been dropped as a result.
			{PlayTurn PlayerPort ID step10}

		[] step10 then
			{System.show step10#ID}
			% The game Controller is also responsible for spawning food randomly on the map after a random time
			% between FoodDelayMin and FoodDelayMin has passed
			{PlayTurn PlayerPort ID endTurn}
		[] endTurn then
			{System.show endTurn#ID}
		end
	end

	% this is the main loop for each thread
	proc {Main Port ID}
		{Wait ID}

		{System.show startOfLoop(ID)}

		{PlayTurn Port ID step1}

		{System.show endOfLoop(ID)}

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

		{Delay 500}

		{InitThreadForAll PlayersPorts}
	end
end
