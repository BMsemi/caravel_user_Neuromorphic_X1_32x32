# X1 Medical-Device Event Logger Demo

## Scope

This demo uses the Caravel Wishbone mailbox at `0x3000_0004` to treat the
Neuromorphic X1 32x32 ReRAM array as a tiny append-style event journal. It is a
research and verification example, not a certified medical-device subsystem and
not the sole record of a therapy or alarm.

The implementation follows the direct X1/Caravel integration in this repository
and borrows the macro-integration pattern from `BMsemi/IMPACT_SNN_RERAM_submit`:
Wishbone control, explicit X1 analog/bias pins, scan/test pins, and macro-first
physical design. The event format is implemented in firmware so the existing
`user_project_wrapper` and hardened X1 macro interface remain unchanged.

## Record format

One X1 row is one 32-bit log slot. The row number is the physical slot; firmware
uses the 8-bit sequence field to order records after reset.

| X1 columns | Field | Purpose |
| --- | --- | --- |
| 0-7 | event code | Boot, sensor fault, therapy delivery, battery/power warning |
| 8-15 | sequence | Monotonic sequence modulo 256 |
| 16-19 | source | Up to 16 sensor/therapy subsystems |
| 20-21 | severity | Info, warning, critical, reserved |
| 22-29 | CRC-8 | Polynomial `0x07` over event, sequence, source, severity |
| 30 | commit A | Written after payload and CRC |
| 31 | commit B | Written last; both commit bits are required |

A row is replayable only when both commit bits are `1` and the CRC matches. This
is a two-phase commit marker: loss of power before the last write leaves the row
invalid instead of presenting a partially written event as complete.

## Firmware proof

`medical_event_log.c` performs four scenarios through the mailbox:

1. Writes and replays a committed boot event.
2. Simulates a power interruption by writing a battery-low event with only
   commit A; replay must reject it.
3. Writes and replays a committed therapy-delivered event.
4. Commits a sensor-fault event, corrupts one payload bit, and proves CRC
   rejection.

The firmware self-check keeps management GPIO high on failure and lowers it only
when all four scenarios behave as expected. Cocotb treats that falling edge as
the pass condition.

## Run RTL verification

```bash
cd verilog/dv/cocotb
../../../venv-cocotb/bin/caravel_cocotb \
  -t medical_event_log \
  -sim RTL \
  -tag medical_event_log_rtl_$(date +%Y%m%d_%H%M%S)
```

Expected proof:

- three initial mailbox writes configure the X1 behavioral model;
- Wishbone writes enqueue reset/program/read commands at `0x3000_0004`;
- reads wait for X1 result ACK/data;
- valid committed rows survive replay;
- a torn row and a CRC-corrupted row are excluded.

## Medical-device engineering assumptions

| Area | Demo assumption | Production requirement |
| --- | --- | --- |
| Power loss | Payload/CRC precede two commit bits. | A supervisor must inhibit writes below the valid rail and provide enough hold-up energy for the worst-case erase/program sequence. Characterize the real macro and board; the demo does not prove brownout behavior. |
| Latency | The current behavioral model uses 207 cycles for a selected-cell program/reset and 155 cycles for a read-result path. | Measure silicon across voltage and temperature. The X1 repository also describes approximately 10 us per page; do not turn either model number into a clinical timing claim without characterization. |
| Retention | ReRAM state is treated as nonvolatile across normal operation. | Obtain vendor retention/endurance data and verify it across device lifetime, storage, sterilization if applicable, and the operating temperature range. No validated retention number is present in the template repository. |
| Reliability | CRC-8 detects corruption; duplicate commit bits detect incomplete writes. | Add wear leveling, sequence-wrap handling, bad-row management, stronger CRC/ECC or redundant copies, periodic scrubbing, and an independent external audit log. |
| Environment | The Caravel/X1 macro rails, references, and bias pins are assumed valid. | Define supply tolerances, startup/shutdown ordering, EMC/ESD protections, temperature limits, clock tolerance, and analog reference monitoring. |
| Safety | Log data is informational in this demo. | Perform system hazard analysis, requirements traceability, verification, cybersecurity review, and applicable medical-device lifecycle/regulatory work. Never make therapy depend solely on this demonstrator. |

## Capacity and wear policy

The array provides 32 physical rows, so this format stores 32 records before
reuse. A production logger should use sequence-to-row mapping, erase only the
oldest confirmed row, keep endurance counters, and mirror critical events in a
larger external nonvolatile store. The current demo clears a row before writing
it to make repeated simulation deterministic; that is not an endurance-optimized
policy.

## XForge SDK note

The referenced `Benchmarking/XForge_sdk` branch is available, but its README
currently describes an X2/YOLO simulation and mapping flow rather than this X1
mailbox protocol. This demo therefore uses the X1 behavioral model and direct
Wishbone command encoding. The SDK can be revisited when an X1-specific compiler
or event-log mapper is published.

## Physical-design and signoff gate

Firmware-only changes do not replace a fresh physical-design run. Before review,
run `make user_project_wrapper` and inspect at least:

```text
signoff/user_project_wrapper/openlane-signoff/drc.rpt
signoff/user_project_wrapper/openlane-signoff/29-user_project_wrapper.lvs.rpt
signoff/user_project_wrapper/openlane-signoff/antenna_summary.rpt
signoff/user_project_wrapper/openlane-signoff/25-xor.rpt
signoff/user_project_wrapper/openlane-signoff/timing-reports/summary.rpt
signoff/user_project_wrapper/metrics.csv
```

The repository's checked-in baseline reports show clean DRC/LVS/antenna/XOR and
zero setup/hold violations, but they also report max-slew and max-fanout
violations. Those inherited violations must remain visible and must be rechecked
after a new hardening run.

## GL status

Do not claim GL proof until `verilog/gl/user_project_wrapper.v` contains the
newly generated wrapper netlist and the X1 hard-macro simulation view resolves.
Until then, RTL cocotb plus a fresh signoff report set are the required review
evidence.
