# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer


# ============================================================
# Helper function
# Drive the Tiny Tapeout input pins
#
# ui_in mapping:
#   [1:0] = mode
#   [2]   = write enable
#   [5:3] = address
#   [7:6] = wdata[1:0]
#
# uio_in mapping:
#   [7:2] = wdata[7:2]
#   [1:0] = unused because these are output pins
# ============================================================

def drive_inputs(dut, mode, we, addr, data):

    ui_value = (
        (mode & 0b11)
        | ((we & 0b1) << 2)
        | ((addr & 0b111) << 3)
        | ((data & 0b11) << 6)
    )

    uio_value = ((data >> 2) & 0b111111) << 2

    dut.ui_in.value = ui_value
    dut.uio_in.value = uio_value


# ============================================================
# Helper function
# Write data to memory
# ============================================================

async def write_memory(dut, mode, addr, data):

    drive_inputs(
        dut,
        mode=mode,
        we=1,
        addr=addr,
        data=data
    )

    # Memory write occurs on positive clock edge
    await ClockCycles(dut.clk, 1)

    # Disable write
    drive_inputs(
        dut,
        mode=mode,
        we=0,
        addr=addr,
        data=data
    )

    await ClockCycles(dut.clk, 1)


# ============================================================
# Helper function
# Read data from memory
# ============================================================

async def read_memory(dut, mode, addr, expected_data):

    drive_inputs(
        dut,
        mode=mode,
        we=0,
        addr=addr,
        data=0
    )

    await ClockCycles(dut.clk, 1)

    # Allow combinational decoder to settle
    await Timer(1, unit="ns")

    read_data = int(dut.uo_out.value)

    assert read_data == expected_data, (
        f"Read data mismatch: "
        f"Mode={mode:02b}, "
        f"Address={addr}, "
        f"Expected=0x{expected_data:02X}, "
        f"Got=0x{read_data:02X}"
    )

    # No error should be reported during normal operation
    single_error = int(dut.uio_out.value) & 0x01
    double_error = (int(dut.uio_out.value) >> 1) & 0x01

    assert single_error == 0, (
        f"Unexpected single-bit error in normal operation: "
        f"Mode={mode:02b}, Address={addr}"
    )

    assert double_error == 0, (
        f"Unexpected double-bit error in normal operation: "
        f"Mode={mode:02b}, Address={addr}"
    )


# ============================================================
# Main test
# ============================================================

@cocotb.test()
async def test_project(dut):

    dut._log.info("==========================================")
    dut._log.info("Runtime-Reconfigurable ECC Memory Test")
    dut._log.info("==========================================")

    # --------------------------------------------------------
    # Clock
    # 10 us period = 100 kHz
    # --------------------------------------------------------

    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # --------------------------------------------------------
    # Initial values
    # --------------------------------------------------------

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    # --------------------------------------------------------
    # Reset
    # --------------------------------------------------------

    dut._log.info("Applying reset...")

    await ClockCycles(dut.clk, 5)

    dut.rst_n.value = 1

    await ClockCycles(dut.clk, 2)

    dut._log.info("Reset released")

    # --------------------------------------------------------
    # Check bidirectional pin configuration
    #
    # uio[1:0] = outputs
    # uio[7:2] = inputs
    #
    # Expected uio_oe = 00000011 = 0x03
    # --------------------------------------------------------

    uio_oe = int(dut.uio_oe.value)

    assert uio_oe == 0x03, (
        f"Incorrect uio_oe configuration. "
        f"Expected 0x03, Got 0x{uio_oe:02X}"
    )

    dut._log.info("PASS: UIO direction configuration")


    # ========================================================
    # TEST 1: OFF MODE
    # ========================================================

    dut._log.info("TEST 1: OFF MODE")

    await write_memory(
        dut,
        mode=0b00,
        addr=0,
        data=0xA5
    )

    await read_memory(
        dut,
        mode=0b00,
        addr=0,
        expected_data=0xA5
    )

    dut._log.info("PASS: OFF MODE")


    # ========================================================
    # TEST 2: PARITY MODE
    # ========================================================

    dut._log.info("TEST 2: PARITY MODE")

    await write_memory(
        dut,
        mode=0b01,
        addr=1,
        data=0x3C
    )

    await read_memory(
        dut,
        mode=0b01,
        addr=1,
        expected_data=0x3C
    )

    dut._log.info("PASS: PARITY MODE")


    # ========================================================
    # TEST 3: HAMMING MODE
    # ========================================================

    dut._log.info("TEST 3: HAMMING MODE")

    await write_memory(
        dut,
        mode=0b10,
        addr=2,
        data=0x5A
    )

    await read_memory(
        dut,
        mode=0b10,
        addr=2,
        expected_data=0x5A
    )

    dut._log.info("PASS: HAMMING MODE")


    # ========================================================
    # TEST 4: SECDED MODE
    # ========================================================

    dut._log.info("TEST 4: SECDED MODE")

    await write_memory(
        dut,
        mode=0b11,
        addr=3,
        data=0xC3
    )

    await read_memory(
        dut,
        mode=0b11,
        addr=3,
        expected_data=0xC3
    )

    dut._log.info("PASS: SECDED MODE")


    # ========================================================
    # TEST 5: RUNTIME MODE SWITCHING
    #
    # Same memory address is written using different modes.
    # Each mode is verified immediately after the write.
    # ========================================================

    dut._log.info("TEST 5: RUNTIME MODE SWITCHING")

    # OFF
    await write_memory(
        dut,
        mode=0b00,
        addr=5,
        data=0x11
    )

    await read_memory(
        dut,
        mode=0b00,
        addr=5,
        expected_data=0x11
    )

    # PARITY
    await write_memory(
        dut,
        mode=0b01,
        addr=5,
        data=0x22
    )

    await read_memory(
        dut,
        mode=0b01,
        addr=5,
        expected_data=0x22
    )

    # HAMMING
    await write_memory(
        dut,
        mode=0b10,
        addr=5,
        data=0x33
    )

    await read_memory(
        dut,
        mode=0b10,
        addr=5,
        expected_data=0x33
    )

    # SECDED
    await write_memory(
        dut,
        mode=0b11,
        addr=5,
        data=0x44
    )

    await read_memory(
        dut,
        mode=0b11,
        addr=5,
        expected_data=0x44
    )

    dut._log.info("PASS: RUNTIME MODE SWITCHING")


    # ========================================================
    # TEST 6: MULTIPLE MEMORY LOCATIONS
    # ========================================================

    dut._log.info("TEST 6: MULTIPLE MEMORY LOCATIONS")

    test_values = [
        (0, 0x00),
        (1, 0xFF),
        (2, 0x55),
        (3, 0xAA),
        (4, 0x96),
        (5, 0x69),
        (6, 0x12),
        (7, 0xE7),
    ]

    for addr, data in test_values:

        await write_memory(
            dut,
            mode=0b11,
            addr=addr,
            data=data
        )

        await read_memory(
            dut,
            mode=0b11,
            addr=addr,
            expected_data=data
        )

    dut._log.info("PASS: MULTIPLE MEMORY LOCATIONS")


    # ========================================================
    # FINAL RESULT
    # ========================================================

    dut._log.info("==========================================")
    dut._log.info("ALL ECC MEMORY TESTS PASSED")
    dut._log.info("==========================================")
