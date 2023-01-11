`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/02/2023 12:24:53 AM
// Design Name: 
// Module Name: ethernet_tx
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ethernet_tx(
    input rst,
    input ETH_TX_CLK,
    output[4:0] ETH_TXD,
    input write_clk,
    input write_enable,
    input[3:0] write_data
);
    parameter[47:0] DST_MAC = 48'h381428448FAA;
    parameter[47:0] SRC_MAC = 48'h00183E03E2DC;
    parameter[12:0] flush_bytes_threshold = 13'h1;
    localparam[12:0] flush_nibbles = 13'h2 * flush_bytes_threshold;
    localparam[12:0] flush_threshold = flush_nibbles - 13'h1;
    
    logic[3:0] tx_fifo_output;
    logic tx_fifo_notenoughdata;
    logic tx_fifo_rden;


    FIFO_DUALCLOCK_MACRO  #(
        .ALMOST_EMPTY_OFFSET(flush_threshold), // Sets the almost empty threshold
        .DATA_WIDTH(4),   // Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
        .DEVICE("7SERIES"),  // Target device: "7SERIES" 
        .FIFO_SIZE ("36Kb"), // Target BRAM: "18Kb" or "36Kb" 
        .FIRST_WORD_FALL_THROUGH ("TRUE") // Sets the FIFO FWFT to "TRUE" or "FALSE" 
    ) fifo_tx (
        .ALMOSTEMPTY(tx_fifo_notenoughdata), // 1-bit output almost empty
        .ALMOSTFULL(),   // 1-bit output almost full
        .DO(tx_fifo_output),                   // Output data, width defined by DATA_WIDTH parameter
        .EMPTY(),             // 1-bit output empty
        .FULL(),               // 1-bit output full
        .RDCOUNT(),         // Output read count, width determined by FIFO depth
        .RDERR(),             // 1-bit output read error
        .WRCOUNT(),         // Output write count, width determined by FIFO depth
        .WRERR(),             // 1-bit output write error
        .DI(write_data),                   // Input data, width defined by DATA_WIDTH parameter
        .RDCLK(ETH_TX_CLK),             // 1-bit input read clock
        .RDEN(tx_fifo_rden),               // 1-bit input read enable
        .RST(rst),                 // 1-bit input reset
        .WRCLK(write_clk),             // 1-bit input write clock
        .WREN(write_enable)                // 1-bit input write enable
    );

    localparam wait_cycles = 12 * 2; // wait 12 bytes
    localparam frame_cycles = flush_bytes_threshold * 2;
    localparam fcs_cycles = 4 * 2; // 
    localparam preamble_cycles = 8 * 2;
    localparam header_cycles = 42 * 2;

    logic[63:0] preamble_buffer;
    logic[335:0] frame_header;
    
    logic[31:0] checksum;
    logic[15:0] udp_size;
    logic[15:0] ip_size;
    logic[159:0] ip_header;
    logic[63:0] udp_header;
    initial begin
        preamble_buffer = {<<8{64'h55555555555555D5}};
        udp_size = 8 + flush_bytes_threshold;
        ip_size = 20 + udp_size;
        ip_header = {16'h4500, ip_size, 128'hB3FE000080110000C0A80A09C0A80AFE};
        checksum = 0;
        for (int i = 0; i < 160; i += 16) begin
            checksum = checksum + ip_header[i+:16];
        end
        checksum = checksum[31:16] + checksum[15:0];
        checksum = checksum[31:16] + checksum[15:0];
        checksum = ~(checksum[31:16] + checksum[15:0]);
        ip_header[64+:16] = checksum[15:0];
        
        
        udp_header = {32'h04000400, udp_size, 16'h0000};
        frame_header = {DST_MAC, SRC_MAC, 16'h0800, ip_header, udp_header};

        frame_header = {<<8{frame_header}};
    end


logic[15:0] tx_statecounter;
initial tx_statecounter = 0;

typedef enum {
    TX_INIT, TX_PREAMBLE, TX_HEADER,
    TX_DATA,
    TX_FCS, TX_WAIT
} TX_STATE;

TX_STATE tx_state;
initial tx_state = TX_INIT;
TX_STATE tx_nextstate;
always_comb 
case (tx_state)
    TX_INIT: tx_nextstate = tx_fifo_notenoughdata ? TX_INIT : TX_PREAMBLE;
    TX_PREAMBLE: tx_nextstate = tx_statecounter == preamble_cycles - 1 ? TX_HEADER : TX_PREAMBLE;
    TX_HEADER: tx_nextstate = tx_statecounter == header_cycles - 1 ? TX_DATA : TX_HEADER;
    TX_DATA: tx_nextstate = tx_statecounter == frame_cycles - 1 ? TX_FCS : TX_DATA;
    TX_FCS: tx_nextstate = tx_statecounter == fcs_cycles - 1 ? TX_WAIT : TX_FCS;
    TX_WAIT: tx_nextstate = tx_statecounter == wait_cycles - 1 ? TX_INIT : TX_WAIT;
    default: tx_nextstate = TX_INIT;
endcase


logic[3:0] tx_outdata;
logic tx_valid = (tx_state != TX_INIT) & (tx_state != TX_WAIT);
logic[31:0] fcs_out;

crc32 crc(
    .data(tx_outdata),
    .fcsOut(fcs_out),
    .crc_enable((tx_state == TX_HEADER) | (tx_state == TX_DATA)),
    .clk(ETH_TX_CLK)
);



logic[31:0] fcs_buffer;
assign tx_fifo_rden = tx_state == TX_DATA;


always_ff @(posedge ETH_TX_CLK) begin

    tx_statecounter <= tx_state == tx_nextstate ? tx_statecounter + 1 : 0;
    tx_state <= tx_nextstate;
    if (tx_state == TX_PREAMBLE) begin
        preamble_buffer <= {preamble_buffer[3:0], preamble_buffer[63:4]};
    end
    if (tx_state == TX_HEADER) begin
        frame_header <= {frame_header[3:0], frame_header[335:4]};
    end
    if (tx_nextstate == TX_FCS) begin
        fcs_buffer <= tx_state == TX_DATA ? fcs_out : {4'bXXXX, fcs_buffer[31:4]};
    end
end

always_comb
case (tx_state) 
    TX_PREAMBLE: tx_outdata = preamble_buffer[3:0];
    TX_HEADER: tx_outdata = frame_header[3:0];
    TX_DATA: tx_outdata = tx_fifo_output;
    TX_FCS: tx_outdata = fcs_buffer[3:0];
    default: tx_outdata = 4'bXXXX;
endcase
assign ETH_TXD = {tx_valid, tx_outdata};
endmodule
