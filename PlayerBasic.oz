functor
import
	Input
	OS
	System
	Number
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
	NewTurn
	Move
	IsDead
	AskHealth
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

	% Helper functions
	RandomInRange = fun {$ Min Max} Min+({OS.rand}mod(Max-Min+1)) end

	SimulatedThinking = proc{$} {Delay ({OS.rand} mod (Input.thinkMax - Input.thinkMin) + Input.thinkMin)} end


	% The distance between two points measured along axes at right angles. In a plane with p1 at (x1, y1) and p2 at (x2, y2), it is |x1 - x2| + |y1 - y2|. 
	fun {ManhattanDistance P1 P2}
		{Number.abs (P1.x - P2.x)} + {Number.abs (P1.y - P2.y)}
	end
in
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
					hp:Input.startHealth
					flag:null
					mineReloads:0
					gunReloads:0
					startPosition:{List.nth Input.spawnPoints ID}
					% TODO You can add more elements if you need it
					playersState:nil % List of tuples that look like: playerState(id:ID position:pt(x:X y:Y) hp:HP mineReload:MineReload gunReload:GunReload flag:Flag) 
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
        end
    end

	%%%% TODO Message functions

	fun {StateModification State WantedID Function}
		case State
		of nil then nil
		[] playerState(id:ID position:_ hp:_ mineReload:_ gunReload:_ flag:_)|Next then
			if (ID == WantedID) then
				{Function State.1}|Next
			else 
				State.1|{StateModification Next WantedID Function}
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
		State	
	end

	fun {SayMoved State ID Position}
		fun {ModPos}
			playerState(id:ID position:_ hp:HP mineReload:MineReload gunReload:GunReload flag:Flag)
		in
			playerState(id:ID position:Position hp:HP mineReload:MineReload gunReload:GunReload flag:Flag)
		end
	in
		{System.show playerMoved(ID Position)}
		{StateModification State ID ModPos}
	end

	fun {SayMineExplode State Mine}
		State
	end

	fun {SayFoodAppeared State Food}
		State
	end

	fun {SayFoodEaten State ID Food}
		State
	end

	fun {ChargeItem State ?ID ?Kind} 
		{SimulatedThinking}

		ID = State.id
		Kind = null
		State
	end

	fun {SayCharge State ID Kind}
		State
	end

	fun {FireItem State ?ID ?Kind}
		ID = State.id
		Kind = null
		State
	end

	fun {SayMinePlaced State ID Mine}
		State
	end

	fun {SayShoot State ID Position}
		State
	end

	fun {SayDeath State ID}
		State
	end

	fun {SayDamageTaken State ID Damage LifeLeft}
		State
    end

	fun {TakeFlag State ?ID ?Flag}
		{SimulatedThinking}

		ID = State.id
		Flag = null
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
end
