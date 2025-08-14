// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: VJtag Host
// Author: Heqing Huang
// Date Created: 07/11/2025
//
// -------------------------------------------------------------------
// vjtag_ctrl: control logic for bus access
// -------------------------------------------------------------------

module vjtag_ctrl #(
    parameter ADDR_WIDTH = 16,   // address width
    parameter DATA_WIDTH = 16    // data width
) (

    // vjtag ip (on tck clock domain)
    output logic [7:0]              ir_out,     // Virtual JTAG instruction register output.
                                                // The value is captured whenever virtual_state_cir is high
    output logic                    tdo,        // Writes to the TDO pin on the device
    input  logic [7:0]              ir_in,      // Virtual JTAG instruction register data.
                                                // The value is available and latched when virtual_state_uir is high
    input  logic                    tck,        // JTAG test clock
    input  logic                    tdi,        // TDI input data on the device. Used when virtual_state_sdr is high
    input  logic                    cdr,        // virtual JTAG is in Capture_DR state
    input  logic                    cir,        // virtual JTAG is in Capture_IR state
    input  logic                    e1dr,       // virtual JTAG is in Exit1_DR state
    input  logic                    e2dr,       // virtual JTAG is in Exit2_DR state
    input  logic                    pdr,        // virtual JTAG is in Pause_DR state
    input  logic                    sdr,        // virtual JTAG is in Shift_DR state
    input  logic                    udr,        // virtual JTAG is in Update_DR state
    input  logic                    uir,        // virtual JTAG is in Update_IR state

    // system bus (on clk clock domain)
    input  logic                    clk,
    input  logic                    rst_n,
    output logic                    rst_n_out,  // reset output
    output logic                    req_valid,  // request valid
    output logic [ADDR_WIDTH-1:0]   req_addr,   // address, aligned to BYTE
    output logic                    req_write,  // 0: read request, 1: write request
    output logic [DATA_WIDTH-1:0]   req_wdata,  // write data
    input  logic                    req_ready,  // ready

    input  logic                    rsp_valid,  // read response valid
    input  logic [DATA_WIDTH-1:0]   rsp_rdata   // read data
);

///////////////////////////////////////
// Signal Declaration
///////////////////////////////////////

localparam IRW = 8;                 // IR width
localparam DRW = ADDR_WIDTH + DATA_WIDTH;           // DR width

// Commands
localparam  CMD_READ  = 8'h1,
            CMD_WRITE = 8'h2,
            CMD_RST_A = 8'hFE,      // reset assertion
            CMD_RST_D = 8'hFF;      // reset de-assertion

// -- tck domain signal --

logic [1:0]             rst_n_dsync_tck;
logic [DRW-1:0]         dr;
logic [DATA_WIDTH-1:0]  rsp_data_tck;          // synchronized rsp_data on TCK domain


// -- clk domain signal --

logic [1:0]     udr_dsync_sys;      // double synchronizer for udr to CLK domain
logic           udr_sys;            // synchronized udr on CLK domain
logic [IRW-1:0] ir_sys;             // synchronized ir on CLK domain
logic [DRW-1:0] dr_sys;             // synchronized dr on CLK domain

logic           udr_q_sys;          // delayed version of udr_sys
logic           update;             // update the ir and dr on CLK domain
logic           request;            // request to initiate bus request

// bus request state machine
typedef enum logic [1:0] {
    IDLE,
    REQ,
    READ
} state_t;

state_t state, state_next;

logic                   is_write;
logic                   is_read;
logic [DATA_WIDTH-1:0]  rsp_data_q;

///////////////////////////////////////
// Main logic
///////////////////////////////////////

// Implementation Note:
// - IR holds the Bus command, and DR holds the remaining data (address, write data)
// When Host send transaction through VJTAG to FPGA:
// - ir_in contains the command.
// - When the `sdr` signal is asserted, the remaining data are shifted into the **DR** via the `tdi` pin.
// - When shifting is complete, `sdr` is de-asserted and `udr` is asserted.
// - The `tck` signal toggles only during active data shifting. Once `udr` is asserted, `tck` remains idle until
//   the next transaction begins. `udr` also remains asserted until the next transaction begins.

