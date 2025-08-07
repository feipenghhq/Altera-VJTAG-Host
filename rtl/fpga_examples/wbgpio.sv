// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: Wishbone IP
// Author: Heqing Huang
// Date Created: 08/04/2025
//
// -------------------------------------------------------------------
// wbgpio: Wishbone GPIO
//  - A simple Wishbone to GPIO module.
//  - No register, just map the wishbone interface to GPIO.
//  - Wishbone B4 Pipeline Interface
// -------------------------------------------------------------------

module wbgpio #(
    parameter DATA_WIDTH = 32,      // GPIO data width, support 8, 16, 32, 64, ...
    parameter NUM_GPIO   = 2,       // Number of GPIO data
    parameter ADDR_WIDTH = 3,
    parameter BYTE_WIDTH = 8,
    parameter NUM_BYTES  = DATA_WIDTH / BYTE_WIDTH
) (
    input  logic                    clk,
    input  logic                    rst_n,

    // GPIO
    input  logic [NUM_GPIO-1:0]                 cfg,    // config each gpio as input or output. 0 - input, 1 - output
    inout  logic [NUM_GPIO-1:0][DATA_WIDTH-1:0] gpio,

    // wishbone interface
    input  logic                    wb_cyc_i,
    input  logic                    wb_stb_i,
    input  logic                    wb_we_i,
    input  logic [ADDR_WIDTH-1:0]   wb_adr_i,
    input  logic [NUM_BYTES -1:0]   wb_sel_i,
    input  logic [DATA_WIDTH-1:0]   wb_dat_i,
    output logic [DATA_WIDTH-1:0]   wb_dat_o,
    output logic                    wb_ack_o,
    output logic                    wb_stall_o
);

localparam BYTE_OFFSET = $clog2(NUM_BYTES);

logic [DATA_WIDTH-1:0]              gpio_r[NUM_GPIO-1:0];
logic [ADDR_WIDTH-1-BYTE_OFFSET:0]  wb_adr_word;

assign wb_adr_word = wb_adr_i[ADDR_WIDTH-1:BYTE_OFFSET];

// Wishbone logic
always_ff @(posedge clk) begin
    if (!rst_n) begin
        wb_ack_o <= 1'b0;
        //gpio_r <= 'b0;
    end
    else begin
        wb_ack_o <= wb_cyc_i & wb_stb_i;
        wb_dat_o <= gpio_r[wb_adr_word];

        if (wb_cyc_i && wb_stb_i) begin
            for (int i = 0; i < NUM_BYTES; i = i + 1) begin
                if (wb_we_i && wb_sel_i[i] && cfg[wb_adr_word]) gpio_r[wb_adr_word][BYTE_WIDTH*i+:8] <= wb_dat_i[BYTE_WIDTH*i+:8];
            end
        end


        for (int i = 0; i < NUM_GPIO; i=i+1) begin
            if (cfg[i] == 0) begin
                gpio_r[i] <= gpio[i];
            end
        end
    end
end

assign wb_stall_o = 1'b0;

// GPIO logic
genvar i;
generate
    for (i = 0; i < NUM_GPIO; i=i+1) begin: gen
        assign gpio[i] = cfg[i] ? gpio_r[i] : 'bz;
    end
endgenerate

endmodule
