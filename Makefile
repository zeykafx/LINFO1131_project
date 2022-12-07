# ----------------------------
# group number 60
# 47142000 : Hugo Delporte 
# 60672000 : Corentin Detry
# ----------------------------

FLAGS = --nowarnunused --warnopt

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
PLAYER1 = "Player060Attacker.oz"
PLAYER2 = "Player060Defender.oz"

# TODO: replace with default makefile at the end of the project (except if we can keep this one?)

all: compileAll run

compileAll: Input.ozf Player060Attacker.ozf Player060Defender.ozf PlayerManager.ozf GUI.ozf Main.ozf

# Compiles all .oz files into .ozf files
%.ozf: %.oz
	$(OZC) $(FLAGS) -c $^

run:
	$(OZENGINE) Main.ozf

clean:
	rm *.ozf

.PHONY: clean