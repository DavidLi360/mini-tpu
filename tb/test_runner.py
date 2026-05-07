import os
from cocotb_test.simulator import run

def test_tpu():
    # Find the absolute paths to avoid Windows folder slash issues
    tb_dir = os.path.dirname(os.path.abspath(__file__))
    rtl_dir = os.path.abspath(os.path.join(tb_dir, "..", "rtl"))
    
    # Run the simulation
    run(
        verilog_sources=[
            os.path.join(rtl_dir, "mini_tpu.v"),
            os.path.join(rtl_dir, "control_fsm.v"),
            os.path.join(rtl_dir, "bsram.v"),
            os.path.join(rtl_dir, "systolic_2x2.v"),
            os.path.join(rtl_dir, "mac.v")
        ],
        toplevel="mini_tpu",    # name of top-level Verilog module
        module="test_mini_tpu", # name of Cocotb script (test_mini_tpu.py)
        simulator="icarus"     
    )