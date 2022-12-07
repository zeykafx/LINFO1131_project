functor
import
	Player060Attacker
	Player060Defender
export
	playerGenerator:PlayerGenerator
define
	PlayerGenerator
in
	fun{PlayerGenerator Kind Color ID}
		case Kind
		of player060attacker then {Player060Attacker.portPlayer Color ID}
		[] player060defender then {Player060Defender.portPlayer Color ID}
		end
	end
end
