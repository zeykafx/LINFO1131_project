functor
import
	Player1
	Player2
export
	playerGenerator:PlayerGenerator
define
	PlayerGenerator
in
	fun{PlayerGenerator Kind Color ID}
		case Kind
		of player060attacker then {Player1.portPlayer Color ID}
		[] player060defender then {Player2.portPlayer Color ID}
		end
	end
end
