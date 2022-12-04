# ----------------------------
# group number 60
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
INPUT := "Input.oz"
PLAYER1 = "PlayerBasic.oz"
PLAYER2 = "PlayerBasic.oz"


all: compileAll run

compileAll: Input.ozf Player1.ozf Player2.ozf PlayerManager.ozf GUI.ozf Main.ozf

# Compiles all .oz files into .ozf files
%.ozf: %.oz
	$(OZC) -c $^

# overrides the previous rules for the players
# TODO: remove this when we have the two players created

# players:
# 	$(OZC) -c ${PLAYER1} -o "Player1.ozf"
# 	$(OZC) -c ${PLAYER2} -o "Player2.ozf"
Player%.ozf: PlayerBasic.oz
	$(OZC) -c $^ -o $@

PlayerManager.ozf: PlayerManager.oz
	$(OZC) -c $^

run:
	$(OZENGINE) Main.ozf

clean:
	rm *.ozf

.PHONY: clean