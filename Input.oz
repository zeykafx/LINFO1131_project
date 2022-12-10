functor
import
    System
    OS
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

    boostsDuration:BoostsDuration
    adrenalineBoostHP:AdrenalineBoostHP
    adrenalineDelayMin:AdrenalineDelayMin 
    adrenalineDelayMax:AdrenalineDelayMax

    speedBoostDelayMin:SpeedBoostDelayMin 
    speedBoostDelayMax:SpeedBoostDelayMax 
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
    AdrenalineBoostHP
    AdrenalineDelayMin 
    AdrenalineDelayMax 
    SpeedBoostDelayMin
    SpeedBoostDelayMax
    BoostsDuration
    GenerateMap
    USE_DEFAULT_MAP
in

%%%% Description of the map %%%%

    NRow = 12
    NColumn = 12

    % set to true to use the default map
    USE_DEFAULT_MAP = false

    % 0 = Empty
    % 1 = Player 1's base
    % 2 = Player 2's base
    % 3 = Walls

    proc {GenerateMap}
        % these are the bases, dont put any walls in those lists
        RedPlayerBase1 = [1 1 1 0 0 0 0 0 0 0 0 0]
        RedPlayerBase2 = [1 1 1 0 0 0 0 0 0 0 0 0]
        RedPlayerBaseFlag = [0 0 0 0 0 0 0 0 0 0 3 3]
        BluePlayerBaseFlag = [3 3 0 0 0 0 0 0 0 0 0 0]
        BluePlayerBase1 = [0 0 0 0 0 0 0 0 0 2 2 2]
        BluePlayerBase2 = [0 0 0 0 0 0 0 0 0 2 2 2]

        % list.member but modified to return the index of the element if it is in the list
        fun {MemberIdx X Ys Idx}
            case Ys of nil then false
            [] Y|Yr then 
                if X==Y then
                    Idx
                else
                    {MemberIdx X Yr Idx+1}
                end
            end
        end

        % this function is used to generate a list of random tiles (with more empty tiles than walls) 
        fun {GenerateTileList Idx}
            if Idx =< 12 then
                if {OS.rand} mod 10 == 0 then % rarely put walls
                    3|{GenerateTileList Idx+1}
                else 
                    0|{GenerateTileList Idx+1}
                end
            else
                nil
            end
        end

        % this function puts the whole map together, it adds the bases, and generates the lists in between the two
        fun {GenMap ListIdx}
            if ListIdx == 1 then
                RedPlayerBase1|{GenMap 2}
            elseif ListIdx == 2 then
                RedPlayerBase2|{GenMap 3}

            % dont place walls on the flag line
            elseif ListIdx == 3 then
                RedPlayerBaseFlag|{GenMap 4}

            % dont place walls on the flag line
            elseif ListIdx == 10 then
                BluePlayerBaseFlag|{GenMap 11}

            elseif ListIdx == 11 then
                BluePlayerBase1|{GenMap 12}
            elseif ListIdx == 12 then
                BluePlayerBase2|nil

            else
                {GenerateTileList 1}|{GenMap ListIdx+1}

                % GenList OutList FlagXForCurrentList FlagsXPos = {List.map Flags fun {$ Elem} Elem.pos.x end} FlagsYPos = {List.map Flags fun {$ Elem} Elem.pos.y end}
            % in

                % this was used to remove any walls from the flag pos, but it didn't always work
                % TODO: fix
                % GenList = {GenerateTileList 1}
                % % check the the current ListIdx (which represents the X axis) doesn't contain a flag, if it does, FlagXForCurrentList will contain the index of the flag that is in the same X position as the list
                % FlagXForCurrentList = {MemberIdx ListIdx FlagsXPos 1}

                % % and if the position where the flag goes has a wall, we will replace that wall with air
                % if FlagXForCurrentList \= false andthen {List.nth GenList FlagXForCurrentList} == 3 then
                %     OutList = {List.mapInd GenList fun {$ Index Elem} if Index == {List.nth FlagsYPos FlagXForCurrentList} then 0 else Elem end end}
                % else
                %     OutList = GenList
                % end
                % OutList|{GenMap ListIdx+1}

            end
        end
    in
        if USE_DEFAULT_MAP then
            {System.show 'Using a the default map'}
            Map = [
                [1 1 1 0 0 0 0 0 0 0 0 0]
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
                [0 0 0 0 0 0 0 0 0 2 2 2]
            ]
        else
            {System.show 'Using a randomly generated map'}
            Map = {GenMap 1}
        end
    end



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

    FoodDelayMin = 15000 % 25000 by default
    FoodDelayMax = 20000 % 30000 by default

%%%% Charges
    GunCharge = 1
    MineCharge = 5
     
%%%% Respawn
    RespawnDelay = 12500 % 25000 by default

%%%% Flags
    Flags = [flag(pos:pt(x:3 y:4) color:red) flag(pos:pt(x:10 y:9) color:blue)]

%%%% Boosts
    BoostsDuration = 5000 % ms
    AdrenalineBoostHP = 2

    AdrenalineDelayMin = 15000 
    AdrenalineDelayMax = 20000 

    SpeedBoostDelayMin = 15000
    SpeedBoostDelayMax = 20000

    % generate the map for this round
   {GenerateMap}
end
