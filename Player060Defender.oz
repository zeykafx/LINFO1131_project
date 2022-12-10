functor
import
	Input
	OS
	System
export
	portPlayer:StartPlayer
define
	% Vars
	MapWidth = {List.length Input.map}
    MapHeight = {List.length Input.map.1}

	% Functions
	StartPlayer
	TreatStream
	MatchHead

	% Message functions
	InitPosition
	Move
	SayMoved
	SayMineExplode
	SayDeath
	SayDamageTaken
	SayFoodAppeared
	SayFoodEaten
	SayFlagTaken
	SayFlagDropped
	ChargeItem
	SayCharge
	FireItem
	SayMinePlaced
	SayShoot
	TakeFlag
	DropFlag
	PlayerStateModification
	InitOtherPlayers
	Respawn
	SayRespawn
	SaySpeedBoostTaken
	SaySpeedBoostWoreOff
	SayAdrenalineTaken 
	SayAdrenalineWoreOff

	% Helper functions
	RandomInRange = fun {$ Min Max} Min+({OS.rand}mod(Max-Min+1)) end

	SimulatedThinking = proc{$} {Delay ({OS.rand} mod (Input.thinkMax - Input.thinkMin) + Input.thinkMin)} end


	% The distance between two points measured along axes at right angles. In a plane with p1 at (x1, y1) and p2 at (x2, y2), it is |x1 - x2| + |y1 - y2|. 
	fun {ManhattanDistance P1 P2}
		{Abs (P1.x - P2.x)} + {Abs (P1.y - P2.y)}
	end

	fun {GetMapPos X Y}
		{List.nth {List.nth Input.map X} Y}
	end

