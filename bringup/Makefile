
venv:
	source ~/rtl/tt-micropython-firmware/venv/bin/activate

flash:
	mpremote fs cp main.py :/main.py
	mpremote fs cp tt_um_essen_test.py :/tt_um_essen_test.py
	mpremote fs cp interactive.py :/interactive.py
	mpremote fs cp mac_utils.py :/mac_utils.py
	mpremote fs cp test.py :/test.py
	mpremote reset

log:
	mpremote fs cp :/boot.log boot.log
	mpremote reset
	cat boot.log

picocom: 
	echo "Exit Ctrl-A + Ctrl-Q" 
	picocom -q /dev/ttyACM0	

format:
	black .

clean: 
	rm -f ./boot.log

.PHONY: venv cp_main log clean picocom format
