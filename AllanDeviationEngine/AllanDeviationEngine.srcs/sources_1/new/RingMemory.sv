`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: University of Houston - Clear Lake
// Engineer: Alexander P. Opekun
// 
// Create Date: 06/08/2026 04:31:12 PM
// Design Name: Streaming Allan Deviation Engine 
// Module Name: RingMemory
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: A collection of 3 modules RingMemorySystem, RingMemory, RotateRing
// this returns the most recent data at the top of the RotData output
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module RingMemorySystem
    #(parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 6,
    localparam int MEMORY_REGS = 2**ADDR_WIDTH)
    (
    input  logic                         clk, //Clock
    input  logic                         rst, // reset Active High
    input  logic                          we, // Write Enable
    input  logic [(DATA_WIDTH-1):0]  SeqData, //Feeding 1 number at a time
    output logic [DATA_WIDTH-1:0]    ParData [0:MEMORY_REGS-1],
    output logic                    ParValid [0:MEMORY_REGS-1]
    );
    
    logic [ADDR_WIDTH-1:0] wr_ptr;  // Write pointer for ring buffer
    logic [DATA_WIDTH-1:0]    RAM [0:MEMORY_REGS-1]; // Returning All memory regs in parallel
    logic                   VALID [0:MEMORY_REGS-1];
    /// Instance 1 : Ring Buffer Memory
    RingMemory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    )u_ring(
        .clk(clk),
        .rst(rst),
        .we(we),
        .SeqData(SeqData),
        .RAM(RAM),
        .VALID(VALID),
        .wr_ptr(wr_ptr)
    );
    RotateRing #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    )
    u_rotate(
        .clk(clk),
        .rst(rst),
        .RAM(RAM),
        .VALID(VALID),
        .wr_ptr(wr_ptr),
        .ParData(ParData),
        .ParValid(ParValid)
    ); 
endmodule

module RingMemory
#(parameter DATA_WIDTH = 16,
parameter ADDR_WIDTH = 6,
localparam int MEMORY_REGS = 2**ADDR_WIDTH)
(
    input logic clk, //Clock
    input logic rst, // reset Active High
    input logic we, // Write Enable
    input logic [(DATA_WIDTH-1):0] SeqData, //Feeding 1 number at a time
    output logic [(DATA_WIDTH-1):0] RAM [0:MEMORY_REGS-1], 
    output logic VALID [0:MEMORY_REGS-1],
    output logic [ADDR_WIDTH-1:0] wr_ptr  //Write pointer for ring buffer
    );
    always_ff @(posedge clk)begin
        if(rst)begin
            wr_ptr <= '0;
            for (int i = 0; i < MEMORY_REGS; i++) begin //CLEAR RAM
                RAM[i] <= '0;
                VALID[i] <= '0;
            end
        end else begin
            if (we) begin 
                RAM[wr_ptr] <= SeqData;//write incoming data
            end
            VALID[wr_ptr] <=  we;
            wr_ptr <= wr_ptr + 1'b1;//increment with wrap around
        end
    end
endmodule

module RotateRing
    #(parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 6,
    localparam int MEMORY_REGS = 2**ADDR_WIDTH)
    (
    input logic clk, //Clock             
    input logic rst, // reset Active High
    input logic [(DATA_WIDTH-1):0] RAM [0:MEMORY_REGS-1], 
    input logic VALID [0:MEMORY_REGS-1],
    input logic [ADDR_WIDTH-1:0] wr_ptr,  // Write pointer for ring buffer
    
    output logic [DATA_WIDTH-1:0]    ParData [0:MEMORY_REGS-1], // send most recent at the top
    output logic ParValid [0:MEMORY_REGS-1]
    );
    
    logic [DATA_WIDTH-1:0] RotData  [0:MEMORY_REGS-1]; // send most recent at the top
    logic                  RotValid [0:MEMORY_REGS-1];
    //Rotated output
    generate
        for (genvar i = 0; i < MEMORY_REGS; i++) begin : ROTATE
            // Compute (wr_ptr - 1 - i) modulo MEMORY_REGS
            logic [ADDR_WIDTH-1:0] src;

            always_comb begin
                src = wr_ptr - (i + 1);
            end
            
            assign ParData[i]  = RAM[src];
            assign ParValid[i] = VALID[src];
        end
    endgenerate
    
    always_ff @(posedge clk)begin
        if(rst)begin
            for (int i = 0; i < MEMORY_REGS; i++) begin //CLEAR RAM
                ParData[i] <= '0;
                ParValid[i] <= '0;
            end
        end else begin
            for (int i = 0; i < MEMORY_REGS; i++) begin //CLEAR RAM
                ParData[i]  <= RotData[i];
                ParValid[i] <= RotValid[i];
            end
        end
    end
    
endmodule