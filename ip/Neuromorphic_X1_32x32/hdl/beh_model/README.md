# Neuromorphic_X1 Behavioral Model (Wishbone)

**Version**: Simulation-only  
**Address used**: 0x3000_0004

---

## 1) What this is

This is a **non-synthesizable behavioral model** of a 32×32 1-bit array with a **Wishbone shim** in front. It is intended for simulation. It demonstrates how software can send **“commands”** over Wishbone to:

- Program a cell
- Request a read
- Return read data later

### Files in this project:

- **Neuromorphic_X1_wb**: The Wishbone shim. It exposes **ONE address** (0x3000_0004). Writes/reads at that address are forwarded to the core.
- **Neuromorphic_X1**: The behavioral **core** that holds:
  - The 32×32 array
  - An input FIFO (commands)
  - An output FIFO (read data)

**Important**: This model uses `@(posedge clk)` inside `always` blocks to create delay loops. This is **for simulation only** and is **not synthesizable**.

---

## 2) The One Wishbone Address (0x3000_0004)

The shim only has address `0x3000_0004`:

- **WB WRITE** to `0x3000_0004`: Your 32-bit word is treated as a command.
- **WB READ** from `0x3000_0004`: You pop one 32-bit word of read data.

### The shim checks:

`EN = (stb & cyc & (adr == 0x3000_0004) & (sel == 4’hF))`

### Signal Mapping (shim → core):

| Signal    | Description |
|-----------|-------------|
| CLKin     | `wb_clk_i` |
| RSTin     | `wb_rst_i` |
| DI        | `wbs_dat_i` (write data / command word) |
| W_RB      | `wbs_we_i` (1 = write command, 0 = read pop) |
| DO        | `wbs_dat_o` (read data back to Wishbone) |
| core_ack  | `wbs_ack_o` (acknowledge back to Wishbone) |

### ACK Behavior

- **For a WRITE cycle** at `0x3000_0004`, `core_ack = 1` when the command is successfully pushed into the input FIFO.
- **For a READ cycle** at `0x3000_0004`:
  - If valid data is available in `op_fifo`, one word is popped into `DO` and `ACK=1`.
  - If no data is available in `op_fifo`, `ACK` is still asserted and `DO = 32'hDEAD_C0DE`.

This prevents the master from halting or getting stuck waiting forever.

Also, if a READ command is issued but Wishbone read is initiated **before data is fetched from the crossbar array into `op_fifo`**, then:
- `ACK = 1`
- `DO = 32'hDEAD_C0DE`

This acts as a “not ready / retry later” response.

---

## 3) Command Word Format (The 32-bit DI)

**Bits**:
- `[31:30] MODE`
- `[29:25] ROW`
- `[24:20] COL`
- `[19:0] DATA/flags`

### Supported MODE values

- **2’b11** → PROGRAM (Write bit at [ROW][COL])
- **2’b01** → READ (Queue read of [ROW][COL])
- **2’b10** → FORMING (reserved / not implemented)

#### PROGRAM (MODE=2’b11)

Programming decision is based on `DATA[7:0]` threshold:

- If `DATA[7:0] > 8'h7F` → write `1` into the cell
- If `DATA[7:0] <= 8'h7F` → write `0` into the cell

Examples:
- `8'hFF` → writes `1`
- `8'h80` → writes `1`
- `8'h7F` → writes `0`
- `8'h00` → writes `0`

#### READ (MODE=2’b01)

- Core later pushes bit at `[ROW][COL]` into output FIFO.
- WB READ at `0x3000_0004` pops one value when available.
- If unavailable, returns `32'hDEAD_C0DE`.

---

## 4) Core Internals

- **32×32 1-bit array**: `array_mem[row][col]`
- **Input FIFO** (`ip_fifo`, depth 32)
- **Output FIFO** (`op_fifo`, depth 32)

### Engine behavior

- Pops commands from `ip_fifo`
- PROGRAM: waits `WR_Dly`, then updates bit
- READ: waits `RD_Dly`, then pushes result into `op_fifo`

---

## 5) Timing / Delays

**Default delays:**
- `WR_Dly = 200`
- `RD_Dly = 44`

Writes are acknowledged immediately after enqueue.

Reads:
- Return real data if available
- Else return `32'hDEAD_C0DE`

---

## 6) Software Example

Use address: `0x3000_0004`

**PROGRAM cell (row=1, col=1):**
```c
write32(0x3000_0004, {2’b11, 5’d1, 5’d1, 20’h080});
```

**Queue READ:**
```c
write32(0x3000_0004, {2’b01, 5’d1, 5’d1, 20’h00000});
```

**Pop result:**
```c
if Read Immediately
data = read32(0x3000_0004);

if (data == 0xDEADC0DE) {
    // data not ready, retry later
}
```

```c
if Read after Read Delay
data = read32(0x3000_0004);

if (data == 0x00000001) {
    // data was ready and valid
}
```

---

## 7) Notes

This is a **simulation-only behavioral model** intended for documentation and verification.
