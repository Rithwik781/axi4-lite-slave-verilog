`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.07.2026 10:37:37
// Design Name: 
// Module Name: axi4_lite_slave_ram
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


// AXI4-Lite Slave with internal RAM

// ============================================================
// axi4_lite_slave_ram.v
// AXI4-Lite Slave — instantiates ram_design internally
// Bug fix: rvalid control inside FSM block (no two-block race)
// ============================================================

module axi4_lite_slave_ram #(
  parameter ADDR_WIDTH = 4,
  parameter DATA_WIDTH = 32,
  parameter DEPTH      = 16
)(
  input                       aclk,
  input                       areset_n,

  // Write Address Channel
  input  [ADDR_WIDTH-1:0]     s_axi_awaddr,
  input                       s_axi_awvalid,
  output reg                  s_axi_awready,

  // Write Data Channel
  input  [DATA_WIDTH-1:0]     s_axi_wdata,
  input                       s_axi_wvalid,
  output reg                  s_axi_wready,

  // Write Response Channel
  output reg [1:0]            s_axi_bresp,
  output reg                  s_axi_bvalid,
  input                       s_axi_bready,

  // Read Address Channel
  input  [ADDR_WIDTH-1:0]     s_axi_araddr,
  input                       s_axi_arvalid,
  output reg                  s_axi_arready,

  // Read Data Channel
  output reg [DATA_WIDTH-1:0] s_axi_rdata,
  output reg [1:0]            s_axi_rresp,
  output reg                  s_axi_rvalid,
  input                       s_axi_rready
);

  // ----------------------------------------------------------------
  // Response codes
  // ----------------------------------------------------------------
  localparam RESP_OKAY = 2'b00;

  // ----------------------------------------------------------------
  // Write FSM states
  // ----------------------------------------------------------------
  localparam WR_IDLE = 2'b00;
  localparam WR_DATA = 2'b01;
  localparam WR_RESP = 2'b10;

  // ----------------------------------------------------------------
  // Read FSM states
  // ----------------------------------------------------------------
  localparam RD_IDLE = 2'b00;
  localparam RD_RESP = 2'b01;  // no RD_DATA needed — async RAM

  // ----------------------------------------------------------------
  // FSM state registers
  // ----------------------------------------------------------------
  reg [1:0] write_state;
  reg [1:0] read_state;

  // ----------------------------------------------------------------
  // Address latch registers
  // ----------------------------------------------------------------
  reg [ADDR_WIDTH-1:0] write_addr_reg;
  reg [ADDR_WIDTH-1:0] read_addr_reg;

  // ----------------------------------------------------------------
  // RAM interface signals
  // ----------------------------------------------------------------
  reg                    ram_we;
  reg  [ADDR_WIDTH-1:0]  ram_addr;
  reg  [DATA_WIDTH-1:0]  ram_wdata;
  wire [DATA_WIDTH-1:0]  ram_rdata;  // wire because RAM read is async

  // ----------------------------------------------------------------
  // RAM instantiation — named port connections
  // ----------------------------------------------------------------
  ram_design #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .DEPTH      (DEPTH)
  ) u_ram (
    .clk       (aclk),
    .rst_n     (areset_n),
    .write_enb (ram_we),
    .addr      (ram_addr),
    .wdata     (ram_wdata),
    .rdata     (ram_rdata)
  );

  // ================================================================
  // WRITE FSM
  // Controls: awready, wready, bvalid, bresp, ram_we, ram_addr, ram_wdata
  // All write-related signals in ONE block — no inter-block race
  // ================================================================
  always @(posedge aclk) begin
    if (!areset_n) begin
      write_state    <= WR_IDLE;
      s_axi_awready  <= 1'b0;
      s_axi_wready   <= 1'b0;
      s_axi_bvalid   <= 1'b0;
      s_axi_bresp    <= RESP_OKAY;
      write_addr_reg <= {ADDR_WIDTH{1'b0}};
      ram_we         <= 1'b0;
      ram_addr       <= {ADDR_WIDTH{1'b0}};
      ram_wdata      <= {DATA_WIDTH{1'b0}};
    end
    else begin
      // Default de-assertions every cycle
      s_axi_awready <= 1'b0;
      s_axi_wready  <= 1'b0;
      ram_we        <= 1'b0;

      case (write_state)

        // --------------------------------------------------------
        // WR_IDLE: assert awready, wait for master write address
        // --------------------------------------------------------
        WR_IDLE : begin
          s_axi_awready <= 1'b1;
          if (s_axi_awvalid && s_axi_awready) begin
            write_addr_reg <= s_axi_awaddr;
            s_axi_awready  <= 1'b0;   // last NBA wins — de-asserts
            write_state    <= WR_DATA;
          end
        end

        // --------------------------------------------------------
        // WR_DATA: assert wready, wait for master write data
        // --------------------------------------------------------
        WR_DATA : begin
          s_axi_wready <= 1'b1;
          if (s_axi_wvalid && s_axi_wready) begin
            ram_we       <= 1'b1;
            ram_addr     <= write_addr_reg;
            ram_wdata    <= s_axi_wdata;
            s_axi_wready <= 1'b0;    // last NBA wins — de-asserts
            write_state  <= WR_RESP;
          end
        end

        // --------------------------------------------------------
        // WR_RESP: assert bvalid, wait for master to accept
        // bvalid and its clear are in the SAME block
        // last NBA wins: bvalid<=0 overrides bvalid<=1 when bready fires
        // --------------------------------------------------------
        WR_RESP : begin
          s_axi_bvalid <= 1'b1;
          s_axi_bresp  <= RESP_OKAY;
          if (s_axi_bvalid && s_axi_bready) begin
            s_axi_bvalid <= 1'b0;    // last NBA wins — clears bvalid
            write_state  <= WR_IDLE;
          end
        end

        default : write_state <= WR_IDLE;

      endcase
    end
  end

  // ================================================================
  // READ FSM
  // Controls: arready, rvalid, rdata, rresp
  // All read-related signals in ONE block — fixes the rvalid stuck-high bug
  //
  // KEY LESSON: if rvalid set/clear are in SEPARATE always blocks,
  // both fire at same posedge and the set always wins (re-drives rvalid=1
  // before the FSM can clear it). Keeping them in ONE block uses
  // Verilog last-NBA-wins rule to correctly clear rvalid.
  // ================================================================
  always @(posedge aclk) begin
    if (!areset_n) begin
      read_state    <= RD_IDLE;
      s_axi_arready <= 1'b0;
      s_axi_rvalid  <= 1'b0;
      s_axi_rdata   <= {DATA_WIDTH{1'b0}};
      s_axi_rresp   <= RESP_OKAY;
      read_addr_reg <= {ADDR_WIDTH{1'b0}};
      ram_addr      <= {ADDR_WIDTH{1'b0}};
    end
    else begin
      s_axi_arready <= 1'b0;  // default de-assert

      case (read_state)

        // --------------------------------------------------------
        // RD_IDLE: assert arready, wait for master read address
        // --------------------------------------------------------
        RD_IDLE : begin
          s_axi_arready <= 1'b1;
          if (s_axi_arvalid && s_axi_arready) begin
            read_addr_reg <= s_axi_araddr;
            ram_addr      <= s_axi_araddr;  // drive RAM address
            s_axi_arready <= 1'b0;          // last NBA wins
            read_state    <= RD_RESP;       // async RAM — skip wait state
          end
        end

        // --------------------------------------------------------
        // RD_RESP: assert rvalid + drive rdata, wait for rready
        //
        // last NBA wins rule in action:
        //   rvalid <= 1  (line 1 — always asserted in this state)
        //   rvalid <= 0  (line 2 — only when rready fires, WINS over line 1)
        // --------------------------------------------------------
        RD_RESP : begin
          s_axi_rvalid <= 1'b1;
          s_axi_rdata  <= ram_rdata;   // async wire — always valid
          s_axi_rresp  <= RESP_OKAY;
          if (s_axi_rvalid && s_axi_rready) begin
            s_axi_rvalid <= 1'b0;      // last NBA wins — clears rvalid
            read_state   <= RD_IDLE;
          end
        end

        default : read_state <= RD_IDLE;

      endcase
    end
  end

endmodule
