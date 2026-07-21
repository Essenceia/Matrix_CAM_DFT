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

    # oe enable values
    tt.uio_oe_pico.value = 0b11000000
    print(f"oe enabled to: {tt.uio_oe_pico}")
    print(f"tt_um_essen configured with options: {tt.shuttle.tt_um_essen}")


def start_test(tt):
	enable_essen(tt)
	runner, dut = test.start_cocotb(tt)
	print("Test finished") 
	return runner 

