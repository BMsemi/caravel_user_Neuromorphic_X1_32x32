# SPDX-FileCopyrightText: 2026 BMsemi contributors
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.triggers import ClockCycles

from caravel_cocotb.caravel_interfaces import report_test, test_configure


@cocotb.test()
@report_test
async def medical_event_log(dut):
    """Run the firmware-driven X1 medical event-log recovery demo."""

    caravel_env = await test_configure(dut, timeout_cycles=2_000_000)
    cocotb.log.info("[MEDLOG] Waiting for firmware initialization")

    await ClockCycles(caravel_env.clk, 10)
    await caravel_env.wait_mgmt_gpio(1)
    cocotb.log.info("[MEDLOG] Firmware ready; releasing CSB")

    await caravel_env.release_csb()

    # Firmware leaves mgmt_gpio high on any self-check failure. A passing run
    # lowers it after accepting two committed records and rejecting one torn
    # record plus one CRC-corrupted record.
    await caravel_env.wait_mgmt_gpio(0)
    cocotb.log.info(
        "[MEDLOG] PASS: committed records replayed; torn/corrupt records rejected"
    )
