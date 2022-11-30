functor
import
	GUI
	Input
	PlayerManager
	System
	OS
define
	DoListPlayer
	InitThreadForAll
	PlayersPorts
	SendToAll
	SimulatedThinking
	Main
	WindowPort
	PlayTurn
	InitPlayersState

	proc {DrawFlags Flags Port}
		case Flags of nil then skip 
		[] Flag|T then
			{Send Port putFlag(Flag)}
			{DrawFlags T Port}
		end
	end
in
    fun {DoListPlayer Players Colors ID}
		case Players#Colors
		of nil#nil then nil
		[] (Player|NextPlayers)#(Color|NextColors) then
			player(ID {PlayerManager.playerGenerator Player Color ID})|
			{DoListPlayer NextPlayers NextColors ID+1}
		end
	end

	SimulatedThinking = proc{$} {Delay ({OS.rand} mod (Input.thinkMax - Input.thinkMin) + Input.thinkMin)} end

	% send a message to all players
	proc {SendToAll Message} 
		for player(_ Port) in PlayersPorts do
			{Send Port Message}
		end
		% for Id in {1..Input.nbPlayer} do
		% 	if {List.nth State.playersState Id}.hp /= 0 then
		% 		{Send {List.nth PlayersPorts Id} Message}
		% 	else 
		% 		skip
		% 	end
		% end
	end

	proc {PlayTurn PlayerPort ID State TurnStep}

		case TurnStep
		of nil then skip
		[] step1 then
			{System.show step1#ID}
			% if the player is dead, wait for RespawnDelay and send respawn() to the player, the player will set its local state's hp to startHp 
			% and start playing again. Update the main's state for that player to set its health to startHp
			% {SendToAll sayMoved(ID pt(x:1 y:1))} % for testing
			
			{PlayTurn PlayerPort ID State step2}

		[] step2 then
			{System.show step2#ID}
			% if the player is alive ask where it wants to go
			{PlayTurn PlayerPort ID State step3}

		[] step3 then
			{System.show step3#ID}
			% check if the position the player wants to move to is a valid move, if it is not, the position stays the same,
			% otherwise notify everyone of the player's new position
			{PlayTurn PlayerPort ID State step4}

		[] step4 then
			{System.show step4#ID}
			% check if the player has moved on a mine
			% If so, apply the damage and notify everyone that the mine has exploded and notify everyone for each player that took damage.
			% If a player dies as a result, notify everyone and skip the rest of the ”turn” for that player.
			{PlayTurn PlayerPort ID State step5}

		[] step5 then
			{System.show step5#ID}
			% ask the player what weapon it wants to charge (gun or mine)
			{PlayTurn PlayerPort ID State step6}

		[] step6 then
			{System.show step6#ID}
			% Ask the player what weapon it wants to use (place a mine or shoot at something). Check if the player
			% can indeed use that weapon, and if so send a message notifying everyone, then reset the charge counter
			% to 0 for that weapon. If a mine is exploded as a result, notify everyone that it has exploded and apply
			% the damage. If a player has been shot, notify everyone.
			{PlayTurn PlayerPort ID State step7}

		[] step7 then
			{System.show step7#ID}
			% Ask the player if it wants to grab the flag (only if it is possible). Notify everyone if the flag has been picked up.
			{PlayTurn PlayerPort ID State step8}

		[] step8 then
			{System.show step8#ID}
			% if applicable, ask the player if they want to drop the flag. Notify everyone if they do.
			{PlayTurn PlayerPort ID State step9}

		[] step9 then
			{System.show step9#ID}
			% if a player has died, notify everyone and also notify them if the flag has been dropped as a result.
			{PlayTurn PlayerPort ID State step10}

		[] step10 then
			{System.show step10#ID}
			% The game Controller is also responsible for spawning food randomly on the map after a random time
			% between FoodDelayMin and FoodDelayMin has passed
			skip
		end
	end

	% this is the main loop for each thread
	proc {Main Port ID State}

		{Wait ID}

		{System.show startOfLoop(ID)}


		%%%% TODO Insert your code here
		% communicate with the players by sending a message with unbound variables and then waiting on those variables to get the answer
		{PlayTurn Port ID State step1}

		{System.show endOfLoop(ID)}
		{Delay 500}
		{Main Port ID State}
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
			 	{Main Port ID state(mines:nil flags:Input.flags playersState:{InitPlayersState 1 nil})} % start the game loop for player #ID
			end
			{InitThreadForAll Next}
		end
	end

	fun {InitPlayersState ID Acc}
		if ID > Input.nbPlayer then
			Acc
		else
			{InitPlayersState ID+1 playerState(id:ID position:{List.nth Input.spawnPoints ID} hp:Input.startHealth mineReload:0 gunReload:0 flag:null)|Acc}
		end
	end

    thread
		% Create port for window
		WindowPort = {GUI.portWindow}

		% Open window
		{Send WindowPort buildWindow}
		{System.show buildWindow}

        % Create port for players
		PlayersPorts = {DoListPlayer Input.players Input.colors 1}

		{InitThreadForAll PlayersPorts}
	end
end
