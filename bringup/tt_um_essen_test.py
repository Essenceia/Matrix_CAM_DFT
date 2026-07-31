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

def enable_essen(tt):
	from ttboard.demoboard import DemoBoard, RPMode

	tt = DemoBoard.get()
	print("Got shuttle chip:")
	print(tt.shuttle)
	if not tt.shuttle.has("tt_um_essen"):
		print("No tt_um_essen this shuttle - fail")
		return

	tt.shuttle.tt_um_essen.enable()
	if tt.mode != RPMode.ASIC_RP_CONTROL:
		print("Setting mode to ASIC_RP_CONTROL")
		tt.mode = RPMode.ASIC_RP_CONTROL

	tt.reset_project(False)
 
	# oe enable values
	tt.uio_oe_pico.value = 0b11000000
	print(f"oe enabled to: {tt.uio_oe_pico}")
   	print(f"tt_um_essen configured with options: {tt.shuttle.tt_um_essen}")
	return tt


cocotb.set_runner_scope(__name__)
@cocotb.test()
def run_test(dut):
	await interactive.init(dut)
	W = array("b", [0, 1, 2, 3])
	I = array("b", [4, 5, 6, 7])

	await interactive.write_weights(dut, dut._log, W)
	res = await interactive.write_data(dut,dut.log, I) 

	print(f"result {res}")

import ttboard.cocotb.dut as basedut
class DUT(basedut.DUT):
	def __init__(self):
		super().__init__('tt_um_essen_test')

def start_interactive(tt):
	tt = enable_essen(tt)
	print("Interactive init finished and project set")

	runner = cocotb.get_runner(__name__)
	
	dut = DUT()
	dut._log.info("start test")
	runner = cocotb.get_runner(__name__)
	runner.test(dut)
 
	return runner

