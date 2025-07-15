// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: UART Controller
// Author: Heqing Huang
// Date Created: 06/25/2025
//
// -------------------------------------------------------------------
// Top level for the Arty FPGA board
// Loopback the RX to TX
// -------------------------------------------------------------------

module top
(
    input         CLOCK_50,    // 50 MHz
    input         KEY,         // Used as RESET, low active

    output [15:0] LEDR,
    output [3:0]  LEDG,
    input  [15:0] SW
);

    logic        rst_n_out;
    logic [15:0] address;
    logic        wvalid;
    logic [15:0] wdata;
    logic        wready;
    logic        rvalid;
    logic        rready;
    logic        rrvalid;
    logic [15:0] rdata;

    logic [15:0] switch;
    logic [15:0] led;

    always @(posedge CLOCK_50) begin
        if (!KEY) begin
            switch <= 0;
            led    <= 16'hFFFF;
            rrvalid <= 1'b0;
        end
        else begin
            switch <= SW;
            rrvalid <= 1'b0;
            if (!rst_n_out) led <= 0;
            else if (wvalid && address == 4) led <= wdata;
            if (rvalid && address == 8) rrvalid <= rvalid;
        end
    end

    assign LEDR = led;
    assign rready = 1;
    assign wready = 1;

    assign LEDG[0] = rst_n_out;
    assign LEDG[1] = ~rst_n_out;

    vjtag_host #(.AW(16), .DW(16))
    u_host (
        .clk       (CLOCK_50),
        .rst_n     (KEY),
        .rst_n_out (rst_n_out),
        .address   (address),
        .wvalid    (wvalid),
        .wdata     (wdata),
        .wready    (wready),
        .rvalid    (rvalid),
        .rready    (rready),
        .rrvalid   (rrvalid),
        .rdata     (switch)
    );

endmodule
