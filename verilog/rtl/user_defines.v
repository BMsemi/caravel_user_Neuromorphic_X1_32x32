`default_nettype none

`ifndef __USER_DEFINES_H
`define __USER_DEFINES_H

// ============================================================================
// GPIO mode encodings (from caravel defs.h)
// ============================================================================
`define GPIO_MODE_INVALID                  13'hXXXX

// Management SoC Modes
`define GPIO_MODE_MGMT_STD_INPUT_NOPULL    13'h0403
`define GPIO_MODE_MGMT_STD_INPUT_PULLDOWN  13'h0c01
`define GPIO_MODE_MGMT_STD_INPUT_PULLUP    13'h0801
`define GPIO_MODE_MGMT_STD_OUTPUT          13'h1809
`define GPIO_MODE_MGMT_STD_BIDIRECTIONAL   13'h1801
`define GPIO_MODE_MGMT_STD_ANALOG          13'h000b

// User Project Modes
`define GPIO_MODE_USER_STD_INPUT_NOPULL    13'h0402
`define GPIO_MODE_USER_STD_INPUT_PULLDOWN  13'h0c00
`define GPIO_MODE_USER_STD_INPUT_PULLUP    13'h0800
`define GPIO_MODE_USER_STD_OUTPUT          13'h1808
`define GPIO_MODE_USER_STD_BIDIRECTIONAL   13'h1800
`define GPIO_MODE_USER_STD_OUT_MONITORED   13'h1802
`define GPIO_MODE_USER_STD_ANALOG          13'h000a

// ============================================================================
// GPIO configuration in NUMERICAL ORDER (0 → 37)
//
// analog_io[0]  = GPIO 7
// analog_io[n]  = GPIO (7 + n)
// ============================================================================

// GPIO 0–4 : SPI / debug (do not touch)
`define USER_CONFIG_GPIO_0_INIT  `GPIO_MODE_MGMT_STD_INPUT_NOPULL  // GPIO 0
`define USER_CONFIG_GPIO_1_INIT  `GPIO_MODE_MGMT_STD_INPUT_NOPULL  // GPIO 1
`define USER_CONFIG_GPIO_2_INIT  `GPIO_MODE_MGMT_STD_INPUT_NOPULL  // GPIO 2
`define USER_CONFIG_GPIO_3_INIT  `GPIO_MODE_MGMT_STD_INPUT_NOPULL  // GPIO 3
`define USER_CONFIG_GPIO_4_INIT  `GPIO_MODE_MGMT_STD_INPUT_NOPULL  // GPIO 4

// GPIO 5–6 : unused → analog (safe)
`define USER_CONFIG_GPIO_5_INIT  `GPIO_MODE_USER_STD_ANALOG        // GPIO 5
`define USER_CONFIG_GPIO_6_INIT  `GPIO_MODE_USER_STD_ANALOG        // GPIO 6

// GPIO 7–20 : generic analog pads (analog_io[0]–[13])
`define USER_CONFIG_GPIO_7_INIT  `GPIO_MODE_USER_STD_ANALOG        // GPIO 7  = analog_io[0]
`define USER_CONFIG_GPIO_8_INIT  `GPIO_MODE_USER_STD_ANALOG        // GPIO 8  = analog_io[1]
`define USER_CONFIG_GPIO_9_INIT  `GPIO_MODE_USER_STD_ANALOG        // GPIO 9  = analog_io[2]
`define USER_CONFIG_GPIO_10_INIT `GPIO_MODE_USER_STD_ANALOG        // GPIO 10 = analog_io[3]
`define USER_CONFIG_GPIO_11_INIT `GPIO_MODE_USER_STD_ANALOG        // GPIO 11 = analog_io[4]
`define USER_CONFIG_GPIO_12_INIT `GPIO_MODE_USER_STD_ANALOG        // GPIO 12 = analog_io[5]
`define USER_CONFIG_GPIO_13_INIT `GPIO_MODE_USER_STD_ANALOG        // GPIO 13 = analog_io[6]
`define USER_CONFIG_GPIO_14_INIT `GPIO_MODE_USER_STD_ANALOG        // GPIO 14 = analog_io[7]
`define USER_CONFIG_GPIO_15_INIT `GPIO_MODE_USER_STD_ANALOG        // GPIO 15 = analog_io[8]
`define USER_CONFIG_GPIO_16_INIT `GPIO_MODE_USER_STD_ANALOG        // GPIO 16 = analog_io[9]
`define USER_CONFIG_GPIO_17_INIT `GPIO_MODE_USER_STD_ANALOG        // GPIO 17 = analog_io[10]
`define USER_CONFIG_GPIO_18_INIT `GPIO_MODE_USER_STD_ANALOG        // GPIO 18 = analog_io[11]
`define USER_CONFIG_GPIO_19_INIT `GPIO_MODE_USER_STD_ANALOG        // GPIO 19 = analog_io[12]
`define USER_CONFIG_GPIO_20_INIT `GPIO_MODE_USER_STD_ANALOG        // GPIO 20 = analog_io[13]

// GPIO 21–23 : Scan digital pins (from image)
`define USER_CONFIG_GPIO_21_INIT `GPIO_MODE_USER_STD_INPUT_PULLDOWN // GPIO 21 = ScanInDR  (io_in[21])
`define USER_CONFIG_GPIO_22_INIT `GPIO_MODE_USER_STD_INPUT_PULLUP   // GPIO 22 = ScanInDL  (io_in[22])
`define USER_CONFIG_GPIO_23_INIT `GPIO_MODE_USER_STD_OUTPUT         // GPIO 23 = ScanOutCC (io_out[23])

// GPIO 24 : free → mgmt output
`define USER_CONFIG_GPIO_24_INIT `GPIO_MODE_MGMT_STD_OUTPUT         // GPIO 24 (unused digital)

// GPIO 25–34 : MAIN ANALOG BIASES (exact order from picture)
//   analog_io[18] → GPIO 25 : dc_bias
//   analog_io[19] → GPIO 26 : Vcc_wl_read
//   analog_io[20] → GPIO 27 : Vcc_set
//   analog_io[21] → GPIO 28 : Vcc_wl_reset
//   analog_io[22] → GPIO 29 : Vbias
//   analog_io[23] → GPIO 30 : Vcc_wl_set
//   analog_io[24] → GPIO 31 : Bias_comp2
//   analog_io[25] → GPIO 32 : Vcomp
//   analog_io[26] → GPIO 33 : Vcc_read
//   analog_io[27] → GPIO 34 : Iref
`define USER_CONFIG_GPIO_25_INIT `GPIO_MODE_USER_STD_ANALOG         // GPIO 25 = dc_bias
`define USER_CONFIG_GPIO_26_INIT `GPIO_MODE_USER_STD_ANALOG         // GPIO 26 = Vcc_wl_read
`define USER_CONFIG_GPIO_27_INIT `GPIO_MODE_USER_STD_ANALOG         // GPIO 27 = Vcc_set
`define USER_CONFIG_GPIO_28_INIT `GPIO_MODE_USER_STD_ANALOG         // GPIO 28 = Vcc_wl_reset
`define USER_CONFIG_GPIO_29_INIT `GPIO_MODE_USER_STD_ANALOG         // GPIO 29 = Vbias
`define USER_CONFIG_GPIO_30_INIT `GPIO_MODE_USER_STD_ANALOG         // GPIO 30 = Vcc_wl_set
`define USER_CONFIG_GPIO_31_INIT `GPIO_MODE_USER_STD_ANALOG         // GPIO 31 = Bias_comp2
`define USER_CONFIG_GPIO_32_INIT `GPIO_MODE_USER_STD_ANALOG         // GPIO 32 = Vcomp
`define USER_CONFIG_GPIO_33_INIT `GPIO_MODE_USER_STD_ANALOG         // GPIO 33 = Vcc_read
`define USER_CONFIG_GPIO_34_INIT `GPIO_MODE_USER_STD_ANALOG         // GPIO 34 = Iref

// GPIO 35–36 : remaining scan pins
`define USER_CONFIG_GPIO_35_INIT `GPIO_MODE_USER_STD_INPUT_PULLDOWN // GPIO 35 = ScanInCC (io_in[35])
`define USER_CONFIG_GPIO_36_INIT `GPIO_MODE_USER_STD_INPUT_PULLUP   // GPIO 36 = TM       (io_in[36])

// GPIO 37 : free → mgmt output
`define USER_CONFIG_GPIO_37_INIT `GPIO_MODE_MGMT_STD_OUTPUT         // GPIO 37

`endif // __USER_DEFINES_H

