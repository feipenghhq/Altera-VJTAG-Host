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

async def bus_monitor(dut):
    dut.rrvalid.value = 0
    dut.rdata.value = 0
    while True:
        await RisingEdge(dut.rvalid)
        await FallingEdge(dut.clk)
        dut.rrvalid.value = 1
        dut.rdata.value = dut.address.value + 1
        await FallingEdge(dut.clk)
        dut.rrvalid.value = 0

async def init(dut, period = 100):
    """
    Initialize the environment: setup clock, load the hack rom and reset the design
    """
    dut.rready.value = 1
    dut.wready.value = 1
    # start clock
    cocotb.start_soon(Clock(dut.clk, period, units = 'ns').start()) # clock
    # generate reset
    dut.rst_n.value = 0
    cocotb.start_soon(bus_monitor(dut))
    for _ in range(1):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


@cocotb.test()
async def test(dut):
    await init(dut)
    await Timer(10, units='ms')