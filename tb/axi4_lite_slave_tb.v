`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.07.2026 10:39:45
// Design Name: 
// Module Name: axi4_lite_slave_tb
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
// axi4_lite_slave_tb.v
// Directed testbench for axi4_lite_slave_ram
// Tests: single write, single read, read-back verify
// ============================================================

module axi4_lite_slave_tb;

  // ----------------------------------------------------------------
  // Parameters
  // ----------------------------------------------------------------
  parameter ADDR_WIDTH = 4;
  parameter DATA_WIDTH = 32;
  parameter DEPTH      = 16;
  parameter CLK_PERIOD = 10; // 100 MHz

  // ----------------------------------------------------------------
  // DUT signals
  // ----------------------------------------------------------------
  reg                    aclk;
  reg                    areset_n;

  // Write Address
  reg  [ADDR_WIDTH-1:0]  s_axi_awaddr;
  reg                    s_axi_awvalid;
  wire                   s_axi_awready;

  // Write Data
  reg  [DATA_WIDTH-1:0]  s_axi_wdata;
  reg                    s_axi_wvalid;
  wire                   s_axi_wready;

  // Write Response
  wire [1:0]             s_axi_bresp;
  wire                   s_axi_bvalid;
  reg                    s_axi_bready;

  // Read Address
  reg  [ADDR_WIDTH-1:0]  s_axi_araddr;
  reg                    s_axi_arvalid;
  wire                   s_axi_arready;

  // Read Data
  wire [DATA_WIDTH-1:0]  s_axi_rdata;
  wire [1:0]             s_axi_rresp;
  wire                   s_axi_rvalid;
  reg                    s_axi_rready;

  // ----------------------------------------------------------------
  // DUT instantiation
  // ----------------------------------------------------------------
  axi4_lite_slave_ram #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .DEPTH      (DEPTH)
  ) dut (
    .aclk          (aclk),
    .areset_n      (areset_n),
    .s_axi_awaddr  (s_axi_awaddr),
    .s_axi_awvalid (s_axi_awvalid),
    .s_axi_awready (s_axi_awready),
    .s_axi_wdata   (s_axi_wdata),
    .s_axi_wvalid  (s_axi_wvalid),
    .s_axi_wready  (s_axi_wready),
    .s_axi_bresp   (s_axi_bresp),
    .s_axi_bvalid  (s_axi_bvalid),
    .s_axi_bready  (s_axi_bready),
    .s_axi_araddr  (s_axi_araddr),
    .s_axi_arvalid (s_axi_arvalid),
    .s_axi_arready (s_axi_arready),
    .s_axi_rdata   (s_axi_rdata),
    .s_axi_rresp   (s_axi_rresp),
    .s_axi_rvalid  (s_axi_rvalid),
    .s_axi_rready  (s_axi_rready)
  );

  // ----------------------------------------------------------------
  // Clock generation
  // ----------------------------------------------------------------
  initial aclk = 0;
  always #(CLK_PERIOD/2) aclk = ~aclk;

  // ----------------------------------------------------------------
  // Task: AXI4-Lite Write
  // Drives AW and W channels independently (AXI allows this)
  // ----------------------------------------------------------------
  task axi_write;
    input [ADDR_WIDTH-1:0] addr;
    input [DATA_WIDTH-1:0] data;
    begin
      // --- Write Address Channel ---
      @(posedge aclk);
      s_axi_awaddr  <= addr;
      s_axi_awvalid <= 1'b1;

      // Wait for awready
      @(posedge aclk);
      while (!s_axi_awready) @(posedge aclk);
      // Handshake done
      s_axi_awvalid <= 1'b0;

      // --- Write Data Channel ---
      s_axi_wdata  <= data;
      s_axi_wvalid <= 1'b1;

      // Wait for wready
      @(posedge aclk);
      while (!s_axi_wready) @(posedge aclk);
      s_axi_wvalid <= 1'b0;

      // --- Write Response Channel ---
      s_axi_bready <= 1'b1;
      @(posedge aclk);
      while (!s_axi_bvalid) @(posedge aclk);
      // Response accepted
      s_axi_bready <= 1'b0;

      @(posedge aclk);
      $display("[WRITE] addr=0x%0h data=0x%0h bresp=%0b", addr, data, s_axi_bresp);
    end
  endtask

  // ----------------------------------------------------------------
  // Task: AXI4-Lite Read
  // ----------------------------------------------------------------
  task axi_read;
    input  [ADDR_WIDTH-1:0] addr;
    output [DATA_WIDTH-1:0] rdata_out;
    begin
      // --- Read Address Channel ---
      @(posedge aclk);
      s_axi_araddr  <= addr;
      s_axi_arvalid <= 1'b1;

      // Wait for arready
      @(posedge aclk);
      while (!s_axi_arready) @(posedge aclk);
      s_axi_arvalid <= 1'b0;

      // --- Read Data Channel ---
      s_axi_rready <= 1'b1;
      @(posedge aclk);
      while (!s_axi_rvalid) @(posedge aclk);
      rdata_out    = s_axi_rdata;   // capture
      s_axi_rready <= 1'b0;

      @(posedge aclk);
      $display("[READ]  addr=0x%0h rdata=0x%0h rresp=%0b", addr, rdata_out, s_axi_rresp);
    end
  endtask

  // ----------------------------------------------------------------
  // Test sequence
  // ----------------------------------------------------------------
  reg [DATA_WIDTH-1:0] read_data;
  integer pass_count, fail_count;

  initial begin
    // Init
    areset_n      = 0;
    s_axi_awaddr  = 0; s_axi_awvalid = 0;
    s_axi_wdata   = 0; s_axi_wvalid  = 0;
    s_axi_bready  = 0;
    s_axi_araddr  = 0; s_axi_arvalid = 0;
    s_axi_rready  = 0;
    pass_count    = 0;
    fail_count    = 0;

    // Reset for 5 cycles
    repeat(5) @(posedge aclk);
    areset_n = 1;
    repeat(2) @(posedge aclk);

    $display("=== AXI4-Lite Slave RAM Testbench ===");

    // ---- Test 1: Write to address 0, read back ----
    axi_write(4'h0, 32'hDEAD_BEEF);
    axi_read (4'h0, read_data);
    if (read_data === 32'hDEAD_BEEF) begin
      $display("PASS: Test 1 — addr 0x0 data match 0x%0h", read_data);
      pass_count = pass_count + 1;
    end else begin
      $display("FAIL: Test 1 — expected 0xDEADBEEF got 0x%0h", read_data);
      fail_count = fail_count + 1;
    end

    // ---- Test 2: Write to address 4, read back ----
    axi_write(4'h4, 32'hCAFE_1234);
    axi_read (4'h4, read_data);
    if (read_data === 32'hCAFE_1234) begin
      $display("PASS: Test 2 — addr 0x4 data match 0x%0h", read_data);
      pass_count = pass_count + 1;
    end else begin
      $display("FAIL: Test 2 — expected 0xCAFE1234 got 0x%0h", read_data);
      fail_count = fail_count + 1;
    end

    // ---- Test 3: Overwrite address 0, verify update ----
    axi_write(4'h0, 32'h1111_2222);
    axi_read (4'h0, read_data);
    if (read_data === 32'h1111_2222) begin
      $display("PASS: Test 3 — overwrite addr 0x0 match 0x%0h", read_data);
      pass_count = pass_count + 1;
    end else begin
      $display("FAIL: Test 3 — expected 0x11112222 got 0x%0h", read_data);
      fail_count = fail_count + 1;
    end

    // ---- Test 4: addr 4 unchanged after overwrite of addr 0 ----
    axi_read (4'h4, read_data);
    if (read_data === 32'hCAFE_1234) begin
      $display("PASS: Test 4 — addr 0x4 unchanged 0x%0h", read_data);
      pass_count = pass_count + 1;
    end else begin
      $display("FAIL: Test 4 — expected 0xCAFE1234 got 0x%0h", read_data);
      fail_count = fail_count + 1;
    end

    $display("=====================================");
    $display("Results: %0d PASSED, %0d FAILED", pass_count, fail_count);
    $display("=====================================");

    repeat(5) @(posedge aclk);
    $finish;
  end

  // ----------------------------------------------------------------
  // Timeout watchdog — kills sim if it hangs
  // ----------------------------------------------------------------
  initial begin
    #50000;
    $display("TIMEOUT: simulation hung — check handshake logic");
    $finish;
  end

  // ----------------------------------------------------------------
  // Waveform dump
  // ----------------------------------------------------------------
  initial begin
    $dumpfile("axi4_lite_slave.vcd");
    $dumpvars(0, axi4_lite_slave_tb);
  end

endmodule
