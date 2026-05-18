
`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Wishbone shim: expose ONE address (0x3000_000C).
//  - WB WRITE @ 0x3000_000C  -> send command into core
//  - WB READ  @ 0x3000_000C  -> get result from core
// -----------------------------------------------------------------------------

`ifdef USE_POWER_PINS
    `define USE_PG_PIN
`endif

`celldefine

module Neuromorphic_X1_wb (

`ifdef USE_PG_PIN
   inout         VDDC1,            // 0 V analog ground
   inout         VDDC2,            // 0 V analog ground
   inout         VDDA1,           // 1.8 V analog supply (mapped to vdda1)
   inout         VDDA2,           // 1.8 V analog supply (mapped to vdda1)
   inout         VSS,           // 1.8 V analog core digital supply (mapped to vccd1)
`endif
  input         user_clk,     // user clock
  input         user_rst,     // user reset
  input         wb_clk_i,     // Wishbone clock
  input         wb_rst_i,     // Wishbone reset (Active High)
  input         wbs_stb_i,    // Wishbone strobe
  input         wbs_cyc_i,    // Wishbone cycle indicator
  input         wbs_we_i,     // Wishbone write enable: 1=write, 0=read
  input  [3:0]  wbs_sel_i,    // Wishbone byte select (must be 4'hF for 32-bit op)
  input  [31:0] wbs_dat_i,    // Wishbone write data (becomes DI to core)
  input  [31:0] wbs_adr_i,    // Wishbone address
  output [31:0] wbs_dat_o,    // Wishbone read data output (driven by DO from core)
  output        wbs_ack_o,     // Wishbone acknowledge output (core_ack from core)
  
  // Scan/Test Pins
  input         ScanInCC,        // Scan enable
  input         ScanInDL,        // Data scan chain input (user_clk domain)
  input         ScanInDR,        // Data scan chain input (wb_clk domain)
  input         TM,              // Test mode
  output        ScanOutCC,       // Data scan chain output

  // Analog Pins
  input         Iref,            // 100 µA current reference
  input         Vcc_read,        // 0.3 V read rail
  input         Vcomp,           // 0.6 V comparator bias
  input         Bias_comp2,      // 0.6 V comparator bias
  input         Vcc_wl_read,     // 0.7 V wordline read rail
  input         Vcc_wl_set,      // 1.8 V wordline set rail
  input         Vbias,           // 1.8 V analog bias
  input         Vcc_wl_reset,    // 2.6 V wordline reset rail
  input         Vcc_set,         // 3.3 V array set rail
  input         dc_bias
);

	parameter [31:0] ADDR_MATCH = 32'h3000_0004;
	
	// --------------------------------------------------------------------------
  // Internal wires connecting the shim to the behavioral core
  // --------------------------------------------------------------------------
	wire        CLKin;
  wire        RSTin;
  wire        EN;
  wire [31:0] DI;
  wire        W_RB;
  wire [31:0] DO;
  wire        core_ack;
	
	// Map WB to core
	assign EN = (wbs_stb_i && wbs_cyc_i && (wbs_adr_i == ADDR_MATCH) && (wbs_sel_i == 4'hF));
	assign CLKin      = wb_clk_i;
  assign RSTin      = wb_rst_i;
	assign DI         = wbs_dat_i;
	assign W_RB       = wbs_we_i;
	assign wbs_dat_o  = DO;
	assign wbs_ack_o  = core_ack;
	
	// Instantiate the behavioral core
	Neuromorphic_X1_beh core_inst (
	`ifdef USE_PG_PIN
      .VDDC1(VDDC2),
      .VDDC2(VDDC2),
      .VDDA1(VDDA1),
      .VDDA2(VDDA2),
      .VSS(VSS),
