`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/25/2022 12:34:58 AM
// Design Name: 
// Module Name: crc32
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


module crc32(
    input [3:0] data,
    output [31:0] fcsOut,
    input crc_enable,
    input clk
);
    
    logic[31:0] crcIn;
    logic[31:0] crcOut;
    
    assign crcOut[0] = crcIn[4];
    assign crcOut[1] = crcIn[5];
    assign crcOut[2] = (crcIn[0] ^ crcIn[6] ^ data[0]);
    assign crcOut[3] = (crcIn[1] ^ crcIn[7] ^ data[1]);
    assign crcOut[4] = (crcIn[2] ^ crcIn[8] ^ data[2]);
    assign crcOut[5] = (crcIn[0] ^ crcIn[3] ^ crcIn[9] ^ data[0] ^ data[3]);
    assign crcOut[6] = (crcIn[0] ^ crcIn[1] ^ crcIn[10] ^ data[0] ^ data[1]);
    assign crcOut[7] = (crcIn[1] ^ crcIn[2] ^ crcIn[11] ^ data[1] ^ data[2]);
    assign crcOut[8] = (crcIn[2] ^ crcIn[3] ^ crcIn[12] ^ data[2] ^ data[3]);
    assign crcOut[9] = (crcIn[3] ^ crcIn[13] ^ data[3]);
    assign crcOut[10] = crcIn[14];
    assign crcOut[11] = crcIn[15];
    assign crcOut[12] = (crcIn[0] ^ crcIn[16] ^ data[0]);
    assign crcOut[13] = (crcIn[1] ^ crcIn[17] ^ data[1]);
    assign crcOut[14] = (crcIn[2] ^ crcIn[18] ^ data[2]);
    assign crcOut[15] = (crcIn[3] ^ crcIn[19] ^ data[3]);
    assign crcOut[16] = (crcIn[0] ^ crcIn[20] ^ data[0]);
    assign crcOut[17] = (crcIn[0] ^ crcIn[1] ^ crcIn[21] ^ data[0] ^ data[1]);
    assign crcOut[18] = (crcIn[0] ^ crcIn[1] ^ crcIn[2] ^ crcIn[22] ^ data[0] ^ data[1] ^ data[2]);
    assign crcOut[19] = (crcIn[1] ^ crcIn[2] ^ crcIn[3] ^ crcIn[23] ^ data[1] ^ data[2] ^ data[3]);
    assign crcOut[20] = (crcIn[0] ^ crcIn[2] ^ crcIn[3] ^ crcIn[24] ^ data[0] ^ data[2] ^ data[3]);
    assign crcOut[21] = (crcIn[0] ^ crcIn[1] ^ crcIn[3] ^ crcIn[25] ^ data[0] ^ data[1] ^ data[3]);
    assign crcOut[22] = (crcIn[1] ^ crcIn[2] ^ crcIn[26] ^ data[1] ^ data[2]);
    assign crcOut[23] = (crcIn[0] ^ crcIn[2] ^ crcIn[3] ^ crcIn[27] ^ data[0] ^ data[2] ^ data[3]);
    assign crcOut[24] = (crcIn[0] ^ crcIn[1] ^ crcIn[3] ^ crcIn[28] ^ data[0] ^ data[1] ^ data[3]);
    assign crcOut[25] = (crcIn[1] ^ crcIn[2] ^ crcIn[29] ^ data[1] ^ data[2]);
    assign crcOut[26] = (crcIn[0] ^ crcIn[2] ^ crcIn[3] ^ crcIn[30] ^ data[0] ^ data[2] ^ data[3]);
    assign crcOut[27] = (crcIn[0] ^ crcIn[1] ^ crcIn[3] ^ crcIn[31] ^ data[0] ^ data[1] ^ data[3]);
    assign crcOut[28] = (crcIn[0] ^ crcIn[1] ^ crcIn[2] ^ data[0] ^ data[1] ^ data[2]);
    assign crcOut[29] = (crcIn[1] ^ crcIn[2] ^ crcIn[3] ^ data[1] ^ data[2] ^ data[3]);
    assign crcOut[30] = (crcIn[2] ^ crcIn[3] ^ data[2] ^ data[3]);
    assign crcOut[31] = (crcIn[3] ^ data[3]);
    
    assign fcsOut = ~crcOut;
    always_ff @(posedge clk) begin
        crcIn <= crc_enable ? crcOut : 32'hffffffff;
    end
endmodule