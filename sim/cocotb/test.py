# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: Hack on FPGA
# Author: Heqing Huang
# Date Created: 06/13/2025
#
# -------------------------------------------------------------------
# Basic Test for hack_top
# -------------------------------------------------------------------

import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, Timer
from cocotb.clock import Clock

async def init(dut, period = 100):
    """
    Initialize the environment: setup clock, load the hack rom and reset the design
    """
    # start clock
    cocotb.start_soon(Clock(dut.clk, period, units = 'ns').start()) # clock
    # generate reset
    dut.rst_n.value = 0
    for _ in range(1):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


@cocotb.test()
async def test(dut):
    await init(dut)
    await Timer(10, units='ms')