`endif
    .CLKin      (CLKin),
    .RSTin      (RSTin),
    .EN         (EN),
    .DI         (DI),
    .W_RB       (W_RB),
    .DO         (DO),
    .core_ack   (core_ack),
    
    // Scan/Test Pins
    .ScanInCC(ScanInCC),
    .ScanInDL(ScanInDL),
    .ScanInDR(ScanInDR),
    .TM(TM),
    .ScanOutCC(ScanOutCC),

    // Analog Pins
    .Iref(Iref),
    .Vcc_read(Vcc_read),
    .Vcomp(Vcomp),
    .Bias_comp2(Bias_comp2),
    .Vcc_wl_read(Vcc_wl_read),
    .Vcc_wl_set(Vcc_wl_set),
    .Vbias(Vbias),
    .Vcc_wl_reset(Vcc_wl_reset),
    .Vcc_set(Vcc_set),
    .dc_bias(dc_bias)
  );
	
endmodule


// -----------------------------------------------------------------------------
// Behavioral core (sim only)
//  - 32x32 bit array
//  - input FIFO (commands), output FIFO (read results)
//  - PROGRAM (MODE=11): after WR_Dly cycles, write bit
//  - READ    (MODE=01): after RD_Dly cycles, push {31'b0, bit} into output FIFO
//  - WB READ a result: ACK=1 only when a word is popped
//  - If empty: DO=DEAD_C0DE for visibility, but ACK=0 (so the master waits)
// -----------------------------------------------------------------------------


module Neuromorphic_X1_beh (

`ifdef USE_PG_PIN
   inout         VDDC1,            // 0 V analog ground
   inout         VDDC2,            // 0 V analog ground
   inout         VDDA1,           // 1.8 V analog supply (mapped to vdda1)
   inout         VDDA2,           // 1.8 V analog supply (mapped to vdda1)
   inout         VSS,           // 1.8 V analog core digital supply (mapped to vccd1)
