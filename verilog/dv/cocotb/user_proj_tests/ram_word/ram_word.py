# SPDX-FileCopyrightText: 2023 Efabless Corporation
# SPDX-License-Identifier: Apache-2.0

from caravel_cocotb.caravel_interfaces import test_configure
from caravel_cocotb.caravel_interfaces import report_test
import cocotb
from cocotb.triggers import ClockCycles

# GPIO pads (Caravel mprj_io indices)
GPIO_SCAN_IN_DR = 24   # ScanInDR
GPIO_TM          = 26  # TM

# Sequence of (TM, ScanInDR) pairs
# seq [
#   0, 1,
#   1, 0,
#   0, 1
# ]
SEQ = [
    (0, 1),
    (1, 0),
    (0, 1),
]

async def drive_sequence(dut, caravelEnv, seq, hold_cycles=1):
    """
    Drive (TM, ScanInDR) in parallel according to seq.
    Each tuple is (tm_value, scan_value) and is held for hold_cycles.
    """
    for tm_val, scan_val in seq:
        # Parallel update: both signals change in the same delta cycle
        dut.uut.mprj_io[GPIO_TM].value         = tm_val
        dut.uut.mprj_io[GPIO_SCAN_IN_DR].value = scan_val
        # Hold this state for the requested number of clock cycles
        await ClockCycles(caravelEnv.clk, hold_cycles)


@cocotb.test()
@report_test
async def ram_word(dut):

    # Configure Caravel test environment
    caravelEnv = await test_configure(dut, timeout_cycles=500_000)
    cocotb.log.info("[TEST] Starting ReRam_word test")

    # Initial values on the pads (before firmware handshake)
    # These are just safe defaults; real sequence starts after release_csb()
    dut.uut.mprj_io[GPIO_SCAN_IN_DR].value = 0
    dut.uut.mprj_io[GPIO_TM].value        = 0

    # Let things settle a bit after reset/config (e.g. 10 cycles)
    await ClockCycles(caravelEnv.clk, 10)

    # Wait for firmware to signal it is ready: mgmt_gpio = 1
    cocotb.log.info("[TEST] Waiting for mgmt_gpio == 1 from firmware")
    await caravelEnv.wait_mgmt_gpio(1)
    cocotb.log.info("[TEST] Firmware signalled ready (mgmt_gpio = 1)")

    # --------------------------------------------------------
    # RELEASE CSB FIRST (your requirement)
    # --------------------------------------------------------
    await caravelEnv.release_csb()
    cocotb.log.info("[TEST] CSB released, starting TM/ScanInDR sequence")

    # Optional: small wait after CSB release (e.g. 2 cycles)
    # await ClockCycles(caravelEnv.clk, 2)

    # --------------------------------------------------------
    # Now drive the parallel sequence on (TM, ScanInDR)
    # --------------------------------------------------------
    # Each pair is:
    #   (TM, ScanInDR) = (0,1) → (1,0) → (0,1)
    await drive_sequence(dut, caravelEnv, SEQ, hold_cycles=1)

    # Optional: keep final state for a few more cycles
    await ClockCycles(caravelEnv.clk, 5)

    # Wait for firmware to signal completion: mgmt_gpio = 0
    cocotb.log.info("[TEST] Waiting for mgmt_gpio == 0 (firmware done)")
    await caravelEnv.wait_mgmt_gpio(0)
    cocotb.log.info("[TEST] Completed Write and Read")

