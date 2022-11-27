# ----------------------------
# TODO: Fill your group number, your NOMAs and your names
# group number X
# 47142000 : Hugo Delporte 
# 60672000 : Corentin Detry
# ----------------------------

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	OZC = /Applications/Mozart2.app/Contents/Resources/bin/ozc
	OZENGINE = /Applications/Mozart2.app/Contents/Resources/bin/ozengine
else
	OZC = ozc
	OZENGINE = ozengine
endif

# TODO: Change these parameters as you wish
PLAYER1 = "PlayerBasic.oz"
PLAYER2 = "PlayerBasic.oz"


all: compileAll run

run:
	$(OZENGINE) Main.ozf

.PHONY: clean

clean:
	rm *.ozf


compileAll: Input.ozf players PlayerManager.ozf GUI.ozf Main.ozf

# Rules used to compile files independently from each other

Input.ozf: Input.oz
	$(OZC) -c Input.oz -o "Input.ozf"

players:
	$(OZC) -c ${PLAYER1} -o "Player1.ozf"
	$(OZC) -c ${PLAYER2} -o "Player2.ozf"

PlayerManager.ozf: PlayerManager.oz
	$(OZC) -c PlayerManager.oz
	
GUI.ozf: GUI.oz
	$(OZC) -c GUI.oz

Main.ozf: Main.oz
	$(OZC) -c Main.oz

