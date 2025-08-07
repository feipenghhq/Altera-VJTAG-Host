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

    fpga_vjtag2gpio u_vjtag2gpio(
        .clk    (CLOCK_50),
        .rst_n  (KEY),
        .gpio0  (LEDR),
        .gpio1  (LEDG),
        .gpio2  (SW)
    );


endmodule
