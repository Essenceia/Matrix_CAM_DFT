"""
Created on Jan 9, 2024

Code here, in main.py, runs on every power-up.

You can put anything you like in here, including any utility functions
you might want to have access to when connecting to the REPL.

If you want to use the SDK, all
you really need is something like

		  DemoboardDetect.probe()
		  tt = DemoBoard.get()

Then you can
		# enable test project
		tt.shuttle.tt_um_factory_test.enable()

and play with i/o as desired.

@author: Pat Deegan
@copyright: Copyright (C) 2024 Pat Deegan, https://psychogenic.com
"""
import gc
import test

import ttboard.log as logging
import micropython
from ttboard.boot.demoboard_detect import DemoboardDetect
from ttboard.demoboard import DemoBoard
import ttboard.util.colors as colors
import interactive
from array import array
import microcotb as cocotb
from machine import Pin
from ttboard.demoboard import DemoBoard, RPMode

def enable_essen():

	tt = DemoBoard.get()

	if tt.mode != RPMode.ASIC_MANUAL_INPUTS:
		print("Setting mode to ASIC_MANUAL_INPUTS")
		tt.mode = RPMode.ASIC_MANUAL_INPUTS

	tt.reset_project(True)
 
	# oe enable values
	tt.uio_oe_pico.value = 0b11000000

	# set clk floating
	tt.pins.rp_projclk.mode = Pin.IN	
	
	print("Got shuttle chip:")
	print(tt.shuttle)
	if not tt.shuttle.has("tt_um_essen"):
		print("No tt_um_essen this shuttle - fail")
		return tt
	
	tt.shuttle.tt_um_essen.enable()
	print(f"tt.sdk_revision={tt.revision}")
	print(f"tt.sdk_version={tt.version}")
	print(f"oe enabled to: {tt.uio_oe_pico}")
   	print(f"tt_um_essen configured with options: {tt.shuttle.tt_um_essen}")


	return tt

