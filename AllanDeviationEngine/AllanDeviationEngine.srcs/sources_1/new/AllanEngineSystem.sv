`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: University of Houston - Clear Lake
// Engineer: Alexander P. Opekun
// 
// Create Date: 06/11/2026 03:00:03 PM
// Design Name: Streaming Allan Deviation Engine 
// Module Name: Allan Deviation Engine
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: a collection of modules that are paramterized to tune the allan engine to desired specificaitons 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Differencer
    #(parameter DATA_WIDTH = 16,
      parameter MEMORY_REGS = 64,
      parameter offset = 1,
      localparam int  ADDR_WIDTH = ceil(log(ADDR_WIDTH)/log(2))
    )
    (
    input clk,
    input rst,
    input logic [DATA_WIDTH-1:0]  inData [0:MEMORY_REGS-1],
    input logic                  inValid [0:MEMORY_REGS-1],
    output logic [DATA_WIDTH-1:0]  outData [0:MEMORY_REGS-1-offset],
    output logic                  outValid [0:MEMORY_REGS-1-offset]
    );
    generate
        for (genvar src_A = 0; src_A < MEMORY_REGS-offset; src_A++) begin : Difference
            // Compute
            logic [ADDR_WIDTH-1:0] src_B;
            always_comb begin
                src_B = src_A + offset;
            end
            always_ff @(posedge clk)begin
                if(rst)begin
                    outData[src_A] <= '0;
                    outValid[src_A]  <= '0;
                end
                else begin
                    outData[src_A]  <=  inData[src_A] -  inData[src_B];
                    outValid[src_A]  <= inValid[src_A] & inValid[src_B];
                end
            end
        end
    endgenerate
endmodule
module squarer
    #(parameter DATA_WIDTH = 16,
      parameter MEMORY_REGS = 64
    )
    (
    input clk,
    input rst,
    input logic [DATA_WIDTH-1:0]  inData [0:MEMORY_REGS-1],
    input logic                  inValid [0:MEMORY_REGS-1],
    output logic [2*DATA_WIDTH-1:0]  outData [0:MEMORY_REGS-1],
    output logic                  outValid [0:MEMORY_REGS-1]
    );
    generate
        for (genvar src = 0; src < MEMORY_REGS; src++) begin : square
            // Compute
            always_ff @(posedge clk)begin
                if(rst)begin
                    outData[src] <= '0;
                    outValid[src]  <= '0;
                end else begin
                    outData[src]  <=  inData[src] *  inData[src];
                    outValid[src]  <= inValid[src];
                end
            end
            
        end
    endgenerate
endmodule

module accumulator
// NOTE: Generates but WILL NOT WORK as intended
// THIS WILL CREATE DATA CLASHES AND UNDEFINED VALUES AS WRITTEN.
// indended goal is sum all of in data to 1 number. may need more outputbits
    #(parameter DATA_WIDTH = 16,
      parameter MEMORY_REGS = 64
    )
    (
    input clk,
    input rst,
    input logic [DATA_WIDTH-1:0]  inData [0:MEMORY_REGS-1],
    input logic                  inValid [0:MEMORY_REGS-1],
    output logic [DATA_WIDTH-1:0]  outData,
    output logic [DATA_WIDTH-1:0] outValid
    );
    generate
        for (genvar src = 0; src < MEMORY_REGS; src++) begin : square
            // Compute
            always_ff @(posedge clk)begin
                if(rst)begin
                    outData <= '0;
                    outValid <= '0;
                end else begin
                    outData  <=  inData[src] + outData;
                    outValid <= inValid[src] + outValid;
                end
            end
            
        end
    endgenerate
endmodule
// Differencer 
// difference of taus
// squarer
// accumulator
// divider
// rooter