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
    parameter AW = 8,   // address width
    parameter DW = 8    // data width
) (

    // vjtag ip (on tck clock domain)
    output logic [1:0]      ir_out,     // Virtual JTAG instruction register output.
                                        // The value is captured whenever virtual_state_cir is high
    output logic            tdo,        // Writes to the TDO pin on the device
    input  logic [1:0]      ir_in,      // Virtual JTAG instruction register data.
                                        // The value is available and latched when virtual_state_uir is high
    input  logic            tck,        // JTAG test clock
    input  logic            tdi,        // TDI input data on the device. Used when virtual_state_sdr is high
    input  logic            cdr,        // virtual JTAG is in Capture_DR state
    input  logic            cir,        // virtual JTAG is in Capture_IR state
    input  logic            e1dr,       // virtual JTAG is in Exit1_DR state
    input  logic            e2dr,       // virtual JTAG is in Exit2_DR state
    input  logic            pdr,        // virtual JTAG is in Pause_DR state
    input  logic            sdr,        // virtual JTAG is in Shift_DR state
    input  logic            udr,        // virtual JTAG is in Update_DR state
    input  logic            uir,        // virtual JTAG is in Update_IR state

    // system bus (on clk clock domain)
    input  logic            clk,
    input  logic            rst_n,
    output logic            rst_n_out,  // reset output
    output logic [AW-1:0]   address,    // address
    output logic            wvalid,     // write request
    output logic [DW-1:0]   wdata,      // write data
    input  logic            wready,     // write ready
    output logic            rvalid,     // read request
    input  logic            rready,     // read ready
    input  logic            rrvalid,    // read response valid
    input  logic [DW-1:0]   rdata       // read data
);

///////////////////////////////////////
// Signal Declaration
///////////////////////////////////////

// Commands
localparam  CMD_READ  = 8'h1,
            CMD_WRITE = 8'h2,
            CMD_RST_A = 8'hFE,  // reset assertion
            CMD_RST_D = 8'hFF;  // reset de-assertion

// -- tck domain signal --

logic [1:0]     rst_n_dsync_tck;
logic           rst_n_tck;  // synchronized rst_n to tck
logic           is_cmd;
logic           is_addr;
logic           is_data;
logic [7:0]     dr_cmd;
logic [AW-1:0]  dr_addr;
logic [DW-1:0]  dr_wdata;
logic [DW-1:0]  dr_rdata;

// -- clk domain signal --

logic           request;    // a pulse indicate a new request is received from vjtag
logic           ready;
logic [7:0]     cmd;
logic [DW-1:0]  rdata_q;    // store read data
logic           rrvalid_q;  // store read valid

// bus request state machine
localparam      IDLE = 0,
                REQ  = 1,
                READ = 2;

logic [1:0]     state, state_next;
logic           is_write;
logic           is_read;

///////////////////////////////////////
// Main logic
///////////////////////////////////////


// ------------------------------------
//              TCK domain
// ------------------------------------

// synchronize rst_n to TCK domain
always @(posedge tck) begin
    rst_n_dsync_tck <= {rst_n_dsync_tck[0], rst_n};
end
assign rst_n_tck = rst_n_dsync_tck[1];

// Decode the VIR
assign is_cmd  = ir_in == 0;
assign is_addr = ir_in == 1;
assign is_data = ir_in == 2;

// Data Register
always_ff @(posedge tck) begin
    if (is_cmd  && sdr) dr_cmd <= {tdi, dr_cmd[7:1]};
    if (is_addr && sdr) dr_cmd <= {tdi, dr_addr[AW-1:1]};
    if (is_data && sdr) dr_cmd <= {tdi, dr_wdata[DW-1:1]};
end

// TDO - FIXME
always_ff @(posedge tck) begin
    if (sdr) tdo <= {dr_wdata[0]};
end

// ------------------------------------
//              CLK domain
// ------------------------------------

// Bus request state machine
always_ff @(posedge clk) begin
    if (!rst_n) state <= IDLE;
    else        state <= state_next;
end

always_comb begin
    state_next = state;
    case(state)
        IDLE: begin
            if (request) begin
                if      (wvalid) state_next = wready ? IDLE : REQ;
                else if (rvalid) state_next = rready ? READ : REQ;
            end
        end
        REQ: begin
            if      (wvalid && wready) state_next = IDLE;
            else if (rvalid && rready) state_next = READ;
        end
        READ: begin
            if (rrvalid) state_next = IDLE;
        end
    endcase
end

always_ff @(posedge clk) begin
    if (!rst_n) begin
        wvalid <= 1'b0;
        rvalid <= 1'b0;
    end
    else begin
        case(state_next)
            IDLE: begin
                wvalid <= request & is_write;
                rvalid <= request & is_read;
            end
            REQ: begin
                wvalid <= is_write;
                rvalid <= is_read;
            end
        endcase
    end
end

// Handle read data
always @(posedge clk) begin
    if (!rst_n) rrvalid_q <= 1'b0;
    else begin
        rrvalid_q <= rvalid;
        rdata_q <= rdata;
    end
end

assign is_write = cmd == CMD_WRITE;
assign is_read  = cmd == CMD_READ;
assign ready = state == IDLE;

// Handle Reset Command
always @(posedge clk) begin
    if (!rst_n) rst_n_out <= 1'b1;
    else begin
        if (request) begin
            if      (cmd == CMD_RST_A) rst_n_out <= 1'b0;
            else if (cmd == CMD_RST_D) rst_n_out <= 1'b1;
        end
    end
end

// ------------------------------------
//              CDC Logic
// ------------------------------------

// synchronize the request from tck to clk when udr is asserted
// Note:

vjtag_cdc #(.WIDTH(8+AW+DW))
u_vjtag_clk_tck2clk(
    .clka           (tck),
    .rst_n_clka     (rst_n_tck),
    .req_clka       (udr),
    .payload_clka   ({dr_cmd, dr_addr, dr_wdata}),
    .clkb           (clk),
    .rst_n_clkb     (rst_n),
    .ready_clkb     (ready),
    .valid_clkb     (request),
    .payload_clkb   ({cmd, address, wdata})
);

// synchronize the read data from clk to tck
// This does not work because the tck will stop . TBD
vjtag_cdc #(.WIDTH(DW))
u_vjtag_clk_clk2tck(
    .clka           (clk),
    .rst_n_clka     (rst_n),
    .req_clka       (rrvalid_q),
    .payload_clka   (rdata_q),
    .clkb           (tck),
    .rst_n_clkb     (rst_n_tck),
    .ready_clkb     (1'b1),
    .valid_clkb     (),
    .payload_clkb   (dr_rdata)
);


endmodule
