`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/05/2023 07:50:37 AM
// Design Name: 
// Module Name: adder_seq
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


module adder48_seq(
    input clk,
    input rst,
    input[47:0] a,
    input[47:0] b,
    output[47:0] result
);
    wire[3:0] carry_out;
    reg cin = 0;
    DSP48E1 #(
      // Feature Control Attributes: Data Path Selection
      .A_INPUT("DIRECT"),               // Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
      .B_INPUT("DIRECT"),               // Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
      .USE_DPORT("FALSE"),              // Select D port usage (TRUE or FALSE)
      .USE_MULT("NONE"),            // Select multiplier usage ("MULTIPLY", "DYNAMIC", or "NONE")
      .USE_SIMD("ONE48"),               // SIMD selection ("ONE48", "TWO24", "FOUR12")
      // Pattern Detector Attributes: Pattern Detection Configuration
      .AUTORESET_PATDET("NO_RESET"),    // "NO_RESET", "RESET_MATCH", "RESET_NOT_MATCH" 
      .MASK(48'h3fffffffffff),          // 48-bit mask value for pattern detect (1=ignore)
      .PATTERN(48'h000000000000),       // 48-bit pattern match for pattern detect
      .SEL_MASK("MASK"),                // "C", "MASK", "ROUNDING_MODE1", "ROUNDING_MODE2" 
      .SEL_PATTERN("PATTERN"),          // Select pattern value ("PATTERN" or "C")
      .USE_PATTERN_DETECT("NO_PATDET"), // Enable pattern detect ("PATDET" or "NO_PATDET")
      // Register Control Attributes: Pipeline Register Configuration
      .ACASCREG(0),                     // Number of pipeline stages between A/ACIN and ACOUT (0, 1 or 2)
      .ADREG(0),                        // Number of pipeline stages for pre-adder (0 or 1)
      .ALUMODEREG(0),                   // Number of pipeline stages for ALUMODE (0 or 1)
      .AREG(0),                         // Number of pipeline stages for A (0, 1 or 2)
      .BCASCREG(0),                     // Number of pipeline stages between B/BCIN and BCOUT (0, 1 or 2)
      .BREG(0),                         // Number of pipeline stages for B (0, 1 or 2)
      .CARRYINREG(0),                   // Number of pipeline stages for CARRYIN (0 or 1)
      .CARRYINSELREG(0),                // Number of pipeline stages for CARRYINSEL (0 or 1)
      .CREG(0),                         // Number of pipeline stages for C (0 or 1)
      .DREG(1),                         // Number of pipeline stages for D (0 or 1)
      .INMODEREG(0),                    // Number of pipeline stages for INMODE (0 or 1)
      .MREG(0),                         // Number of multiplier pipeline stages (0 or 1)
      .OPMODEREG(0),                    // Number of pipeline stages for OPMODE (0 or 1)
      .PREG(0)                          // Number of pipeline stages for P (0 or 1)
   )
   DSP48E1_inst (
      // Cascade: 30-bit (each) output: Cascade Ports
      .ACOUT(),                   // 30-bit output: A port cascade output
      .BCOUT(),                   // 18-bit output: B port cascade output
      .CARRYCASCOUT(),     // 1-bit output: Cascade carry output
      .MULTSIGNOUT(),       // 1-bit output: Multiplier sign cascade output
      .PCOUT(),                   // 48-bit output: Cascade output
      // Control: 1-bit (each) output: Control Inputs/Status Bits
      .OVERFLOW(),             // 1-bit output: Overflow in add/acc output
      .PATTERNBDETECT(), // 1-bit output: Pattern bar detect output
      .PATTERNDETECT(),   // 1-bit output: Pattern detect output
      .UNDERFLOW(),           // 1-bit output: Underflow in add/acc output
      // Data: 4-bit (each) output: Data Ports
      .CARRYOUT(carry_out),             // 4-bit output: Carry output
      .P(result),                           // 48-bit output: Primary data output
      // Cascade: 30-bit (each) input: Cascade Ports
      .ACIN(30'd0),                     // 30-bit input: A cascade data input
      .BCIN(18'd0),                     // 18-bit input: B cascade input
      .CARRYCASCIN(1'b0),       // 1-bit input: Cascade carry input
      .MULTSIGNIN(1'b0),         // 1-bit input: Multiplier sign input
      .PCIN(),                     // 48-bit input: P cascade input
      // Control: 4-bit (each) input: Control Inputs/Status Bits
      .ALUMODE(4'b0000),               // X + Y + Z + Cin
      .CARRYINSEL(3'b000),         // carrycascadeout select
      .CLK(1'b0),                       // 1-bit input: Clock input
      .INMODE(5'b00000),                 // 5-bit input: INMODE control input
      .OPMODE(7'b0001111),                 // Z = 0; Y = C; X = A:B
      // Data: 30-bit (each) input: Data Ports
      .A(a[47:18]),                           // 30-bit input: A data input
      .B(a[17:0]),                           // 18-bit input: B data input
      .C(b),                           // 48-bit input: C data input
      .CARRYIN(cin),               // 1-bit input: Carry input signal
      .D({25{1'b1}}),                           // 25-bit input: D data input
      // Reset/Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
      .CEA1(1'b0),                     // 1-bit input: Clock enable input for 1st stage AREG
      .CEA2(1'b0),                     // 1-bit input: Clock enable input for 2nd stage AREG
      .CEAD(1'b0),                     // 1-bit input: Clock enable input for ADREG
      .CEALUMODE(1'b0),           // 1-bit input: Clock enable input for ALUMODE
      .CEB1(1'b0),                     // 1-bit input: Clock enable input for 1st stage BREG
      .CEB2(1'b0),                     // 1-bit input: Clock enable input for 2nd stage BREG
      .CEC(1'b0),                       // 1-bit input: Clock enable input for CREG
      .CECARRYIN(1'b0),           // 1-bit input: Clock enable input for CARRYINREG
      .CECTRL(1'b0),                 // 1-bit input: Clock enable input for OPMODEREG and CARRYINSELREG
      .CED(1'b0),                       // 1-bit input: Clock enable input for DREG
      .CEINMODE(1'b0),             // 1-bit input: Clock enable input for INMODEREG
      .CEM(1'b0),                       // 1-bit input: Clock enable input for MREG
      .CEP(1'b0),                       // 1-bit input: Clock enable input for PREG
      .RSTA(1'b0),                     // 1-bit input: Reset input for AREG
      .RSTALLCARRYIN(1'b0),   // 1-bit input: Reset input for CARRYINREG
      .RSTALUMODE(1'b0),         // 1-bit input: Reset input for ALUMODEREG
      .RSTB(1'b0),                     // 1-bit input: Reset input for BREG
      .RSTC(1'b0),                     // 1-bit input: Reset input for CREG
      .RSTCTRL(1'b0),               // 1-bit input: Reset input for OPMODEREG and CARRYINSELREG
      .RSTD(1'b0),                     // 1-bit input: Reset input for DREG and ADREG
      .RSTINMODE(1'b0),           // 1-bit input: Reset input for INMODEREG
      .RSTM(1'b0),                     // 1-bit input: Reset input for MREG
      .RSTP(1'b0)                      // 1-bit input: Reset input for PREG
   );
   
   always @(posedge clk) begin
    cin <= rst ? 1'b0 : carry_out[3];
   end
   
   
    
endmodule

module adder_seq(clk, rst, a, b, sumout, done);

    parameter width48 = 43;
    localparam bits = width48 * 48;
    input clk;
    input rst;
    input[bits-1:0] a;
    input[bits-1:0] b;
    output reg [bits-1:0] sumout = 0;
    output done;
    
    reg[15:0] cycles = width48;
    
    wire[47:0] result;
    
    adder48_seq adder(.clk(clk), .rst(rst), .a(a[cycles*48+:48]), .b(b[cycles*48+:48]), .result(result));
    
    
    always @(posedge clk) begin
        if (rst) begin
            cycles <= 0;
        end
        else if (cycles < width48) begin
            sumout[cycles*48+:48] <= result;
            cycles <= cycles + 1;
        end
    end
    
    assign done = cycles == width48;
    
    
endmodule

