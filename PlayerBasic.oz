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

	% Helper functions
	RandomInRange = fun {$ Min Max} Min+({OS.rand}mod(Max-Min+1)) end

	SimulatedThinking = proc{$} {Delay ({OS.rand} mod (Input.thinkMax - Input.thinkMin) + Input.thinkMin)} end


	% The distance between two points measured along axes at right angles. In a plane with p1 at (x1, y1) and p2 at (x2, y2), it is |x1 - x2| + |y1 - y2|. 
	fun {ManhattanDistance P1 P2}
		{Abs (P1.x - P2.x)} + {Abs (P1.y - P2.y)}
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
					id:id(name:basic color:Color id:ID)
					position:{List.nth Input.spawnPoints ID}
					map:Input.map
					food:nil
					hp:Input.startHealth
					flag:null
					mineReloads:0
					gunReloads:0
					startPosition:{List.nth Input.spawnPoints ID}
					mines:nil
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
			[] sayFlagDropped(ID Flag) then {SayFlagDropped State ID flag}
			[] respawn() then {Respawn State}
			[] sayRespawn(ID) then {SayRespawn State ID}
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

	fun {Move State ?ID ?Position}
		Pos NearestEnemyFlag PosX PosY DX DY
	in
		{SimulatedThinking}
		ID = State.id
		Pos = State.position

		NearestEnemyFlag = {List.filter Input.flags fun {$ Elem} Elem.color \= State.id.color end}.1
		
		DX = NearestEnemyFlag.pos.x - Pos.x
		DY = NearestEnemyFlag.pos.y - Pos.y

		if DX < 0 then
			NewPos
		in
			NewPos = {AdjoinAt Pos x Pos.x - 1}
			if {List.nth {List.nth Input.map NewPos.x} NewPos.y} == 3 then
				PosX = {AdjoinAt NewPos x NewPos.x + 1}
			else
				PosX = NewPos
			end

		elseif DX > 0 then
			NewPos
		in
			NewPos = {AdjoinAt Pos x Pos.x + 1}
			if {List.nth {List.nth Input.map NewPos.x} NewPos.y} == 3 then
				PosX = {AdjoinAt NewPos x NewPos.x - 1}
			else
				PosX = NewPos
			end
		else PosX = Pos end


		if DY < 0 then
			NewPos
		in
			NewPos = {AdjoinAt PosX y Pos.y - 1}
			if {List.nth {List.nth Input.map NewPos.x} NewPos.y} == 3 then
				PosY = {AdjoinAt NewPos y NewPos.y + 1}
			else
				PosY = NewPos
			end

		elseif DY > 0 then
			NewPos
		in
			NewPos = {AdjoinAt PosX y Pos.y + 1}
			if {List.nth {List.nth Input.map NewPos.x} NewPos.y} == 3 then
				PosY = {AdjoinAt NewPos y NewPos.y - 1}
			else
				PosY = NewPos
			end
		else PosY = Pos end

		Position = PosY

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
		if ID == State.id then
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
		State
	end

	fun {SayFoodEaten State ID Food}
		State
	end

	fun {ChargeItem State ?ID ?Kind} 
		{SimulatedThinking}

		% TODO: change with real decisions
		ID = State.id
		if State.gunReloads < Input.gunCharge then
			Kind = gun
		elseif State.mineReloads < Input.mineCharge then
			Kind = mine
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
		if ID == State.id then
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

	fun {FireItem State ?ID ?Kind}
		NearestPlayers
	in
		{SimulatedThinking}

		% TODO: change with real decision
		ID = State.id
		% shoot at the nearest player that is within two tiles
		NearestPlayers = {List.filter State.playersState fun {$ Elem} {ManhattanDistance Elem.position State.position} =< 2 andthen Elem.id.color \= State.id.color andthen Elem.hp > 0 end}
		if {List.length NearestPlayers} >= 1 then
			Kind = gun(pos:NearestPlayers.1.position)
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
		if ID == State.id then
			OutputState = {AdjoinAt State mineReloads 0}
		else 
			OutputState = State 
		end

		% add the mine to the list of mines and change the charge of the player that placed the mine
		{AdjoinAt {AdjoinAt OutputState mines Mine|mines} playerState {PlayerStateModification OutputState.playersState ID ModCharge}}
	end

	fun {SayShoot State ID Position}
		% reset the charges
		fun {ModCharge PlayerState}
			playerState(id:ID position:Position hp:HP mineReload:MineReload gunReload:_ flag:Flag) = PlayerState
		in
			playerState(id:ID position:Position hp:HP mineReload:MineReload gunReload:0 flag:Flag)
		end 
		OutputState
	in
		% reset this player's charge
		if ID == State.id then
			OutputState = {AdjoinAt State gunReloads 0}
		else 
			OutputState = State 
		end
		
		% reset the charge of the player in the list
		{AdjoinAt OutputState playerState {PlayerStateModification OutputState.playersState ID ModCharge}}
	end

	fun {SayDeath State ID}
		fun {ModDeath PlayerState}
			playerState(id:ID position:Position hp:_ mineReload:MineReload gunReload:GunReload flag:Flag) = PlayerState
		in
			playerState(id:ID position:Position hp:0 mineReload:MineReload gunReload:GunReload flag:Flag)
		end 
	in
		{AdjoinAt State playersState {PlayerStateModification State.playersState ID ModDeath}}
	end

	fun {SayDamageTaken State ID Damage LifeLeft}
		fun {ModHp PlayerState}
			playerState(id:ID position:Position hp:_ mineReload:MineReload gunReload:GunReload flag:Flag) = PlayerState
		in
			playerState(id:ID position:Position hp:LifeLeft mineReload:MineReload gunReload:GunReload flag:Flag)
		end 
	in
		{AdjoinAt State playersState {PlayerStateModification State.playersState ID ModHp}}
    end

	fun {TakeFlag State ?ID ?Flag}
		NearestEnemyFlag
	in
		{SimulatedThinking}

		NearestEnemyFlag = {List.sort {List.filter Input.flags fun {$ Elem} Elem.color \= State.id.color end} fun {$ Element} {ManhattanDistance Element.pos State.position} end}

		% try to grab the nearest flag if we are close enough
		if NearestEnemyFlag.1.pos == State.position then
			Flag = NearestEnemyFlag.1
		else
			Flag = null
		end
		
		ID = State.id

		State
	end
			
	fun {DropFlag State ?ID ?Flag}
		{SimulatedThinking}

		ID = State.id
		Flag = null
		State
	end

	fun {SayFlagTaken State ID Flag}
		State
	end

	fun {SayFlagDropped State ID Flag}
		State
	end

	fun {Respawn State}
		fun {ModHp PlayerState}
			playerState(id:ID position:_ hp:_ mineReload:MineReload gunReload:GunReload flag:Flag) = PlayerState
			NewPos = {List.nth Input.spawnPoints ID.id}
		in
			playerState(id:ID position:NewPos hp:Input.startHealth mineReload:MineReload gunReload:GunReload flag:Flag)
		end
		NewState NewState2
	in
		NewState = {AdjoinAt State hp Input.startHealth}
		NewState2 = {AdjoinAt NewState position {List.nth Input.spawnPoints NewState.id.id}}
		{AdjoinAt NewState2 playersState {PlayerStateModification NewState2.playersState NewState2.id ModHp}}
	end

	fun {SayRespawn State ID}
		fun {ModHp PlayerState}
			playerState(id:ID position:_ hp:_ mineReload:MineReload gunReload:GunReload flag:Flag) = PlayerState
			NewPos = {List.nth Input.spawnPoints ID.id}
		in
			playerState(id:ID position:NewPos hp:Input.startHealth mineReload:MineReload gunReload:GunReload flag:Flag)
		end 
	in
		{AdjoinAt State playersState {PlayerStateModification State.playersState ID ModHp}}
	end
end
