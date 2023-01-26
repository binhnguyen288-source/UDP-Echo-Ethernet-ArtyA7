`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/23/2022 06:27:51 PM
// Design Name: 
// Module Name: top
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


module top(
    input clk100Mhz,
    output ETH_RSTN,
    output[4:0] ETH_TXD,
    output ETH_REFCLK,
    output ETH_MDC,
    inout ETH_MDIO,
    input ETH_TX_CLK,
    input ETH_RX_CLK,
    input[5:0] ETH_RXD,
    input ps2_clk,
    input ps2_data
);

    logic fb_clk, pll_locked;
    logic clk25Mhz;
    logic process_clk;

    PLLE2_BASE #(
        .CLKFBOUT_MULT(8),
        .CLKIN1_PERIOD(10.0),
        .CLKOUT0_DIVIDE(32)
    ) PLLE2_BASE_inst (
        // Clock Outputs: 1-bit (each) output: User configurable clock outputs
        .CLKOUT0(clk25Mhz),   // 1-bit output: CLKOUT0
        .CLKOUT1(),   // 1-bit output: CLKOUT1
        .CLKOUT2(),   // 1-bit output: CLKOUT2
        .CLKOUT3(),   // 1-bit output: CLKOUT3
        .CLKOUT4(),   // 1-bit output: CLKOUT4
        .CLKOUT5(),   // 1-bit output: CLKOUT5
        // Feedback Clocks: 1-bit (each) output: Clock feedback ports
        .CLKFBOUT(fb_clk), // 1-bit output: Feedback clock
        .LOCKED(pll_locked),     // 1-bit output: LOCK
        .CLKIN1(clk100Mhz),     // 1-bit input: Input clock
        // Control Ports: 1-bit (each) input: PLL control ports
        .PWRDWN(1'b0),     // 1-bit input: Power-down
        .RST(1'b0),           // 1-bit input: Reset
        // Feedback Clocks: 1-bit (each) input: Clock feedback ports
        .CLKFBIN(fb_clk)    // 1-bit input: Feedback clock
    );

    assign ETH_REFCLK = clk25Mhz;
    assign ETH_MDC = 1'b0;
    assign ETH_MDIO = 1'bZ;
    assign ETH_RSTN = pll_locked;

    assign process_clk = clk25Mhz;

    

    
    logic ether_rx_rden;
    logic ether_rx_notenoughdata;
    logic[3:0] ether_rx_data;

    localparam[12:0] rx_payload_size = 13'h80;
    localparam[12:0] tx_payload_size = 13'h80;

    localparam rx_bits = rx_payload_size * 8;
    localparam tx_bits = tx_payload_size * 8;

    ethernet_rx #(
        .flush_bytes_threshold(rx_payload_size)
    ) ether_rx(
        .rst(~pll_locked),
        .ETH_RX_CLK(ETH_RX_CLK),
        .ETH_RXD(ETH_RXD),
        .read_clk(process_clk),
        .read_enable(ether_rx_rden),
        .almostempty(ether_rx_notenoughdata),
        .out_data(ether_rx_data)
    );

    logic ether_tx_wren;
    logic[3:0] ether_tx_data;

    ethernet_tx #(
        .flush_bytes_threshold(tx_payload_size)
    ) ether_tx(
        .rst(~pll_locked),
        .ETH_TXD(ETH_TXD),
        .ETH_TX_CLK(ETH_TX_CLK),
        .write_clk(process_clk),
        .write_enable(ether_tx_wren),
        .write_data(ether_tx_data)
    );

    typedef enum {
        PROCESS_WAIT,
        PROCESS_LOADDATA,
        PROCESS_INIT,
        PROCESS_CALC,
        PROCESS_TRANSFER
    } PROCESS_STATE;

    PROCESS_STATE proc_state;
    initial proc_state = PROCESS_WAIT;
    logic[15:0] proc_statecounter;
    initial proc_statecounter = 0;
    logic[rx_bits-1:0] message;
    logic[tx_bits-1:0] send_buffer;


    logic calc_done = 1'b1;

    PROCESS_STATE proc_nextstate;
    always_comb
    case (proc_state)
        PROCESS_WAIT: proc_nextstate = ether_rx_notenoughdata ? PROCESS_WAIT : PROCESS_LOADDATA;
        PROCESS_LOADDATA: proc_nextstate = proc_statecounter == rx_payload_size * 2 - 1 ? PROCESS_INIT : PROCESS_LOADDATA;
        PROCESS_INIT: proc_nextstate = PROCESS_CALC;
        PROCESS_CALC: proc_nextstate = calc_done ? PROCESS_TRANSFER : PROCESS_CALC;
        PROCESS_TRANSFER: proc_nextstate = proc_statecounter == tx_payload_size * 2 - 1 ? PROCESS_WAIT : PROCESS_TRANSFER;
        default: proc_nextstate = PROCESS_WAIT;
    endcase

    assign ether_rx_rden = proc_state == PROCESS_LOADDATA;
    assign ether_tx_wren = proc_state == PROCESS_TRANSFER;
    assign ether_tx_data = send_buffer[3:0];


    always_ff @(posedge process_clk) begin
        proc_state <= proc_nextstate;
        proc_statecounter <= proc_state == proc_nextstate ? proc_statecounter + 1 : 0;

        case (proc_state)
            PROCESS_LOADDATA: message[{proc_statecounter, 2'b00}+:4] <= ether_rx_data;
            PROCESS_CALC: send_buffer <= message;
            PROCESS_TRANSFER: send_buffer <= {4'bXXXX, send_buffer[tx_bits-1:4]};
            default: ;
        endcase

    end



endmodule