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
from cocotb.triggers import FallingEdge, RisingEdge, Timer, ReadWrite
from cocotb.clock import Clock

from WbDeviceBFM import WbDeviceBFM


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
    wb = WbDeviceBFM(dut, 16, 16, True)
    await init(dut)
    await cocotb.start_soon(wb.single_write())
    await cocotb.start_soon(wb.single_read())
    await Timer(1, units='ms')
