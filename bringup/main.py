'''
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
'''
import gc

GCThreshold = gc.threshold()
gc.threshold(80000)

import ttboard.log as logging
logging.ticksStart() # start-up tick delta counter
logging.basicConfig(level=logging.DEBUG, filename='boot.log')

from ttboard.boot.demoboard_detect import DemoboardDetect
from ttboard.demoboard import DemoBoard

gc.collect()
gc.threshold(GCThreshold)

log = logging.getLogger(__name__)
log.debug("BOOT: Tiny Tapeout SDK")

gc.collect()
tt = None

# detect the board, carrier and shuttle
if DemoboardDetect.probe():
    log.info('Detected ' + DemoboardDetect.PCB_str())
else:
    log.error('Hm, could not figure out the DB/shuttle?')

gc.collect()
