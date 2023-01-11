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
    input[5:0] ETH_RXD
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
    localparam[12:0] tx_payload_size = 13'h100;

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


    logic calc_done;

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

    logic[2047:0] calc_result;
    do_calc calc(
        .rst(proc_state == PROCESS_INIT),
        .clk(process_clk),
        .value(message),
        .result(calc_result),
        .done(calc_done)
    );

    always_ff @(posedge process_clk) begin
        proc_state <= proc_nextstate;
        proc_statecounter <= proc_state == proc_nextstate ? proc_statecounter + 1 : 0;

        case (proc_state)
            PROCESS_LOADDATA: message[{proc_statecounter, 2'b00}+:4] <= ether_rx_data;
            PROCESS_CALC: if (calc_done) send_buffer <= calc_result;
            PROCESS_TRANSFER: send_buffer <= {4'bXXXX, send_buffer[tx_bits-1:4]};
            default: ;
        endcase

    end



endmodule


module do_calc(
    input rst,
    input clk,
    input[1023:0] value,
    output[2047:0] result,
    output done
);
//     logic[15:0] cycles;
//     initial cycles = 128;
//     logic[1535:0] res_low;
//     logic[1535:0] res_high;

//     logic[15:0] base_mult = {cycles, 4'b0000};
//     logic[15:0] base_mult_prev = {cycles - 16'h1, 4'b0000};
//     logic[15:0] base_mult_hi = {cycles ^ 16'd64, 4'b0000};
//     logic[511:0] lower = value[511:0];
//     logic[511:0] upper = value[1023:512];
//     logic[527:0] last_mul;

//     always_ff @(posedge clk) begin
//         if (rst) begin 
//             cycles   <= 16'h0;
//             res_low  <= 1536'h0;
//             res_high <= 1536'h0;
//             last_mul <= 528'h0;
//         end
//         else if (cycles < 64) begin
// //            if (cycles != 0) begin
// //                res_low [base_mult_prev+:528] <= res_low [base_mult_prev+:528] + last_mul;
// //            end
// //            if (cycles != 64) begin
// //                last_mul <= lower * value[base_mult+:16];
// //            end
//              res_low [base_mult+:528] <= res_low [base_mult+:528] + last_mul;
//             cycles   <= cycles + 1;
//         end
//     end
// //     logic add_done;
// //     adder_seq final_adder(
// //         .clk(clk),
// //         .rst(cycles == 127),
         
// //         .a({528'h0, res_low}),
// //         .b({16'h0, res_high, 512'h0}),
// //         .sumout(result),
// //         .done(add_done)
// //     );
//      assign result = res_high + res_low;
    assign result = {value, value};
    assign done = 1'b1;
endmodule


module mul128x128(
    input[127:0] a,
    input[127:0] b,
    output[255:0] c
);

    
    logic[127:0] z0;
    logic[127:0] z2;
    logic[127:0] temp_z1;
    


    logic[63:0] abs_a = (a[63:0] < a[127:64]) ? a[127:64] - a[63:0] : a[63:0] - a[127:64];
    logic[63:0] abs_b = (b[127:64] < b[63:0]) ? b[63:0] - b[127:64] : b[127:64] - b[63:0];
    
    mul64x64 mulz0(.a(a[63:0]), .b(b[63:0]), .c(z0));
    mul64x64 mulz1(.a(abs_a), .b(abs_b), .c(temp_z1));
    mul64x64 mulz2(.a(a[127:64]), .b(b[127:64]), .c(z2));

    logic sign = (a[63:0] < a[127:64]) ^ (b[127:64] < b[63:0]);

    logic[128:0] z1 = (z0 + z2) + (sign ? -temp_z1 : temp_z1);

    assign c = {z2, z0} + {z1, {64{1'b0}}};

endmodule

module mul64x64(
    input[63:0] a,
    input[63:0] b,
    output[127:0] c
);
    logic[63:0] z0; 
    logic[63:0] z2;
    mul32x32 mulz0(.a(a[31:0]), .b(b[31:0]), .c(z0));
    mul32x32 mulz2(.a(a[63:32]), .b(b[63:32]), .c(z2));
    logic[64:0] z1 = (a[31:0] + a[63:32]) * (b[31:0] + b[63:32]) - z0 - z2;
    assign c = {z2, z0} + {z1, {32{1'b0}}};
endmodule


module mul32x32(
    input[31:0] a,
    input[31:0] b,
    output[63:0] c
);
    logic[31:0] z0 = a[31:16] * b[31:16];
    logic[31:0] z2 = a[15:0] * b[15:0];
    logic[32:0] z1 = (a[31:16] + a[15:0]) * (b[31:16] + b[15:0]) - z0 - z2;
    assign c = {z2, z0} + {z1, {16{1'b0}}};
endmodule