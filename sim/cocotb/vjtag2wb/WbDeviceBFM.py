# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: Wishbone IP
# Author: Heqing Huang
# Date Created: 08/01/2025
#
# -------------------------------------------------------------------
# Wishbone Bus Device BFM
# Support Wishbone B4 Pipeline Interface
# -------------------------------------------------------------------

import random
from cocotb.triggers import RisingEdge, ReadWrite

class WbDeviceBFM:

    def __init__(self, dut, AW=32, DW=32, default=False):

        """
            Parameters:
            - dut: cocotb  dut
            - AW (int): Address width, default is 32 bits.
            - DW (int): Data width, default is 32 bits.
            - default (bool): Connect the BFM to RTL using default wb signal name
        """
        self.dut = dut
        self.AW = AW
        self.DW = DW
        self.clk = dut.clk
        self.ram = {}
        if default:
            self.connect_default()
            self.init()

    def connect(self, wb_cyc_o, wb_stb_o, wb_we_o, wb_adr_o, wb_dat_i, wb_dat_o, wb_ack_i, wb_stall_i):
        """
        Connect wishbone device BFM to RTL. Assuming RTL interface naming as wb_xxx_i/o
        The WbDeviceBFM is acting as a Wishbone Device so:
            - dut.wb_xxx_o is connected to self.wb_xxx_i
            - dut.wb_xxx_i is connected to self.wb_xxx_o
        """
        # Inputs to the BFM (from DUT outputs)
        self.wb_cyc_i    = wb_cyc_o
        self.wb_stb_i    = wb_stb_o
        self.wb_we_i     = wb_we_o
        self.wb_adr_i    = wb_adr_o
        self.wb_dat_o    = wb_dat_i
        self.wb_dat_i    = wb_dat_o
        self.wb_ack_o    = wb_ack_i
        self.wb_stall_o  = wb_stall_i

    def connect_default(self):
        """
        Connect wishbone device BFM to RTL using default signal name
        """
        self.connect(self.dut.wb_cyc_o, self.dut.wb_stb_o, self.dut.wb_we_o, self.dut.wb_adr_o,
                     self.dut.wb_dat_i, self.dut.wb_dat_o, self.dut.wb_ack_i, self.dut.wb_stall_i)

    def init(self):
        """
        Initialize the signal
        """
        self.wb_ack_o.value = 0
        self.wb_stall_o.value = 0

    async def single_write(self, stall=0):
        """
        Process a SINGLE pipelined write request
        Parameter:
            - stall (int): stall cycle. 0: no stall. > 0: stall `stall` cycle. < 0: random cycle within [0, -stall]
        """
        # wait for the assertion of wb_stb_i
        await ReadWrite()
        while(self.wb_stb_i.value == 0):
            await RisingEdge(self.clk)
            await ReadWrite()
        if (self.wb_cyc_i.value != 1):
            assert ValueError, self.dut._log.error("wb_cyc_o should be asserted when wb_stb_o is asserted!")
        if (self.wb_we_i.value != 0):
            assert ValueError, self.dut._log.error("wb_we_o should be asserted for write request")

        # stall accordingly
        if stall != 0:
            if stall < 0:
                stall = random.randint(0, -stall)
            self.wb_stall_o.value = 1
            for _ in range(stall):
                await RisingEdge(self.clk)
                await ReadWrite()
            self.wb_stall_o.value = 0

        # store the data into local 'ram'
        addr = self.wb_adr_i.value.integer
        data = self.wb_dat_i.value.integer
        self.ram[addr] = data

        # send ack
        await RisingEdge(self.clk)
        await ReadWrite()
        self.wb_ack_o.value = 1
        await RisingEdge(self.clk)
        await ReadWrite()
        self.wb_ack_o.value = 0
        return data

    async def single_read(self, stall=0):
        """
        Process a SINGLE pipelined read request
        Parameter:
            - stall (int): stall cycle. 0: no stall. > 0: stall `stall` cycle. < 0: random cycle within [0, -stall]
        """
        # wait for the assertion of wb_stb_i
        await ReadWrite()
        while(self.wb_stb_i.value == 0):
            await RisingEdge(self.clk)
            await ReadWrite()
        if (self.wb_cyc_i.value != 1):
            assert ValueError, self.dut._log.error("wb_cyc_o should be asserted when wb_stb_o is asserted!")
        if (self.wb_we_i.value != 1):
            assert ValueError, self.dut._log.error("wb_we_o should be de-asserted for read request")

        # stall accordingly
        if stall != 0:
            if stall < 0:
                stall = random.randint(0, -stall)
            self.wb_stall_o.value = 1
            for _ in range(stall):
                await RisingEdge(self.clk)
                await ReadWrite()
            self.wb_stall_o.value = 0

        # capture address
        addr = self.wb_adr_i.value.integer
        data = self.ram[addr]


        # send ack and read data
        await RisingEdge(self.clk)
        await ReadWrite()
        self.wb_ack_o.value = 1
        self.wb_dat_o.value = data
        await RisingEdge(self.clk)
        await ReadWrite()
        self.wb_ack_o.value = 0
        self.wb_dat_o.value = 0
        return data
