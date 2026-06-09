`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/09/2026 09:33:31 AM
// Design Name: 
// Module Name: TB_RingMemorySystem
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


module TB_RingMemorySystem();
    //parameters
    localparam DATA_WIDTH = 16;
    localparam ADDR_WIDTH = 6;
    localparam int MEMORY_REGS = 2**ADDR_WIDTH;
    
    //DUT inputs
    logic clk; //Clock
    logic rst; // reset Active High
    logic  we; // Write Enable
    logic [(DATA_WIDTH-1):0] SeqData; //Feeding 1 number at a time
    //DUT outputs
    logic [DATA_WIDTH-1:0]    ParData [0:MEMORY_REGS-1];
    logic                    ParValid [0:MEMORY_REGS-1];

    //instantiate Dut
    RingMemorySystem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    )u_ringMemSys(
        .clk(clk),
        .rst(rst),
        .we(we),
        . SeqData( SeqData),
        . ParData( ParData),
        .ParValid(ParValid)
    );
    //clock gen: 100 MHz
    initial clk = 0;
    always #5 clk = ~clk;
    
    //Stimulus
    initial begin
        // Initialize
        rst = 1;
        we = 0;
        SeqData = 0;
        //hold reset for a few cycles
        repeat(5) @(posedge clk);
        // feed 100 samples
        for(int i = 0; i < 100; i++) begin
            @(posedge clk);
            we = 1;
            rst = 0;
            SeqData = i;
        end
        // feed 100 samples
        for(int i = 0; i < 100; i++) begin
            @(posedge clk);
            we = 0;
            rst = 0;
            SeqData = i;
        end
        $display("Simulation Complete");
        $finish;
    end
endmodule
