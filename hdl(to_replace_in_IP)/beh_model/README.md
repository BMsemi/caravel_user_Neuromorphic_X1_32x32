
# Neuromorphic_X1 Behavioral Model (Wishbone)

**Version**: Simulation-only  
**Address used**: 0x3000_000C

---

## 1) What this is

This is a **non-synthesizable behavioral model** of a 32×32 1-bit array with a **Wishbone shim** in front. It is intended for simulation. It demonstrates how software can send **“commands”** over Wishbone to:

- Program a cell
- Request a read
- Return read data later

### Files in this project:

- **Neuromorphic_X1_wb**: The Wishbone shim. It exposes **ONE address** (0x3000_000C). Writes/reads at that address are forwarded to the core.
- **Neuromorphic_X1**: The behavioral **core** that holds:
  - The 32×32 array
  - An input FIFO (commands)
  - An output FIFO (read data)

**Important**: This model uses `@(posedge clk)` inside `always` blocks to create delay loops. This is **for simulation only** and is **not synthesizable**.

---

## 2) The One Wishbone Address (0x3000_000C)

The shim only has address `0x3000_000C`:

- **WB WRITE** to `0x3000_000C`: Your 32-bit word is treated as a command.
- **WB READ** from `0x3000_000C`: You pop one 32-bit word of read data.

### The shim checks:

`EN = (stb & cyc & (adr == 0x3000_000C) & (sel == 4’hF))`

### Signal Mapping (shim → core):

| Signal    | Description                         |
|-----------|-------------------------------------|
| CLKin     | `wb_clk_i`                          |
| RSTin     | `wb_rst_i`                          |
| DI        | `wbs_dat_i` (write data / command word)|
| W_RB      | `wbs_we_i` (1 = write command, 0 = read pop) |
| DO        | `wbs_dat_o` (read data back to Wishbone) |
| core_ack  | `wbs_ack_o` (acknowledge back to Wishbone) |

### ACK Behavior (Simple):

- **For a WRITE cycle** at `0x3000_000C`, `core_ack = 1` when the command is successfully pushed into the input FIFO.
- **For a READ cycle** at `0x3000_000C`, `core_ack = 1` when one word is popped from the output FIFO into `DO`.
- If the output FIFO is empty, **ACK stays LOW**. The master should keep **CYC/STB active** and wait for **ACK to go HIGH** (standard Wishbone wait).

---

## 3) Command Word Format (The 32-bit DI)

**Bits**:  
- `[31:30] MODE`
- `[29:25] ROW`
- `[24:20] COL`
- `[19:0] DATA/flags`

### Supported **MODE** values in this model:

- **2’b11** → PROGRAM (Write the bit at [ROW][COL])
- **2’b01** → READ (Queue a read of [ROW][COL])
- **2’b10** → FORMING (reserved in doc; **NOT implemented** in the minimal code)

#### PROGRAM (MODE=2’b11):

- **DATA[7:0] = 8’hFF** → write `1` into the cell
- **DATA[7:0] = 8’h00** → write `0` into the cell

#### READ (MODE=2’b01):

- The core will later push the bit at `[ROW][COL]` into the output FIFO.
- When software performs a WB READ at `0x3000_000C`, one value is popped and returned on `DO` with **ACK=1**.

---

## 4) What’s Inside the Core

- **32×32 1-bit array**: `array_mem[row][col]`
- **Input FIFO** (`ip_fifo`, depth 32): Where incoming commands are queued.
- **Output FIFO** (`op_fifo`, depth 32): Where completed read data waits.
- **Simple “engine”**:
  - Pops commands from the input FIFO.
  - For **PROGRAM**: Waits `WR_Dly` cycles, then sets the target bit.
  - For **READ**: Waits `RD_Dly` cycles, then pushes the bit into `op_fifo`.

All delays are done with `@(posedge CLKin)` loops to keep the simulation simple.

---

## 5) Handshake, Timing, and Delays

- **Writes**:  
  ACK is asserted when the command is accepted (pushed into `ip_fifo`). The actual PROGRAM work happens later in the engine.
  
- **Reads**:  
  A READ command (MODE=01) only queues a **request**; the data arrives later in `op_fifo` after `RD_Dly` cycles. When software performs a WB READ on `0x3000_000C`, **ACK will be HIGH** only if a word is available to pop from `op_fifo` that cycle.  
  If `op_fifo` is empty, the core holds **ACK LOW** and the master waits.

**Default Delays in the Code**:
- `WR_Dly = 200`  // PROGRAM latency (in `CLKin` cycles)
- `RD_Dly = 44`   // READ latency (in `CLKin` cycles)

---

## 6) Bring-up & Expectations

- **On reset**, both FIFOs are empty, but array will persist.
- **Before any PROGRAM**, a READ of a location will eventually return `0`.
- **After a PROGRAM**, the bit persists (non-volatile behavior in simulation).

### Quick Checklist:
1. Release reset.
2. PROGRAM a location with **MODE=11** (e.g., `row=1`, `col=1`, `DATA=0xFF`).
3. Queue a **READ** with **MODE=01** for the same location.
4. Do a WB **READ** at `0x3000_000C` and wait for **ACK=1**; `DO` should be `0x0000_0001`.
5. Repeat **READ/POP** to prove non-volatility.

---

## 7) Software View (Example)

Use one address: `0x3000_000C`

**PROGRAM cell (row=1, col=1) to ‘1’**:
```c
write32(0x3000_000C, {2’b11, 5’d1, 5’d1, 20’h0FF});
```

**Queue READ of the same cell**:
```c
write32(0x3000_000C, {2’b01, 5’d1, 5’d1, 20’h00000});
```

**Pop the read result (blocking read)**:
```c
data = read32(0x3000_000C);
// The master should hold CYC/STB until ACK=1, then sample data.
```

---

## 8) Common Pitfalls

- **Reading too early**: You must first queue a READ command (MODE=01). Then perform a WB READ and wait for ACK=1.
- **Assuming combinational reads**: They are not. Data appears in `op_fifo` only after `RD_Dly` cycles inside the engine.
- **Ignoring SEL**: The shim expects `SEL=4’hF` for 32-bit access.
- **Expecting synthesizable code**: This is a **behavioral model only**. It uses simulation-only delay loops.

---

## 9) Testbench Tips

The included testbench style does three steps per location:
1. **PROGRAM** → 
2. **Enqueue READ** → 
3. **WB READ (pop)**

It also checks that **ACK only pulses** when the operation occurs (accepting a command or popping data).

---

## 10) Where to Change Things

- **Change delays**:
  - `WR_Dly / RD_Dly` in `Neuromorphic_X1`
  
- **Depths**: The FIFOs are hard-coded at 32 in this simple model.
  
- **FORMING**: **MODE=10** not implemented in simulator 

---

## License/Notes

This model is intended for **internal simulation** and **documentation**. It is not a drop-in hardware implementation. **Use at your own risk**.