// ------------------------------------
//              TCK domain
// ------------------------------------

// Data Register (dr)
always_ff @(posedge tck) begin
    if (cdr) dr <= {{ADDR_WIDTH{1'b0}}, rsp_data_q}; // rsp_data_q is in CLK domain but considered as quasi-static
    if (sdr) dr <= {tdi, dr[DRW-1:1]};
end

// tdo
assign tdo = dr[0];

// ir_out
assign ir_out = ir_in;

// ------------------------------------
//              CLK domain
// ------------------------------------

// request should be flop version of update as ir/dr is updated after update is asserted
always @(posedge clk) begin
    if (!rst_n) request <= 1'b0;
    else        request <= update;
end

// Bus request state machine
always_ff @(posedge clk) begin
    if (!rst_n) state <= IDLE;
    else        state <= state_next;
end

always_comb begin
    state_next = state;
    case(state)
        IDLE: begin
            if (req_valid) begin
                if (!req_ready) state_next = state_t'(REQ);
                else if (!req_write) state_next = state_t'(READ);
            end
        end
        REQ: begin
            if      (req_valid &&  req_write && req_ready) state_next = IDLE;
            else if (req_valid && !req_write && req_ready) state_next = READ;
        end
        READ: begin
            if (rsp_valid) state_next = IDLE;
        end
    endcase
end

always_ff @(posedge clk) begin
    if (!rst_n) begin
        req_valid <= 1'b0;
        req_write <= 1'b0;
    end
    else begin
        req_valid <= 1'b0;
        req_write <= 1'b0;
        // Note: use next state here
        case(state_next)
            IDLE: begin
                req_valid <= request & (is_write | is_read);
                req_write <= request & is_write;
            end
            REQ: begin
                req_valid <= 1'b1;
                req_write <= is_write;
            end
            READ: begin
                if (state != READ) begin // entering READ state
                    req_valid <= 1'b0;
                    req_write <= 1'b0;
                end
            end
        endcase
    end
end

assign is_write  = ir_sys == CMD_WRITE;
assign is_read   = ir_sys == CMD_READ;
assign req_wdata = dr_sys[DATA_WIDTH-1:0];
assign req_addr  = dr_sys[ADDR_WIDTH+DATA_WIDTH-1:DATA_WIDTH];

// Handle read data
always @(posedge clk) begin
    if (rsp_valid) rsp_data_q <= rsp_rdata;
end


// Handle Reset Command
always @(posedge clk) begin
    if (!rst_n) rst_n_out <= 1'b1;
    else begin
        if (request) begin
            if      (ir_sys == CMD_RST_A) rst_n_out <= 1'b0;
            else if (ir_sys == CMD_RST_D) rst_n_out <= 1'b1;
        end
    end
end

// ------------------------------------
//              CDC Logic
// ------------------------------------

// -- TCK -> CLK --

// synchronize udr
always @(posedge clk) begin
    if (!rst_n) udr_dsync_sys <= 2'b0;
    else        udr_dsync_sys <= {udr_dsync_sys[0], udr};
end
assign udr_sys = udr_dsync_sys[1];

// create a pulse from udr
always @(posedge clk) begin
    if (!rst_n) udr_q_sys <= 1'b0;
    else        udr_q_sys <= udr_sys;
end
assign update = udr_sys & ~udr_q_sys;

// use the udr pulse as a qualifier to capture ir and dr to CLK domain
always @(posedge clk) begin
    if (update) begin
        ir_sys <= ir_in;
        dr_sys <= dr;
    end
end

// -- CLK -> TCK --
// TCK is usually running slower then CLK.
// When VJTAG issue command to read the data back, the read data should already been captured in rsp_data_q register.
// We can consider rsp_data_q as quasi-static hence no need to synchronize it from CLK to TCK

endmodule
