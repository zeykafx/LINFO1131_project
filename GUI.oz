functor
import
	QTk at 'x-oz://system/wp/QTk.ozf'
	Input
	System
export
	portWindow:StartWindow
define

	StartWindow
	TreatStream

	RemoveItem
	RemoveSoldier

	Map = Input.map

	NRow = Input.nRow
	NColumn = Input.nColumn

	DrawSoldier
	MoveSoldier
	DrawMine
	RemoveMine
	DrawFlag
	RemoveFlag
	DrawFood
	RemoveFood

	BuildWindow

	Label
	Squares
	DrawMap

	StateModification

	UpdateLife
	SoldierHasFlag
	RemoveSoldierHasFlag

	DrawSpeedBoost
	RemoveSpeed

	DrawAdrenalineBoost
	RemoveAdrenaline
in

%%%%% Build the initial window and set it up (call only once)
	fun {BuildWindow ?Done} % Done is used to know when the interface is ready
		Grid GridScore Toolbar Desc DescScore Window
	in
		Toolbar=lr(glue:we tbbutton(text:"Quit" glue:w action:toplevel#close))
		Desc=grid(handle:Grid height:500 width:500)
		DescScore=grid(handle:GridScore height:100 width:500)
		Window={QTk.build td(Toolbar Desc DescScore)}
  
		{Window show}

		% configure rows and set headers
		{Grid rowconfigure(1 minsize:50 weight:0 pad:5)}
		for N in 1..NRow do
			{Grid rowconfigure(N+1 minsize:50 weight:0 pad:5)}
			{Grid configure({Label N} row:N+1 column:1 sticky:wesn)}
		end
		% configure columns and set headers
		{Grid columnconfigure(1 minsize:50 weight:0 pad:5)}
		for N in 1..NColumn do
			{Grid columnconfigure(N+1 minsize:50 weight:0 pad:5)}
			{Grid configure({Label N} row:1 column:N+1 sticky:wesn)}
		end
		% configure scoreboard
		{GridScore rowconfigure(1 minsize:50 weight:0 pad:5)}
		for N in 1..(Input.nbPlayer) do
			{GridScore columnconfigure(N minsize:50 weight:0 pad:5)}
		end

		{DrawMap Grid}
		Done = true
		handle(grid:Grid score:GridScore)
	end

	Squares = square(
                0:label(text:"" width:1 height:1 bg:c(102 180 102)) % Land
			    1:label(text:"" borderwidth:5 relief:flat width:1 height:1 bg:(Input.colors.1)) % Player1's base
                2:label(text:"" borderwidth:5 relief:flat width:1 height:1 bg:(Input.colors.2.1)) % Player2's base
                3:label(text:"" borderwidth:5 relief:raised width:1 height:1 bg:c(160 160 160)) % Walls
			)

%%%%% Labels for rows and columns
	fun{Label V}
		label(text:V borderwidth:5 relief:groove bg:c(80 80 80) ipadx:5 ipady:5)
	end

%%%%% Function to draw the map
	proc{DrawMap Grid}
		proc{DrawColumn Column M N}
			case Column
			of nil then skip
			[] T|End then
				{Grid configure(Squares.T row:M+1 column:N+1 sticky:wesn)}
				{DrawColumn End M N+1}
			end
		end
		proc{DrawRow Row M}
			case Row
			of nil then skip
			[] T|End then
				{DrawColumn T M 1}
				{DrawRow End M+1}
			end
		end
	in
		{DrawRow Map 1}
	end

%%%%% Init the soldier
	fun{DrawSoldier Grid ID Position}
		Handle HandleScore X Y Id Color LabelSub LabelScore
	in
		if ID == null then
			guiSoldier(id:ID score:null soldier:null mines:nil flags:nil foods:nil speeds:nil adrenalines:nil)
		else
			pt(x:X y:Y) = Position
			id(id:Id color:Color name:_) = ID

			LabelSub = label(text:'S'#ID.id handle:Handle borderwidth:5 relief:raised bg:Color ipadx:5 ipady:5)
			LabelScore = label(text:Input.startHealth borderwidth:5 handle:HandleScore relief:solid bg:Color ipadx:5 ipady:5)
			{Grid.grid configure(LabelSub row:X+1 column:Y+1 sticky:wesn)}
			{Grid.score configure(LabelScore row:1 column:Id sticky:wesn)}
			{Handle 'raise'()}
			guiSoldier(id:ID score:HandleScore soldier:Handle mines:nil flags:nil foods:nil speeds:nil adrenalines:nil)
		end
	end

	fun{MoveSoldier Position}
		fun{$ Grid State}
			ID HandleScore Handle Mine X Y Flag Food Speed Adrenaline
		in
			guiSoldier(id:ID score:HandleScore soldier:Handle mines:Mine flags:Flag foods:Food speeds:Speed adrenalines:Adrenaline) = State
			pt(x:X y:Y) = Position
			{Grid.grid remove(Handle)}
			{Grid.grid configure(Handle row:X+1 column:Y+1 sticky:wesn)}
			{Handle 'raise'()}
			guiSoldier(id:ID score:HandleScore soldier:Handle mines:Mine flags:Flag foods:Food speeds:Speed adrenalines:Adrenaline)
		end
	end

	% changes the soldier's label to include F if they are carrying the flag
	fun {SoldierHasFlag}
		fun{$ Grid State}
			ID Handle
		in
			guiSoldier(id:ID score:_ soldier:Handle mines:_ flags:_ foods:_ speeds:_ adrenalines:_) = State
			{Handle set(text:'S'#ID.id#'F')}
			State
		end
	end

	% reset the player's label if they dropped the flag
	fun {RemoveSoldierHasFlag}
		fun{$ Grid State}
			ID Handle
		in
			guiSoldier(id:ID score:_ soldier:Handle mines:_ flags:_ foods:_ speeds:_ adrenalines:_) = State
			{Handle set(text:'S'#ID.id)}
			State
		end
	end
  
	fun{DrawMine Position}
		fun{$ Grid State}
			ID HandleScore Handle Mine LabelMine HandleMine X Y Flag Food Speed Adrenaline
		in
			guiSoldier(id:ID score:HandleScore soldier:Handle mines:Mine flags:Flag foods:Food speeds:Speed adrenalines:Adrenaline) = State
			pt(x:X y:Y) = Position
			LabelMine = label(text:"M" handle:HandleMine borderwidth:5 relief:raised bg:c(30 30 30) ipadx:5 ipady:5)
			{Grid.grid configure(LabelMine row:X+1 column:Y+1)}
			{HandleMine 'raise'()}
			if Handle \= null then 
				{Handle 'raise'()}
			end
			guiSoldier(id:ID score:HandleScore soldier:Handle mines:mine(HandleMine Position)|Mine flags:Flag foods:Food speeds:Speed adrenalines:Adrenaline)
		end
	end

	fun{DrawFlag Position Color}
		fun{$ Grid State}
			ID HandleScore Handle Flag LabelFlag HandleFlag X Y Flag Mine Food Speed Adrenaline
		in
			{System.show drawFlag|Color}
			guiSoldier(id:ID score:HandleScore soldier:Handle mines:Mine flags:Flag foods:Food speeds:Speed adrenalines:Adrenaline) = State
			pt(x:X y:Y) = Position
			LabelFlag = label(text:"F" handle:HandleFlag borderwidth:5 relief:raised bg:Color ipadx:5 ipady:5)
			{Grid.grid configure(LabelFlag row:X+1 column:Y+1)}
			{HandleFlag 'raise'()}
			if Handle \= null then 
				{Handle 'raise'()}
			end
			guiSoldier(id:ID score:HandleScore soldier:Handle mines:Mine flags:flag(HandleFlag Position)|Flag foods:Food speeds:Speed adrenalines:Adrenaline)
		end
	end

	fun{DrawFood Position}
		fun{$ Grid State}
			ID HandleScore Handle Flag LabelFood HandleFood X Y Flag Mine Food Speed Adrenaline
		in
			guiSoldier(id:ID score:HandleScore soldier:Handle mines:Mine flags:Flag foods:Food speeds:Speed adrenalines:Adrenaline) = State
			pt(x:X y:Y) = Position
			LabelFood = label(text:"f" handle:HandleFood borderwidth:5 relief:raised bg:c(160 160 160) ipadx:5 ipady:5)
			{Grid.grid configure(LabelFood row:X+1 column:Y+1)}
			{HandleFood 'raise'()}
			if Handle \= null then 
				{Handle 'raise'()}
			end
			guiSoldier(id:ID score:HandleScore soldier:Handle mines:Mine flags:Flag foods:food(HandleFood Position)|Food speeds:Speed adrenalines:Adrenaline)
		end
	end

	fun{DrawSpeedBoost Position}
		fun{$ Grid State}
			ID HandleScore Handle Flag LabelSpeed HandleSpeed X Y Flag Mine Food Speed Adrenaline
		in
			guiSoldier(id:ID score:HandleScore soldier:Handle mines:Mine flags:Flag foods:Food speeds:Speed adrenalines:Adrenaline) = State

			pt(x:X y:Y) = Position
			LabelSpeed = label(text:"spd" handle:HandleSpeed borderwidth:5 relief:raised bg:c(31 161 206) ipadx:5 ipady:5)
			{Grid.grid configure(LabelSpeed row:X+1 column:Y+1)}
			{HandleSpeed 'raise'()}

			if Handle \= null then 
				{Handle 'raise'()}
			end
			guiSoldier(id:ID score:HandleScore soldier:Handle mines:Mine flags:Flag foods:Food speeds:speed(HandleSpeed Position)|Speed adrenalines:Adrenaline)
		end
	end

	fun{DrawAdrenalineBoost Position}
		fun{$ Grid State}
			ID HandleScore Handle Flag LabelAdrenaline HandleAdrenaline X Y Flag Mine Food Speed Adrenaline
		in
			guiSoldier(id:ID score:HandleScore soldier:Handle mines:Mine flags:Flag foods:Food speeds:Speed adrenalines:Adrenaline) = State
			pt(x:X y:Y) = Position
			LabelAdrenaline = label(text:"adr" handle:HandleAdrenaline borderwidth:5 relief:raised bg:c(194 206 31) ipadx:5 ipady:5)
			{Grid.grid configure(LabelAdrenaline row:X+1 column:Y+1)}
			{HandleAdrenaline 'raise'()}
			if Handle \= null then 
				{Handle 'raise'()}
			end
			guiSoldier(id:ID score:HandleScore soldier:Handle mines:Mine flags:Flag foods:Food speeds:Speed adrenalines:adrenaline(HandleAdrenaline Position)|Adrenaline)
		end
	end

	local
		fun{RmMine Grid Position List}
			case List
			of nil then nil
			[] H|T then
				if (H.2 == Position) then
					{RemoveItem Grid H.1}
					T
				else
					H|{RmMine Grid Position T}
				end
			end
		end
	in
		fun{RemoveMine Position}
			{System.show removeMine(Position)}
			fun{$ Grid State}
				ID HandleScore Handle Mine NewMine Flag Food Speed Adrenaline
			in
				guiSoldier(id:ID score:HandleScore soldier:Handle mines:Mine flags:Flag foods:Food speeds:Speed adrenalines:Adrenaline) = State
				NewMine = {RmMine Grid Position Mine}
				guiSoldier(id:ID score:HandleScore soldier:Handle mines:NewMine flags:Flag foods:Food speeds:Speed adrenalines:Adrenaline)
			end
		end
	end

	local
		fun{RmFood Grid Position List}
			case List
			of nil then nil
			[] H|T then
				if (H.2 == Position) then
					{RemoveItem Grid H.1}
					T
				else
					H|{RmFood Grid Position T}
				end
			end
		end
	in
		fun{RemoveFood Position}
			{System.show removeFood(Position)}
			fun{$ Grid State}
				ID HandleScore Handle Food NewFood Mine Flag Speed Adrenaline
			in
				guiSoldier(id:ID score:HandleScore soldier:Handle mines:Mine flags:Flag foods:Food speeds:Speed adrenalines:Adrenaline) = State
				NewFood = {RmFood Grid Position Food}
				guiSoldier(id:ID score:HandleScore soldier:Handle mines:Mine flags:Flag foods:NewFood speeds:Speed adrenalines:Adrenaline)
			end
		end
	end

	local
		fun{RmSpeed Grid Position List}
			case List
			of nil then nil
			[] H|T then
				if (H.2 == Position) then
					{RemoveItem Grid H.1}
					T
				else
					H|{RmSpeed Grid Position T}
				end
			end
		end
	in
		fun{RemoveSpeed Position}
			{System.show removeSpeed(Position)}
			fun{$ Grid State}
				ID HandleScore Handle Food NewSpeed Mine Flag Speed Adrenaline
			in
				guiSoldier(id:ID score:HandleScore soldier:Handle mines:Mine flags:Flag foods:Food speeds:Speed adrenalines:Adrenaline) = State
				NewSpeed = {RmSpeed Grid Position Speed}
				guiSoldier(id:ID score:HandleScore soldier:Handle mines:Mine flags:Flag foods:Food speeds:NewSpeed adrenalines:Adrenaline)
			end
		end
	end

	local
		fun{RmAdrenaline Grid Position List}
			case List
			of nil then nil
			[] H|T then
				if (H.2 == Position) then
					{RemoveItem Grid H.1}
					T
				else
					H|{RmAdrenaline Grid Position T}
				end
			end
		end
	in
		fun{RemoveAdrenaline Position}
			{System.show removeAdrenaline(Position)}
			fun{$ Grid State}
				ID HandleScore Handle Food NewAdrenaline Speed Mine Flag Speed Adrenaline
			in
				guiSoldier(id:ID score:HandleScore soldier:Handle mines:Mine flags:Flag foods:Food speeds:Speed adrenalines:Adrenaline) = State
				NewAdrenaline = {RmAdrenaline Grid Position Adrenaline}
				guiSoldier(id:ID score:HandleScore soldier:Handle mines:Mine flags:Flag foods:Food speeds:Speed adrenalines:NewAdrenaline)
			end
		end
	end


	local
		fun{RmFlag Grid Position List}
			case List
			of nil then nil
			[] H|T then
				if (H.2 == Position) then
					{RemoveItem Grid H.1}
					T
				else
					H|{RmFlag Grid Position T}
				end
			end
		end
	in
		fun{RemoveFlag Position}
			{System.show removeFlag(Position)}
			fun{$ Grid State}
				ID HandleScore Handle Mine NewFlag Flag Food Speed Adrenaline
			in
				guiSoldier(id:ID score:HandleScore soldier:Handle mines:Mine flags:Flag foods:Food speeds:Speed adrenalines:Adrenaline) = State
				NewFlag = {RmFlag Grid Position Flag}
				guiSoldier(id:ID score:HandleScore soldier:Handle mines:Mine flags:NewFlag foods:Food speeds:Speed adrenalines:Adrenaline)
			end
		end
	end
	
	proc{RemoveItem Grid Handle}
		{Grid.grid forget(Handle)}
	end

	fun{UpdateLife Life}
		fun{$ Grid State}
			HandleScore
		in
			guiSoldier(id:_ score:HandleScore soldier:_ mines:_ flags:_ foods:_ speeds:_ adrenalines:_) = State
			{HandleScore set(text:Life)}
	 		State
		end
	end


	fun{StateModification Grid WantedID State Fun}
		case State
		of nil then nil
		[] guiSoldier(id:ID score:_ soldier:_ mines:_ flags:_ foods:_ speeds:_ adrenalines:_)|Next then
			if (ID \= null) andthen (WantedID \= null) andthen {HasFeature ID id} andthen {HasFeature WantedID id} then
				if (ID.id == WantedID.id) then
					{Fun Grid State.1}|Next
				else
					State.1|{StateModification Grid WantedID Next Fun}
				end
			elseif (ID == null) andthen (WantedID == null) then
				{Fun Grid State.1}|Next
			else
				State.1|{StateModification Grid WantedID Next Fun}
			end
		end
	end

	fun {RemoveSoldier Grid WantedID State}
		case State
		of nil then nil
		[] guiSoldier(id:ID score:HandleScore soldier:Handle mines:M flags:Flag foods:Food speeds:Speed adrenalines:Adrenaline)|Next then
			if (ID == WantedID) then
				{RemoveItem Grid Handle}
				Next
			else
				State.1|{RemoveSoldier Grid WantedID Next}
			end
		end
	end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

	fun{StartWindow}
		Stream
		Port
	in
		{NewPort Stream Port}
		thread
			{TreatStream Stream nil nil}
		end
		Port
	end

	proc {TreatStream Stream Grid State}
		case Stream
		of nil then skip
		[] buildWindow(?Done)|T then NewGrid in 
			NewGrid = {BuildWindow Done}
			{TreatStream T NewGrid State}
		[] initSoldier(ID Position)|T then NewState in
			NewState = {DrawSoldier Grid ID Position}
			{TreatStream T Grid NewState|State}
		[] moveSoldier(ID Position)|T then
			{TreatStream T Grid {StateModification Grid ID State {MoveSoldier Position}}}
		[] lifeUpdate(ID Life)|T then
			{TreatStream T Grid {StateModification Grid ID State {UpdateLife Life}}}
		[] putMine(Mine)|T then 
			{TreatStream T Grid {StateModification Grid null State {DrawMine Mine.pos}}}
		[] removeMine(Mine)|T then
			{TreatStream T Grid {StateModification Grid null State {RemoveMine Mine.pos}}}
		[] putFlag(Flag)|T then 
			{TreatStream T Grid {StateModification Grid null State {DrawFlag Flag.pos Flag.color}}}
		[] removeFlag(Flag)|T then
			{TreatStream T Grid {StateModification Grid null State {RemoveFlag Flag.pos}}}
		[] putFood(Food)|T then 
			{TreatStream T Grid {StateModification Grid null State {DrawFood Food.pos}}}
		[] removeFood(Food)|T then
			{TreatStream T Grid {StateModification Grid null State {RemoveFood Food.pos}}}
		[] removeSoldier(ID)|T then
			{TreatStream T Grid {RemoveSoldier Grid ID State}}
		[] explosion(Position)|T then
			{TreatStream T Grid State}
		[] addSoldierHasFlag(ID)|T then
			{TreatStream T Grid {StateModification Grid ID State {SoldierHasFlag}}}
		[] removeSoldierHasFlag(ID)|T then
			{TreatStream T Grid {StateModification Grid ID State {RemoveSoldierHasFlag}}}

		[] putSpeed(Speed)|T then 
			{TreatStream T Grid {StateModification Grid null State {DrawSpeedBoost Speed.pos}}}

		[] removeSpeed(Speed)|T then
			{TreatStream T Grid {StateModification Grid null State {RemoveSpeed Speed.pos}}}

		[] putAdrenaline(Adrenaline)|T then 
			{TreatStream T Grid {StateModification Grid null State {DrawAdrenalineBoost Adrenaline.pos}}}

		[] removeAdrenaline(Adrenaline)|T then
			{TreatStream T Grid {StateModification Grid null State {RemoveAdrenaline Adrenaline.pos}}}


		[] _|T then
			{TreatStream T Grid State}
		end
	end
end