`endif

  input         CLKin,
	input         RSTin,
	input         EN,
	input  [31:0] DI,
	input         W_RB,
	output reg [31:0] DO,
	output reg    core_ack,
	
	// Scan/Test Pins
  input         ScanInCC,        // Scan enable
  input         ScanInDL,        // Scan data in (user_clk domain)
  input         ScanInDR,        // Scan data in (wb_clk domain)
  input         TM,              // Test mode
  output        ScanOutCC,       // Scan data out

  // Analog Pins
  input         Iref,            // 100 µA current reference
  input         Vcc_read,        // 0.3 V read rail
  input         Vcomp,           // 0.6 V comparator bias
  input         Bias_comp2,      // 0.6 V comparator bias
  input         Vcc_wl_read,     // 0.7 V wordline read rail
  input         Vcc_wl_set,      // 1.8 V wordline set rail
  input         Vbias,           // 1.8 V analog bias
  input         Vcc_wl_reset,    // 2.6 V wordline reset rail
  input         Vcc_set,         // 3.3 V set rail
  input         dc_bias
);
  
        assign ScanOutCC = 1'b0;
        
	parameter RD_Dly       = 44;  // Clock cycles delay before read data becomes valid
	parameter WR_Dly       = 200; // Write delay (simulate ~1K cycles for real chip)
	
	integer i,j;
	integer arry_row,arry_col;
	
	// 32x32 1-bit memory
	reg array_mem [0:31][0:31];
	
	// Two 32-deep FIFOs (behavioral)
	reg [31:0] ip_fifo [0:31];
	reg [31:0] op_fifo [0:31];
	
	// FIFO pointers/counters
	reg [4:0]  ip_fifo_addr;
	reg [4:0]  ip_fifo_addr_1;
	reg [4:0]  op_fifo_addr;
	reg [4:0]  op_fifo_addr_1;
	integer ip_fifo_size;
	integer op_fifo_size;
	
	// local latches
	reg [31:0] DI_local;
	reg [31:0] DO_local;
  
  `ifndef SYNTHESIS
	// WB side: enqueue on WRITE, pop on READ, ACK only when it happens
  always @(posedge CLKin or posedge RSTin) begin
	  if (RSTin) begin
		
		  DO <= 32'd0;
			core_ack <= 1'b0;
			
			ip_fifo_size <= 0;
			op_fifo_size <= 0;
			ip_fifo_addr <= 0;
			ip_fifo_addr_1 <= 0;
			op_fifo_addr <= 0;
			op_fifo_addr_1 <= 0;
			DI_local <= 0;
			DO_local <= 0;

		end else begin
		  
			core_ack <= 1'b0;
			
			// WB WRITE
			if (EN && W_RB && ip_fifo_size < 32 && !core_ack) begin
			  core_ack <= 1'b1;
				ip_fifo[ip_fifo_addr] <= DI;
				ip_fifo_addr <= (ip_fifo_addr + 1) % 32;
				ip_fifo_size <= ip_fifo_size + 1;
			
		  // WB READ
			end else if (EN && !W_RB && op_fifo_size > 0 && !core_ack) begin
			  core_ack <= 1'b1;
				DO <= op_fifo[op_fifo_addr_1];
				op_fifo_addr_1 <= (op_fifo_addr_1 + 1) % 32;
				op_fifo_size <= op_fifo_size - 1;
			end else if (EN && !W_RB && op_fifo_size == 0 && !core_ack) begin
			  core_ack <= 1'b1;
			  DO <= 32'hDEAD_C0DE;
			end
			
		end
  end
	
	// Engine side (sim-only): executes commands with simple wait loops
	// NOTE: Nested @(posedge) waits are simulation-only (not synthesizable).
	always @(posedge CLKin) begin
	  if (ip_fifo_size > 0 && op_fifo_size < 32) begin
		  DI_local = ip_fifo[ip_fifo_addr_1];
			
			// PROGRAM (MODE=11): write 1 if DATA[7:0]==FF, write 0 if ==00, else X
	    if (DI_local[31:30] == 2'b11) begin  // Write Mode
			  if (DI_local[7:0] > 8'h7F) begin  // NOTE: Value is Greater than Threshold Then 1 is Stored
          DI_local[0] = 1'b1;
				end else if(DI_local[7:0] <= 8'h7F) begin  // NOTE: Value is Less than or Equal to Threshold Then 0 is Stored
          DI_local[0] = 1'b0;
				end
				
				for (i = 0; i < WR_Dly; i = i + 1) begin
          @(posedge CLKin); // delay (sim only)
        end
				
				array_mem[DI_local[29:25]][DI_local[24:20]] = DI_local[0];
				ip_fifo_addr_1 <= (ip_fifo_addr_1 + 1) % 32;
				ip_fifo_size <= ip_fifo_size - 1;
				
			// READ (MODE=01): after delay, push {31'b0, bit} to output FIFO
			end else if(DI_local[31:30] == 2'b01) begin  // Read Mode
			
			  for (j = 0; j < RD_Dly; j = j + 1) begin
          @(posedge CLKin); // delay (sim only)
        end
				
				DO_local = array_mem[DI_local[29:25]][DI_local[24:20]];
				op_fifo[op_fifo_addr] = DO_local;
				op_fifo_addr <= (op_fifo_addr + 1) % 32;
				op_fifo_size <= op_fifo_size + 1;
				ip_fifo_addr_1 <= (ip_fifo_addr_1 + 1) % 32;
				ip_fifo_size <= ip_fifo_size - 1;
		  end
			// FORMING/NOP not implemented in this minimal version
	  end
	end
	`endif
	
	initial begin
	 	// init array to 0
		for (arry_row = 0; arry_row < 32; arry_row = arry_row + 1) begin
       for (arry_col = 0; arry_col < 32; arry_col = arry_col + 1) begin
         array_mem[arry_row][arry_col] = 1'b0;
       end
     end
	end

endmodule
`endcelldefine


