# axi4-lite-slave-verilog

# AXI4-Lite Slave — Verilog RTL

A complete AXI4-Lite slave implementation in Verilog with internal RAM, verified with a directed testbench in Vivado. **4/4 tests passing, 0 failures.**

---

## What's Implemented

|                Feature                 |  Status |
|----------------------------------------|---------|
| AW channel — write address handshake   |   ✅   |
| W channel — write data handshake       |   ✅   |
| B channel — write response             |   ✅   |
| AR channel — read address handshake    |   ✅   |
| R channel — read data response         |   ✅   |
| Internal RAM with async read           |   ✅   |
| Independent write and read FSMs        |   ✅   |
| Directed testbench — 4/4 tests passing |   ✅   |

---

## Test Results

| Test |                   Operation                   |  Expected  | Result  |
|------|-----------------------------------------------|------------|---------|
|  T1  | Write 0xDEADBEEF → addr 0x0, read back        | 0xDEADBEEF | ✅ PASS |
|  T2  | Write 0xCAFE1234 → addr 0x4, read back        | 0xCAFE1234 | ✅ PASS |
|  T3  | Overwrite addr 0x0 with 0x11112222, read back | 0x11112222 | ✅ PASS |
|  T4  | Verify addr 0x4 still holds 0xCAFE1234        | 0xCAFE1234 | ✅ PASS |

---

## Block Diagram

```
     Master (Testbench)
           |
   ┌───────┴────────┐
   │  AXI4-Lite     │
   │  Slave         │
   │                │
   │  ┌──────────┐  │
   │  │ Write    │──┼──► RAM (mem[])
   │  │ FSM      │  │
   │  └──────────┘  │
   │                │
   │  ┌──────────┐  │
   │  │ Read     │◄─┼─── RAM (mem[])
   │  │ FSM      │  │
   │  └──────────┘  │
   └────────────────┘
```

---

## FSM Architecture

### Write Path
```
WR_IDLE ──(awvalid && awready)──► WR_DATA ──(wvalid && wready)──► WR_RESP ──(bvalid && bready)──► WR_IDLE
```
- WR_IDLE — assert awready, wait for master to send write address
- WR_DATA — assert wready, wait for master to send write data, write to RAM
- WR_RESP — assert bvalid, wait for master to accept response

### Read Path
```
RD_IDLE ──(arvalid && arready)──► RD_RESP ──(rvalid && rready)──► RD_IDLE
```
- RD_IDLE — assert arready, wait for master to send read address
- RD_RESP — assert rvalid, drive rdata from RAM, wait for master to accept

> No RD_DATA wait state needed — async RAM returns data combinatorially in the same cycle.

---

## Key Design Decisions

### 1. Async RAM read
```verilog
// Synchronous read — 1 cycle latency, needs extra wait state
always @(posedge clk) rdata <= mem[addr];

// Async read — zero latency, data valid same cycle as address
assign rdata = mem[addr];
```
Using async read eliminates the need for a `RD_DATA` wait state, simplifying the read FSM from 3 states to 2.

### 2. rvalid control in single always block
If rvalid set and clear are in **separate** always blocks, both fire at the same posedge. The set always wins — rvalid gets permanently stuck high. Keeping both in **one block** uses Verilog's last-NBA-wins scheduling rule:

```verilog
RD_RESP : begin
  s_axi_rvalid <= 1'b1;              // NBA 1: assert rvalid
  s_axi_rdata  <= ram_rdata;
  if (s_axi_rvalid && s_axi_rready)
    s_axi_rvalid <= 1'b0;            // NBA 2: wins when handshake fires
    read_state   <= RD_IDLE;
end
```

### 3. Default de-assertions
```verilog
// At top of every always block
s_axi_awready <= 1'b0;
s_axi_wready  <= 1'b0;
ram_we        <= 1'b0;
```
Every registered output defaults to 0 each cycle. Only the active FSM state overrides to 1. Prevents accidental latching of stale values.

---

## AXI4 Handshake Rule
> **VALID must never be de-asserted before READY.**

Once a master asserts AWVALID, it must hold it high until AWREADY comes. This applies to all 5 channels. Violating this rule causes silent protocol deadlocks that are extremely hard to debug in simulation.

---

## File Structure

```
axi4-lite-slave-verilog/
├── rtl/
│   ├── axi4_lite_slave_ram.v   ← AXI4-Lite slave top module
│   └── ram_design.v            ← Internal RAM with async read
├── tb/
│   └── axi4_lite_slave_tb.v    ← Directed Verilog testbench
├── sim/
│   └── screenshots/            ← Vivado simulation waveforms
└── README.md
```

---

## How to Simulate

**Vivado:**
1. Create new project → add all `.v` files from `rtl/` and `tb/`
2. Set `axi4_lite_slave_tb` as top module
3. Run Behavioral Simulation

**Icarus Verilog:**
```bash
iverilog -o sim rtl/ram_design.v rtl/axi4_lite_slave_ram.v tb/axi4_lite_slave_tb.v
vvp sim
```

Expected output:
```
=== AXI4-Lite Slave RAM Testbench ===
[WRITE] addr=0x0 data=0xdeadbeef bresp=0
[READ]  addr=0x0 rdata=0xdeadbeef
PASS T1
[WRITE] addr=0x4 data=0xcafe1234 bresp=0
[READ]  addr=0x4 rdata=0xcafe1234
PASS T2
[WRITE] addr=0x0 data=0x11112222 bresp=0
[READ]  addr=0x0 rdata=0x11112222
PASS T3
[READ]  addr=0x4 rdata=0xcafe1234
PASS T4
=====================================
Results: 4 PASSED  0 FAILED
=====================================
```

---

## Tools Used

- Xilinx Vivado 2023.x — simulation and waveform analysis
- Icarus Verilog — local verification

---

## Author

Rithwik kusuma
Final Year B.Tech — Electrical and Electronics Engineering  
NIT Warangal  

