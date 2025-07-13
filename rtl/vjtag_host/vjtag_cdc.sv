// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: VJtag Host
// Author: Heqing Huang
// Date Created: 07/11/2025
//
// -------------------------------------------------------------------
// vjtag_cdc_hs: Clock domain crossing using handshake
// -------------------------------------------------------------------

module vjtag_cdc #(
    parameter WIDTH = 8     // Payload size
) (
    // CLK A domain
    input  logic                clka,
    input  logic                rst_n_clka,
    input  logic                req_clka,       // request to send a data from clka domain. req is a pulse
    input  logic [WIDTH-1:0]    payload_clka,   // payload from clka domain

    input  logic                clkb,
    input  logic                rst_n_clkb,
    input  logic                ready_clkb,     // indicate clkb domain is ready to take the data
    output logic                valid_clkb,     // payload is synchronized and valid to clkb domain. valid is a pulse
    output logic [WIDTH-1:0]    payload_clkb    // payload synchronized to clkb domain
);

///////////////////////////////////////
// Signal Declaration
///////////////////////////////////////

// clka signal
logic       reql_clka;        // request (level signal)
logic [1:0] ack_dsync_clka;
logic       ack_clka;

// clkb signal
logic [1:0] reql_dsync_clkb;
logic       reql_clkb;
logic       ack_clkb;
logic       capture_clkb;

///////////////////////////////////////
// Main logic
///////////////////////////////////////

// CLKA domain

// cdc handshake request
always_ff @(posedge clka) begin
    if (!rst_n_clka)   reql_clka <= 1'b0;
    else if (req_clka) reql_clka <= 1'b1;   // assert reql when a new request comes in
    else if (ack_clka) reql_clka <= 1'b0;   // de-assert reql when it get ack from clkb
end

// synchronize ack from CLKB to CLKA domain
always_ff @(posedge clka) begin
    if (!rst_n_clka) ack_dsync_clka <= 2'b0;
    else ack_dsync_clka <= {ack_dsync_clka[0], ack_clkb};
end
assign ack_clka = ack_dsync_clka[1];

// CLKB domain

// cdc handshake acknowledge
always_ff @(posedge clkb) begin
    if (!rst_n_clkb)                 ack_clkb <= 1'b0;
    else if (reql_clkb & ready_clkb) ack_clkb <= 1'b1;   // assert ack when a request is received and is ready to be taken
    else if (!reql_clkb)             ack_clkb <= 1'b0;   // de-assert ack when the request de-assert
end

// synchronize req from CLKA to CLKB domain
always_ff @(posedge clkb) begin
    if (!rst_n_clkb) reql_dsync_clkb <= 2'b0;
    else reql_dsync_clkb <= {reql_dsync_clkb[0], reql_clka};
end
assign reql_clkb = reql_dsync_clkb[1];

// capture the data from CLKA to CLKB
assign capture_clkb = reql_clkb & ~ack_clkb;
always_ff @(posedge clkb) begin
    valid_clkb <= capture_clkb;
end

always_ff @(posedge clkb) begin
    if (capture_clkb) payload_clkb <= payload_clka;
end
endmodule
