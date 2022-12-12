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

INPUT = "Input.oz"
PLAYER1 = "Player060Attacker.oz"
PLAYER2 = "Player060Defender.oz"

all:
	$(OZC) -c ${INPUT} -o "Input.ozf"
	$(OZC) -c ${PLAYER1} -o "Player1.ozf"
	$(OZC) -c ${PLAYER2} -o "Player2.ozf"
	$(OZC) -c PlayerManager.oz
	$(OZC) -c GUI.oz
	$(OZC) -c Main.oz
	$(OZENGINE) Main.ozf

run:
	$(OZENGINE) Main.ozf

clean:
	rm *.ozf
