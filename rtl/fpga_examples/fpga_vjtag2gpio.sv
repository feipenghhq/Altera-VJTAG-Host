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

module fpga_vjtag2gpio
(
    input   clk,
    input   rst_n,

    output [15:0] gpio0,
    output [15:0] gpio1,
    input  [15:0] gpio2
);

    localparam ADDR_WIDTH = 16;
    localparam DATA_WIDTH = 16;

    logic rst_n_out;

    // wishbone b4
    logic                    wb_cyc_o;
    logic                    wb_stb_o;
    logic                    wb_we_o;
    logic [ADDR_WIDTH-1:0]   wb_adr_o;
    logic [DATA_WIDTH-1:0]   wb_dat_i;
    logic [DATA_WIDTH-1:0]   wb_dat_o;
    logic                    wb_ack_i;
    logic                    wb_stall_i;

    wire [2:0][DATA_WIDTH-1:0] gpio;

    assign gpio0 = gpio[0];
    assign gpio1 = gpio[1];
    assign gpio[2] = gpio2;

    vjtag2wb u_vjtag2wb(.*);

    wbgpio #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .NUM_GPIO(3)
    ) u_wbgpio(
        .clk        (clk),
        .rst_n      (rst_n),
        .cfg        (3'b011),
        .gpio       (gpio),
        .wb_cyc_i   (wb_cyc_o  ),
        .wb_stb_i   (wb_stb_o  ),
        .wb_we_i    (wb_we_o   ),
        .wb_adr_i   (wb_adr_o  ),
        .wb_sel_i   (2'b11),
        .wb_dat_i   (wb_dat_o  ),
        .wb_dat_o   (wb_dat_i  ),
        .wb_ack_o   (wb_ack_i  ),
        .wb_stall_o (wb_stall_i)
    );

endmodule