in
	fun {InitOtherPlayers Nbr}
		if Nbr > Input.nbPlayer then
			nil
		else
			playerState(id:id(id:Nbr color:{List.nth Input.colors Nbr} name:_) position:{List.nth Input.spawnPoints Nbr} hp:Input.startHealth mineReload:0 gunReload:0 flag:null)|{InitOtherPlayers Nbr+1}
		end
	end

	fun {StartPlayer Color ID}
		Stream
		Port
	in
		{NewPort Stream Port}
		thread
			{TreatStream
			 	Stream
				state(
					id:id(name:player060defender color:Color id:ID)
					position:{List.nth Input.spawnPoints ID}
					map:Input.map
					food:nil
					hp:Input.startHealth
					flag:null
					mineReloads:0
					gunReloads:0
					startPosition:{List.nth Input.spawnPoints ID}
					mines:nil
					friendyFlag: {List.filter Input.flags fun {$ Elem} Elem.color == Color end}.1
					enemyHasFlag: false
					speedBoost:false
					playersState:{InitOtherPlayers 1} % List of tuples that look like: playerState(id:ID position:pt(x:X y:Y) hp:HP mineReload:MineReload gunReload:GunReload flag:Flag) 
				)
			}
		end
		Port
	end

    proc{TreatStream Stream State}
        case Stream
            of H|T then {TreatStream T {MatchHead H State}}
        end
    end

	fun {MatchHead Head State}
        case Head 
            of initPosition(?ID ?Position) then {InitPosition State ID Position}
            [] move(?ID ?Position) then {Move State ID Position}
            [] sayMoved(ID Position) then {SayMoved State ID Position}
            [] sayMineExplode(Mine) then {SayMineExplode State Mine}
			[] sayFoodAppeared(Food) then {SayFoodAppeared State Food}
			[] sayFoodEaten(ID Food) then {SayFoodEaten State ID Food}
			[] chargeItem(?ID ?Kind) then {ChargeItem State ID Kind}
			[] sayCharge(ID Kind) then {SayCharge State ID Kind}
			[] fireItem(?ID ?Kind) then {FireItem State ID Kind}
			[] sayMinePlaced(ID Mine) then {SayMinePlaced State ID Mine}
			[] sayShoot(ID Position) then {SayShoot State ID Position}
            [] sayDeath(ID) then {SayDeath State ID}
            [] sayDamageTaken(ID Damage LifeLeft) then {SayDamageTaken State ID Damage LifeLeft}
			[] takeFlag(?ID ?Flag) then {TakeFlag State ID Flag}
			[] dropFlag(?ID ?Flag) then {DropFlag State ID Flag}
			[] sayFlagTaken(ID Flag) then {SayFlagTaken State ID Flag}
			[] sayFlagDropped(ID Flag) then {SayFlagDropped State ID Flag}

			%%%%% CUSTOM MESSAGES %%%%% 
			[] respawn() then {Respawn State}
			[] sayRespawn(ID) then {SayRespawn State ID}
			[] saySpeedBoostTaken() then {SaySpeedBoostTaken State}
			[] saySpeedBoostWoreOff() then {SaySpeedBoostWoreOff State}
			[] sayAdrenalineTaken() then {SayAdrenalineTaken State}
			[] sayAdrenalineWoreOff() then {SayAdrenalineWoreOff State}
			
			[] _ then % if no messages match, instead of crashing we just return the unmodified state
				{System.show 'Player ID'#State.id#' got an unknown message, ignoring...'} 
				State
        end
    end


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

	fun {InitPosition State ?ID ?Position}
		{SimulatedThinking}
		ID = State.id
		Position = State.startPosition
		State
	end

	% has custom defender logic
	fun {Move State ?ID ?Position}

		% returns true if the move to the new tile is valid, returns false otherwise
		fun {IsValidMove NewPos}
			EnemyBaseTileNbr NewPosMapTileNbr OtherPlayersAtPos NearestMines
		in
			if (NewPos.x =< Input.nRow) andthen (NewPos.y =< Input.nColumn) andthen (NewPos.x > 0) andthen (NewPos.y > 0) then
				% get the enemy base tile nbr
				EnemyBaseTileNbr = if State.id.color == red then 2 else 1 end 
				% get the new pos tile nbr
				NewPosMapTileNbr = {GetMapPos NewPos.x NewPos.y}
				% check if there another player at the new pos
				OtherPlayersAtPos = {List.filter State.playersState fun {$ Elem} Elem.position == NewPos andthen Elem.id \= State.id andthen Elem.hp > 0 end}	

				% check if we will step into a mine
				NearestMines = {List.filter State.mines fun {$ Mine} {ManhattanDistance Mine.pos NewPos} == 0 end}

				if {ManhattanDistance State.position NewPos} =< MaxTravelDistance
					andthen (NewPosMapTileNbr \= 3) 
						andthen (NewPosMapTileNbr \= EnemyBaseTileNbr) 
							andthen {List.length OtherPlayersAtPos} == 0 
								andthen {List.length NearestMines} == 0 then
					true
				else
					false
				end
				
			else
				false
			end
		end

		Pos DX DY MaxTravelDistance
	in
		{SimulatedThinking}
		ID = State.id

		Pos = State.position

		MaxTravelDistance = if State.speedBoost == true then 2 else 1 end

		% make the defenders stay near the friendly flag, or near the friendly with the flag
		if State.enemyHasFlag == false then
			DX = State.friendyFlag.pos.x - Pos.x
			DY = State.friendyFlag.pos.y - Pos.y	
		
		else
			% make the player go to the friendly that is carrying the flag
			FriendlyWithFlagPos
		in
			FriendlyWithFlagPos = {List.filter State.playersState fun {$ Elem} Elem.flag \= null andthen Elem.id \= State.id andthen Elem.hp > 0 end}.1.position

			DX = FriendlyWithFlagPos.x - Pos.x
			DY = FriendlyWithFlagPos.y - Pos.y	
		end

		if DX < 0 andthen {IsValidMove {AdjoinAt Pos x Pos.x - MaxTravelDistance}} then

			Position = {AdjoinAt Pos x Pos.x - MaxTravelDistance}

		elseif DX > 0 andthen {IsValidMove {AdjoinAt Pos x Pos.x + MaxTravelDistance}} then

			Position = {AdjoinAt Pos x Pos.x + MaxTravelDistance}

		elseif DY < 0 andthen {IsValidMove {AdjoinAt Pos y Pos.y - MaxTravelDistance}} then

			Position = {AdjoinAt Pos y Pos.y - MaxTravelDistance}

		elseif DY > 0 andthen {IsValidMove {AdjoinAt Pos y Pos.y + MaxTravelDistance}} then

			Position = {AdjoinAt Pos y Pos.y + MaxTravelDistance}

		else 
			NearestMines SafeDirectionX SafeDirectionY
		in
			NearestMines = {List.filter State.mines fun {$ Mine} {ManhattanDistance Mine.pos Pos} == MaxTravelDistance end}


			if {List.length NearestMines} > 0 then
				SafeDirectionX = NearestMines.1.pos.x - Pos.x
				SafeDirectionY = NearestMines.1.pos.y - Pos.y
			else
				SafeDirectionX = 1
				SafeDirectionY = 1
			end


			% it seems like we are stuck....
			% try to move in a random direction, it doesn't matter if it's not valid, we'll try again next round, and again, until we're not stuck anymore
			case {OS.rand} mod 4
			of 0 then
				% avoid mines, we check SafeDirectionX since this random move was going to make the player move up in the X axis
				if SafeDirectionX \= 0 then
					Position = {AdjoinAt Pos y if Pos.y + MaxTravelDistance == Input.nColumn then Pos.y - MaxTravelDistance else Pos.y + MaxTravelDistance end}
				else
					Position = {AdjoinAt Pos x Pos.x + MaxTravelDistance}
				end
			[] 1 then
				if SafeDirectionX \= 0 then
					Position = {AdjoinAt Pos y if Pos.y + MaxTravelDistance == Input.nColumn then Pos.y - MaxTravelDistance else Pos.y + MaxTravelDistance end}
				else
					Position = {AdjoinAt Pos x Pos.x - MaxTravelDistance}
				end
			[] 2 then
				if SafeDirectionY \= 0 then
					Position = {AdjoinAt Pos x if Pos.x + MaxTravelDistance == Input.nRow then Pos.x - MaxTravelDistance else Pos.x + MaxTravelDistance end}
				else
					Position = {AdjoinAt Pos y Pos.y + MaxTravelDistance}
				end
			[] 3 then
				if SafeDirectionY \= 0 then
					Position = {AdjoinAt Pos x if Pos.x + MaxTravelDistance == Input.nRow then Pos.x - MaxTravelDistance else Pos.x + MaxTravelDistance end}
				else
					Position = {AdjoinAt Pos y Pos.y - MaxTravelDistance}
				end
			end
			
		end


		State
	end

	fun {SayMoved State ID Position}
		NewState
		% modifies the position inside the playersState list
		fun {ModPos PlayerState}
			playerState(id:ID position:_ hp:HP mineReload:MineReload gunReload:GunReload flag:Flag) = PlayerState
		in
			playerState(id:ID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag)
		end
		
	in
		% if the player that moved is the the current player, then also change the position in the state
		if ID.id == State.id.id then
			NewState = {AdjoinAt State position Position}
		else
			NewState = State
		end

		% this returns a modified version of State where the playerState list in State (record) is replaced with the updated state 
		{AdjoinAt NewState playersState {PlayerStateModification State.playersState ID ModPos}}
	end

	fun {SayMineExplode State Mine}
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
	in
		% remove the mine from the mine list
		{AdjoinAt State mines {RemoveMine State.mines Mine}}
	end

	fun {SayFoodAppeared State Food}
		{AdjoinAt State food Food|State.food}
	end

	fun {SayFoodEaten State ID Food}
		fun {ModHp PlayerState}
			playerState(id:ID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag) = PlayerState
		in
			playerState(id:ID position:Position hp:HP+1 mineReload:MineReload gunReload:GunReload flag:Flag)
		end 
		OutputState FoodRemovedState
	in
		FoodRemovedState = {AdjoinAt State food {List.filter State.food fun {$ Elem} Elem \= Food end}}

		if ID.id == State.id.id then
			OutputState = {AdjoinAt FoodRemovedState hp State.hp+1}
		else
			OutputState = FoodRemovedState
		end
		{AdjoinAt OutputState playersState {PlayerStateModification OutputState.playersState ID ModHp}}
	end

	fun {ChargeItem State ?ID ?Kind} 
		{SimulatedThinking}

		ID = State.id
		if State.mineReloads < Input.mineCharge then
			Kind = mine
		elseif State.gunReloads < Input.gunCharge then
			Kind = gun
		else
			Kind = null
		end
		State
	end

	fun {SayCharge State ID Kind}
		fun {ModCharge PlayerState}
			playerState(id:LocID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag) = PlayerState
			NewGunReload NewMineReload
		in
			if Kind == gun then
				NewGunReload = {Min GunReload+1 Input.gunCharge}
				NewMineReload = MineReload
			else
				NewGunReload = GunReload
				NewMineReload = {Min MineReload+1 Input.mineCharge}
			end

			% update the mine/gun reload
			playerState(id:LocID position:Position hp:HP mineReload:NewMineReload gunReload:NewGunReload flag:Flag)
		end 
		NewState
	in
		% this player charged their gun or mine
		if ID.id == State.id.id then
			% increase the state charge counter
			if Kind == gun then
				NewState = {AdjoinAt State gunReloads State.gunReloads+1}
			else
				NewState = {AdjoinAt State mineReloads State.mineReloads+1}
			end
		else
			NewState = State
		end
		% also modify the charge in the playersState list
		{AdjoinAt NewState playersState {PlayerStateModification NewState.playersState ID ModCharge}}

	end

	% has custom defender logic
	fun {FireItem State ?ID ?Kind}
		NearestPlayers
	in
		{SimulatedThinking}

		ID = State.id

		% the defenders won't shoot at mines but they will drop mines near the friendly flag

		% find the nearest player that is within two tiles
		NearestPlayers = {List.filter State.playersState fun {$ Elem} {ManhattanDistance Elem.position State.position} =< 2 andthen Elem.id.color \= State.id.color andthen Elem.hp > 0 end}
		
		if State.gunReloads == Input.gunCharge andthen {List.length NearestPlayers} >= 1 then

			Kind = gun(pos:NearestPlayers.1.position)

		% place mines around the flag
		elseif State.mineReloads == Input.mineCharge andthen {OS.rand} mod 5 == 0 andthen State.friendyFlag \= null andthen {ManhattanDistance State.position State.friendyFlag.pos} =< 5 then % dont place mines too often
			Kind = mine(pos: State.position)
		else
			Kind = null
		end
	
		State
	end

	fun {SayMinePlaced State ID Mine}
		fun {ModCharge PlayerState}
			playerState(id:ID position:Position hp:HP mineReload:_ gunReload:GunReload flag:Flag) = PlayerState
		in
			playerState(id:ID position:Position hp:HP mineReload:0 gunReload:GunReload flag:Flag)
		end 
		OutputState
	in
		if ID.id == State.id.id then
			OutputState = {AdjoinAt State mineReloads 0}
		else 
			OutputState = State 
		end

		% add the mine to the list of mines and change the charge of the player that placed the mine
		{AdjoinAt {AdjoinAt OutputState mines Mine|State.mines} playersState {PlayerStateModification OutputState.playersState ID ModCharge}}
	end

	fun {SayShoot State ID Position}
		% reset the charges
		fun {ModCharge PlayerState}
			playerState(id:LocalID position:Position hp:HP mineReload:MineReload gunReload:_ flag:Flag) = PlayerState
		in
			playerState(id:LocalID position:Position hp:HP mineReload:MineReload gunReload:0 flag:Flag)
		end 
		OutputState
	in
		% reset this player's charge
		if ID.id == State.id.id then
			OutputState = {AdjoinAt State gunReloads 0}
		else 
			OutputState = State 
		end
		
		% reset the charge of the player in the list
		{AdjoinAt OutputState playersState {PlayerStateModification OutputState.playersState ID ModCharge}}
	end

	fun {SayDeath State ID}
		fun {ModDeath PlayerState}
			playerState(id:ID position:Position hp:_ mineReload:MineReload gunReload:GunReload flag:Flag) = PlayerState
		in
			playerState(id:ID position:Position hp:0 mineReload:MineReload gunReload:GunReload flag:null)
		end
		OutputState 
	in
		if ID.id == State.id.id then
			OutputState = {AdjoinAt State hp 0}
		else
			OutputState = State
		end

		{AdjoinAt OutputState playersState {PlayerStateModification OutputState.playersState ID ModDeath}}
	end

	fun {SayDamageTaken State ID Damage LifeLeft}
		fun {ModHp PlayerState}
			playerState(id:ID position:Position hp:_ mineReload:MineReload gunReload:GunReload flag:Flag) = PlayerState
		in
			playerState(id:ID position:Position hp:LifeLeft mineReload:MineReload gunReload:GunReload flag:Flag)
		end 
		OutputState 
	in
		if ID.id == State.id.id then
			OutputState = {AdjoinAt State hp LifeLeft}
		else
			OutputState = State
		end
		{AdjoinAt OutputState playersState {PlayerStateModification OutputState.playersState ID ModHp}}
    end

	% has custom defender logic
	fun {TakeFlag State ?ID ?Flag}
		{SimulatedThinking}
		ID = State.id

		% defenders will never grab the flag
		Flag = null
		
		State
	end
			
	fun {DropFlag State ?ID ?Flag}
		BaseColor = if State.id.color == red then 1 else 2 end 
	in
		{SimulatedThinking}
		ID = State.id
		if State.flag \= null andthen {GetMapPos State.position.x State.position.y} == BaseColor then
			Flag = {AdjoinAt State.flag pos State.position}
		else
			Flag = null
		end

		State
	end

	% has custom defender logic
	fun {SayFlagTaken State ID Flag}
		fun {ModFlag PlayerState}
			playerState(id:ID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:_) = PlayerState
		in
			playerState(id:ID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag)
		end 
		OutputState FlagState
	in
		% if this player is carrying the flag
		if ID == State.id then
			OutputState = {AdjoinAt State flag Flag}
		
		else
			OutputState = State
		end

		% if an enemy is carrying the flag
		if ID.color \= State.id.color then 
			% remove the enemy flag from the list since the flag is currently being carried by another player and is therefore not at the original position anymore
			FlagState = {AdjoinAt {AdjoinAt OutputState friendyFlag null} enemyHasFlag true}

		else 
			% if a friendly is carrying the flag
			FlagState = OutputState 
		end

		{AdjoinAt FlagState playersState {PlayerStateModification FlagState.playersState ID ModFlag}}
	end

	% has custom defender logic
	fun {SayFlagDropped State ID Flag}
		fun {ModFlag PlayerState}
			playerState(id:ID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:_) = PlayerState
		in
			playerState(id:ID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:null)
		end 
		OutputState FlagState
	in
		if ID == State.id then
			OutputState = {AdjoinAt State flag null}
		else
			OutputState = State
		end

		if ID.color \= State.id.color then
			FlagState = {AdjoinAt {AdjoinAt OutputState friendyFlag Flag} enemyHasFlag false}
		else
			FlagState = OutputState
		end
	
		{AdjoinAt FlagState playersState {PlayerStateModification FlagState.playersState ID ModFlag}}
	end

	fun {Respawn State}
		fun {ModHp PlayerState}
			playerState(id:ID position:_ hp:_ mineReload:MineReload gunReload:GunReload flag:Flag) = PlayerState
		in
			playerState(id:ID position:State.startPosition hp:Input.startHealth mineReload:MineReload gunReload:GunReload flag:Flag)
		end
		NewState
	in
		NewState = {AdjoinAt {AdjoinAt State hp Input.startHealth} position State.startPosition}
		{AdjoinAt NewState playersState {PlayerStateModification NewState.playersState NewState.id ModHp}}
	end

	fun {SayRespawn State ID}
		fun {ModHp PlayerState}
			playerState(id:ID position:_ hp:_ mineReload:MineReload gunReload:GunReload flag:Flag) = PlayerState
			NewPos = {List.nth Input.spawnPoints ID.id}
		in
			playerState(id:ID position:NewPos hp:Input.startHealth mineReload:MineReload gunReload:GunReload flag:Flag)
		end 
	in
		if ID \= State.id then
			{AdjoinAt State playersState {PlayerStateModification State.playersState ID ModHp}}
		else
			State
		end
	end

	fun {SaySpeedBoostTaken State}
		{AdjoinAt State speedBoost true}
	end

	fun {SaySpeedBoostWoreOff State}
		{AdjoinAt State speedBoost false}
	end

	fun {SayAdrenalineTaken State} 
		% wrap in try catch to make it work with other groups that might have not defined adrenalineBoostHP (since it's an extension)
		try
			{AdjoinAt State hp State.hp+Input.adrenalineBoostHP}
		catch _ then
			{AdjoinAt State hp State.hp+2}
		end
	end

	fun {SayAdrenalineWoreOff State} 
		try
			{AdjoinAt State hp State.hp-Input.adrenalineBoostHP}
		catch _ then
			{AdjoinAt State hp State.hp-2}
		end
	end
end
