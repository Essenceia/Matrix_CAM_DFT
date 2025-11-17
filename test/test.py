# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clk = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clk.start())

    # Set the clock period to 100 us (10 KHz)
    jtag_clk = Clock(dut.dut.tck, 100, unit="us")
    cocotb.start_soon(jtag_clk.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 100)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")


    # Wait for one clock cycle to see the output values
    await ClockCycles(dut.clk, 100)

