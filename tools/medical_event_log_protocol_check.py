#!/usr/bin/env python3
"""Host-side exhaustive checks for the X1 medical event record protocol."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

COMMIT_A_BIT = 30
COMMIT_B_BIT = 31
COMMIT_MASK = 0xC0000000
PAYLOAD_MASK = 0x3FFFFFFF


@dataclass(frozen=True)
class Record:
    event_code: int
    sequence: int
    source: int
    severity: int


def crc8_update(crc: int, data: int) -> int:
    for _ in range(8):
        feedback = (crc ^ data) & 0x80
        crc = (crc << 1) & 0xFF
        if feedback:
            crc ^= 0x07
        data = (data << 1) & 0xFF
    return crc


def record_crc(record: Record) -> int:
    crc = 0
    for byte in (
        record.event_code,
        record.sequence,
        ((record.source & 0x0F) << 4) | (record.severity & 0x03),
    ):
        crc = crc8_update(crc, byte)
    return crc


def payload(record: Record) -> int:
    return (
        (record.event_code & 0xFF)
        | ((record.sequence & 0xFF) << 8)
        | ((record.source & 0x0F) << 16)
        | ((record.severity & 0x03) << 20)
        | (record_crc(record) << 22)
    )


def encode_committed(record: Record) -> int:
    return payload(record) | COMMIT_MASK


def is_valid(raw: int) -> bool:
    if raw & COMMIT_MASK != COMMIT_MASK:
        return False
    decoded = Record(
        event_code=raw & 0xFF,
        sequence=(raw >> 8) & 0xFF,
        source=(raw >> 16) & 0x0F,
        severity=(raw >> 20) & 0x03,
    )
    return ((raw >> 22) & 0xFF) == record_crc(decoded)


def overwrite_operations(record: Record) -> list[tuple[str, int]]:
    """Return ordered (operation, bit) actions used by firmware."""
    actions: list[tuple[str, int]] = [
        ("reset", COMMIT_B_BIT),
        ("reset", COMMIT_A_BIT),
    ]
    actions.extend(("reset", bit) for bit in range(COMMIT_A_BIT))
    value = payload(record)
    actions.extend(
        ("set", bit) for bit in range(COMMIT_A_BIT) if value & (1 << bit)
    )
    actions.extend((("set", COMMIT_A_BIT), ("set", COMMIT_B_BIT)))
    return actions


def apply(raw: int, actions: Iterable[tuple[str, int]]) -> int:
    for operation, bit in actions:
        if operation == "set":
            raw |= 1 << bit
        elif operation == "reset":
            raw &= ~(1 << bit)
        else:
            raise ValueError(f"unknown operation: {operation}")
    return raw & 0xFFFFFFFF


def main() -> None:
    old = Record(0x01, 0x7E, 0, 0)
    new = Record(0x30, 0x7F, 2, 0)
    actions = overwrite_operations(new)
    initial = encode_committed(old)

    # Before the first operation, the old record is still safely valid. After
    # invalidation begins, every interrupted prefix must be rejected. Only the
    # complete sequence may expose the new record as valid.
    assert is_valid(initial)
    for cut in range(1, len(actions)):
        torn = apply(initial, actions[:cut])
        assert not is_valid(torn), (
            f"interrupted overwrite validated at operation {cut}/{len(actions)}: "
            f"0x{torn:08X}"
        )

    completed = apply(initial, actions)
    assert is_valid(completed)
    assert completed & PAYLOAD_MASK == payload(new)

    # Every single-bit payload/CRC corruption of a committed row is detected.
    for bit in range(COMMIT_A_BIT):
        corrupted = completed ^ (1 << bit)
        assert not is_valid(corrupted), f"single-bit corruption escaped at bit {bit}"

    # Clearing either commit marker also invalidates replay.
    assert not is_valid(completed & ~(1 << COMMIT_A_BIT))
    assert not is_valid(completed & ~(1 << COMMIT_B_BIT))

    print(f"PASS: checked {len(actions) - 1} interrupted overwrite points")
    print(f"PASS: checked {COMMIT_A_BIT} single-bit payload/CRC corruptions")
    print(f"PASS: completed record = 0x{completed:08X}")


if __name__ == "__main__":
    main()
