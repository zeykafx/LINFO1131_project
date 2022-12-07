functor
export
    nRow:NRow
    nColumn:NColumn
    map:Map
    players:Players
    colors:Colors
    guiDelay:GUIDelay
    nbPlayer:NbPlayer
    startHealth:StartHealth
    thinkMin:ThinkMin
    thinkMax:ThinkMax
    foodDelayMin:FoodDelayMin
    foodDelayMax:FoodDelayMax
    gunCharge:GunCharge
    mineCharge:MineCharge
    respawnDelay:RespawnDelay
    spawnPoints:SpawnPoints
    flags:Flags
define
    NRow
    NColumn
    Map
    Players
    Colors
    NbPlayer
    StartHealth
    GUIDelay
    ThinkMin
    ThinkMax
    FoodDelayMin
    FoodDelayMax
    GunCharge
    MineCharge
    RespawnDelay
    SpawnPoints
    Flags
in

%%%% Description of the map %%%%

    NRow = 12
    NColumn = 12

    % 0 = Empty
    % 1 = Player 1's base
    % 2 = Player 2's base
    % 3 = Walls

    Map = [[1 1 1 0 0 0 0 0 0 0 0 0]
	       [1 1 1 0 0 0 0 0 0 0 0 0]
	       [0 0 0 0 0 0 0 0 0 0 0 0]
	       [0 0 0 3 3 0 0 3 3 0 0 0]
	       [0 0 0 3 0 0 0 0 3 0 0 0]
	       [0 0 0 0 0 0 0 0 0 0 0 0]
	       [0 0 0 0 0 0 0 0 0 0 0 0]
	       [0 0 0 3 0 0 0 0 3 0 0 0]
           [0 0 0 3 3 0 0 3 3 0 0 0]
           [0 0 0 0 0 0 0 0 0 0 0 0]
	       [0 0 0 0 0 0 0 0 0 2 2 2]
	       [0 0 0 0 0 0 0 0 0 2 2 2]]

%%%% Players description %%%%

    % two defenders and 2 attackers per teams
    Players = [player060attacker player060attacker player060attacker player060attacker player060defender player060defender]
    Colors = [red blue red blue red blue]
    SpawnPoints = [pt(x:1 y:1) pt(x:12 y:10) pt(x:1 y:2) pt(x:12 y:11) pt(x:1 y:3) pt(x:12 y:12)]
    NbPlayer = 6
    StartHealth = 2

%%%% Waiting time for the GUI between each effect %%%%

    GUIDelay = 500 % ms

%%%% Thinking parameters %%%%

    ThinkMin = 200 % 450 by default
    ThinkMax = 250 % 500 by default

%%%% Food apparition parameters %%%%

    FoodDelayMin = 12500 % 25000 by default
    FoodDelayMax = 15000 % 30000 by default

%%%% Charges
    GunCharge = 1
    MineCharge = 5
     
%%%% Respawn
    RespawnDelay = 12500 % 25000 by default

%%%% Flags
    Flags = [flag(pos:pt(x:3 y:4) color:red) flag(pos:pt(x:10 y:9) color:blue)]

end
