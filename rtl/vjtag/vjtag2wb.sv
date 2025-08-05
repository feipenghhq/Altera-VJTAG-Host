// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: VJtag Host
// Author: Heqing Huang
// Date Created: 08/03/2025
//
// -------------------------------------------------------------------
// vjtag2wb: Virtual JTAG to wishbone
//   - Wishbone B4 Pipeline Protocol
//
// Limitation:
//  The VJTAG interface does not support back-pressure. One transaction
//  MUST complete before the next transaction arrives.
// -------------------------------------------------------------------

module vjtag2wb #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 16
)(
    input  logic                    clk,
    input  logic                    rst_n,

    output logic                    rst_n_out,   // reset output

    // wishbone b4
    output logic                    wb_cyc_o,
    output logic                    wb_stb_o,
    output logic                    wb_we_o,
    output logic [ADDR_WIDTH-1:0]   wb_adr_o,
    input  logic [DATA_WIDTH-1:0]   wb_dat_i,
    output logic [DATA_WIDTH-1:0]   wb_dat_o,
    input  logic                    wb_ack_i,
    input  logic                    wb_stall_i
);

    logic [7:0] ir_in, ir_out;
    logic       tck, tdi, tdo;
    logic       cdr, cir, e1dr, e2dr, pdr, sdr, udr, uir;

    logic [ADDR_WIDTH-1:0]   address;
    logic                    rvalid;
    logic                    wvalid;
    logic [DATA_WIDTH-1:0]   wdata;
    logic                    ready;
    logic                    rsp_valid;
    logic [DATA_WIDTH-1:0]   rsp_data;

    logic wb_cyc_hold;

    assign wb_cyc_o = wvalid | rvalid | wb_cyc_hold;
    assign wb_stb_o = wvalid | rvalid;
    assign wb_adr_o = address;
    assign wb_dat_o = wdata;
    assign wb_we_o  = wvalid;

    assign ready = ~wb_stall_i;
    assign rsp_data = wb_dat_i;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rsp_valid <= 1'b0;
            wb_cyc_hold <= 1'b0;
        end
        else begin
            if (wb_ack_i) wb_cyc_hold <= 1'b0;
            else if (wvalid | rvalid) wb_cyc_hold <= 1'b1;

            if (wb_cyc_o && wb_stb_o && !wb_stall_i && !wb_we_o) rsp_valid <= 1'b1;
            else rsp_valid <= 1'b0;
        end
    end

    // Instantiate VJTAG IP
    vjtag_ip u_vjtag_ip (
        .ir_out             (ir_out),
        .tdo                (tdo),
        .ir_in              (ir_in),
        .tck                (tck),
        .tdi                (tdi),
        .virtual_state_cdr  (cdr),
        .virtual_state_cir  (cir),
        .virtual_state_e1dr (e1dr),
        .virtual_state_e2dr (e2dr),
        .virtual_state_pdr  (pdr),
        .virtual_state_sdr  (sdr),
        .virtual_state_udr  (udr),
        .virtual_state_uir  (uir)
    );

    // Instantiate VJTAG control module
    vjtag_ctrl #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_vjtag_ctrl (
        .ir_out     (ir_out),
        .tdo        (tdo),
        .ir_in      (ir_in),
        .tck        (tck),
        .tdi        (tdi),
        .cdr        (cdr),
        .cir        (cir),
        .e1dr       (e1dr),
        .e2dr       (e2dr),
        .pdr        (pdr),
        .sdr        (sdr),
        .udr        (udr),
        .uir        (uir),
        .clk        (clk),
        .rst_n      (rst_n),
        .rst_n_out  (rst_n_out),
        .address    (address),
        .wvalid     (wvalid),
        .wdata      (wdata),
        .ready      (ready),
        .rvalid     (rvalid),
        .rsp_valid  (rsp_valid),
        .rsp_data   (rsp_data)
    );

endmodule
