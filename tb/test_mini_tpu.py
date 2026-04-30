import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import numpy as np

# helper function to pack four 8-bit numbers into our 32-bit memory row
def pack_row(a0, a1, b0, b1):
    return (int(a0) << 24) | (int(a1) << 16) | (int(b0) << 8) | int(b1)

@cocotb.test()
async def test_tpu_random_matrices(dut):
    """Test the Mini-TPU with randomly generated matrices against a NumPy golden model."""
    
    # Create two random 2x2 matrices with numbers between 1 and 9
    A = np.random.randint(1, 10, size=(2, 2))
    B = np.random.randint(1, 10, size=(2, 2))
    
    # Calculate the exact mathematical answer instantly in Python
    expected_C = np.dot(A, B)
    
    dut._log.info(f"--- Software Golden Model --- \nMatrix A:\n{A}\nMatrix B:\n{B}\nExpected Answer:\n{expected_C}")

  
    # START THE CLOCK
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())


    # RESET THE CHIP
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(40, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


    # DATA SKEWING & MEMORY INJECTION
    # We must stagger the data diagonally 
    # Format: [A0, A1, B0, B1]
    row0 = pack_row(A[0,0], 0,      B[0,0], 0)
    row1 = pack_row(A[1,0], A[0,1], B[0,1], B[1,0])
    row2 = pack_row(0,      A[1,1], 0,      B[1,1])
    row3 = pack_row(0,      0,      0,      0)

    # Inject directly into the inferred BSRAM
    dut.memory_block.ram_block[0].value = row0
    dut.memory_block.ram_block[1].value = row1
    dut.memory_block.ram_block[2].value = row2
    dut.memory_block.ram_block[3].value = row3

  
    # TRIGGER THE HARDWARE FSM
    dut._log.info("Firing hardware start pulse...")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for the FSM to pulse the 'done' signal
    while dut.done.value == 0:
        await RisingEdge(dut.clk)

    # Wait one extra cycle for safety
    await RisingEdge(dut.clk) 

  
    # HARDWARE ASSERTIONS (THE FINAL CHECK)
    # Read the copper wires
    res_00 = dut.result_00.value.integer
    res_01 = dut.result_01.value.integer
    res_10 = dut.result_10.value.integer
    res_11 = dut.result_11.value.integer

    dut._log.info(f"--- Hardware Accelerator Output --- \n[{res_00}, {res_01}]\n[{res_10}, {res_11}]")

    # If any of these fail, Cocotb immediately stops the test and throws a massive red error
    assert res_00 == expected_C[0,0], f"Hardware failed at 0,0: Got {res_00}, Expected {expected_C[0,0]}"
    assert res_01 == expected_C[0,1], f"Hardware failed at 0,1: Got {res_01}, Expected {expected_C[0,1]}"
    assert res_10 == expected_C[1,0], f"Hardware failed at 1,0: Got {res_10}, Expected {expected_C[1,0]}"
    assert res_11 == expected_C[1,1], f"Hardware failed at 1,1: Got {res_11}, Expected {expected_C[1,1]}"
    
    dut._log.info("SUCCESS: Hardware perfectly matches Software Golden Model!")