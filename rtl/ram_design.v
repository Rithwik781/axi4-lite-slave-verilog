`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.07.2026 10:36:11
// Design Name: 
// Module Name: ram_design
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

// ============================================================
// ram_design.v
// Simple single-port RAM with ASYNC read
// Async read means zero latency — data valid same cycle as address
// ============================================================

module ram_design #(
  parameter ADDR_WIDTH = 4,
  parameter DATA_WIDTH = 32,
  parameter DEPTH      = 16
)(
  input                      clk,
  input                      rst_n,
  input                      write_enb,
  input  [ADDR_WIDTH-1:0]    addr,
  input  [DATA_WIDTH-1:0]    wdata,
  output [DATA_WIDTH-1:0]    rdata    // wire — async read, no latency
);

  reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

  integer i;

  // Async read — combinational, always reflects current address
  assign rdata = mem[addr];

  // Sync write with reset
  always @(posedge clk) begin
    if (!rst_n) begin
      for (i = 0; i < DEPTH; i = i + 1)
        mem[i] <= {DATA_WIDTH{1'b0}};
    end
    else if (write_enb) begin
      mem[addr] <= wdata;
    end
  end

endmodule

