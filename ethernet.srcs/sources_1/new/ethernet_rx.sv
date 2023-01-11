`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/02/2023 12:11:29 AM
// Design Name: 
// Module Name: ethernet_rx
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


module ethernet_rx(
    input rst,
    input ETH_RX_CLK,
    input[5:0] ETH_RXD,
    input read_clk,
    input read_enable,
    output almostempty,
    output[3:0] out_data
);
    parameter[47:0] SRC_MAC = 48'h381428448FAA;
    parameter[47:0] DST_MAC = 48'h00183E03E2DC;
    parameter[12:0] flush_bytes_threshold = 13'h1;
    localparam[12:0] flush_nibbles = 13'h2 * flush_bytes_threshold;
    localparam[12:0] flush_threshold = flush_nibbles - 13'h1;
    logic[3:0] rx_fifo_input;
    logic rx_fifo_wren;

    FIFO_DUALCLOCK_MACRO  #(
        .ALMOST_EMPTY_OFFSET(flush_threshold), // Sets the almost empty threshold
        .DATA_WIDTH(4),   // Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
        .DEVICE("7SERIES"),  // Target device: "7SERIES" 
        .FIFO_SIZE ("36Kb"), // Target BRAM: "18Kb" or "36Kb" 
        .FIRST_WORD_FALL_THROUGH ("TRUE") // Sets the FIFO FWFT to "TRUE" or "FALSE" 
    ) fifo_rx (
        .ALMOSTEMPTY(almostempty), // 1-bit output almost empty
        .ALMOSTFULL(),   // 1-bit output almost full
        .DO(out_data),                   // Output data, width defined by DATA_WIDTH parameter
        .EMPTY(),             // 1-bit output empty
        .FULL(),               // 1-bit output full
        .RDCOUNT(),         // Output read count, width determined by FIFO depth
        .RDERR(),             // 1-bit output read error
        .WRCOUNT(),         // Output write count, width determined by FIFO depth
        .WRERR(),             // 1-bit output write error
        .DI(rx_fifo_input),                   // Input data, width defined by DATA_WIDTH parameter
        .RDCLK(read_clk),             // 1-bit input read clock
        .RDEN(read_enable),               // 1-bit input read enable
        .RST(rst),                 // 1-bit input reset
        .WRCLK(ETH_RX_CLK),             // 1-bit input write clock
        .WREN(rx_fifo_wren)                // 1-bit input write enable
    );

    logic[143:0] rxmatch;
    logic[15:0] rx_statecounter;
    logic[15:0] ip_size;
    initial begin 
        ip_size = flush_bytes_threshold + 20 + 8;
        rxmatch = {DST_MAC, SRC_MAC, 32'h08004500, ip_size};
        rxmatch = {<<8{rxmatch}};
        rx_statecounter = 0;
    end

typedef enum {
    RX_PREAMBLE, RX_STARTFRAME, RX_HEADERCHECK,
    RX_PAYLOAD,
    RX_IGNORE
} RX_STATE;
RX_STATE rx_state;
initial rx_state = RX_PREAMBLE;
logic[3:0] rx_nibble = ETH_RXD[3:0];
RX_STATE rx_nextstate;
always_comb begin
    case (rx_state)
        RX_PREAMBLE: begin
            rx_nextstate = rx_nibble == 4'h5 ? RX_STARTFRAME : RX_PREAMBLE;
        end
        RX_STARTFRAME: begin
            rx_nextstate = rx_nibble == 4'hd ? RX_HEADERCHECK :
                            rx_nibble == 4'h5 ? RX_STARTFRAME :
                                                RX_IGNORE;
        end
        RX_HEADERCHECK: begin
            if (rx_nibble == rxmatch[{rx_statecounter, 2'd0}+:4]) begin
                rx_nextstate = rx_statecounter == 35 ? RX_PAYLOAD : RX_HEADERCHECK;
            end
            else rx_nextstate = RX_IGNORE;
        end
        RX_PAYLOAD: rx_nextstate = RX_PAYLOAD;
        RX_IGNORE: rx_nextstate = RX_IGNORE;
        default: rx_nextstate = RX_PREAMBLE;
    endcase
    rx_nextstate = ETH_RXD[4] ? rx_nextstate : RX_PREAMBLE;
    rx_nextstate = ETH_RXD[5] ? RX_IGNORE : rx_nextstate;
end


assign rx_fifo_input = rx_nibble;
assign rx_fifo_wren = (rx_state == RX_PAYLOAD) & (rx_statecounter >= 48) & (rx_statecounter < 48 + flush_nibbles);

always_ff @(posedge ETH_RX_CLK) begin
    rx_statecounter <= rx_state == rx_nextstate ? rx_statecounter + 1 : 0;
    rx_state <= rx_nextstate;
end
endmodule
