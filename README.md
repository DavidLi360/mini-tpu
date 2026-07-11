# Mini TPU Accelerator

![Status](https://img.shields.io/badge/Status-Cocotb_Verified-success)
![Board](https://img.shields.io/badge/Board-Sipeed_Tang_Nano_9K-blue)

<p align="center">
  <img width="400" alt="pc and fpga" src="https://github.com/user-attachments/assets/f3db03a6-b6fe-4645-8a24-ceef468db0e3" />
</p>

This repo holds a custom Tensor Processing Unit (TPU) core. It's a small systolic-array matrix multiplier that I designed from scratch, verified against a NumPy golden model, and actually synthesized and flashed onto a Sipeed Tang Nano 9K FPGA.

[![Mini-TPU Hardware Demo](https://img.youtube.com/vi/yrxMmgOofpQ/maxresdefault.jpg)](https://youtu.be/yrxMmgOofpQ)

---

### Motivation

As an EE student, I noticed a huge gap between studying digital logic in class and actually getting a custom accelerator running on physical silicon. The semiconductor industry is pretty closed off, so I decided to build this Mini-TPU from scratch to see how these architectures actually work under the hood.

While my classes gave me the theory, I took this project on to get hands-on with real hardware verification. I wanted to write a systolic array, prove the math works, and then fight through the painful process of getting it to run on a cheap FPGA instead of just passing in a simulator.

## Architecture

### The Processing Element (PE)
At the core of the accelerator is the Processing Element (`mac.v`). Unlike a normal CPU core that deals with branching and memory, a PE is specialized to do exactly one thing: Multiply-Accumulate (MAC).

* **The Operation:** `result <= result + (a * b)`, computed every cycle `en` is asserted.
* Four of these are instantiated to form the 2x2 array.

### The Systolic Array (`systolic_2x2.v`)
The four PEs are wired into a 2x2 grid where each one is fixed in place and accumulates a single output element (`result_00` to `result_11`). This makes it closer to an **output-stationary** array than a weight-stationary one. Both the input matrix (`A`, coming from the left) and the weight matrix (`B`, coming from the top) stream in together. They are skewed by one clock cycle per row so each PE gets the right operands on the right cycle:

* PE(0,0) operates directly on the incoming edge values.
* PE(0,1) and PE(1,0) each grab one delayed operand (`a_delay_00`, `b_delay_00`) so they line up with the diagonal wavefront.
* PE(1,1) needs two delayed operands (`a_delay_10`, `b_delay_01`).

I verified this timing by hand using the skewed row-packing scheme from the testbenches, and then confirmed it in simulation. Feeding `A=[[1,2],[3,4]]` against an identity matrix spits out `[[1,2],[3,4]]` unchanged, and randomized 2x2 inputs are automatically checked against NumPy (more on that in Verification).

### Control & Memory
`control_fsm.v` is a basic 3-state FSM (`IDLE -> COMPUTE -> DONE`). It walks a step counter from 0 to 6 on `start`, sequences reads out of a small block-RAM (`bsram.v`), and drives the systolic array's enable window. This ensures the pre-packed, skewed rows hit the array at the exact right cycle, and then holds the array enabled for a few extra cycles to flush the pipeline before firing the `done` signal.

## Current State: What's Verified vs. What's Planned

This project currently has two separate pieces of proof, and I want to be super clear about what each one does:

1. **The compute core is functionally correct.** It is verified two different ways, including against randomized inputs.
2. **The compute core synthesizes and runs on real Tang Nano 9K silicon.** Check the hardware bring-up section below for that journey.

**What is *not* built yet:** A way to load arbitrary matrices into the chip from my PC while it is running on the board. Right now, matrix data only gets into `bsram.v` through direct simulation injection (`$readmemh` in the Verilog testbench or a direct register poke from Cocotb). There is no UART or host-facing interface in the RTL just yet. `tpu_host.py` outlines the serial protocol (`LOAD_WEIGHTS` / `LOAD_INPUTS` / `EXECUTE_MATMUL` / `READ_OUT`) that a future UART bridge will use, but `mini_tpu.v` does not listen for it yet. That is the next big milestone.

Another honest caveat is that the current `mini_tpu.v` top level (the one the testbenches use) ties the write data input of `bsram` to a constant `0` since nothing drives it yet. A smart synthesis tool will notice that and optimize the entire compute path down to a constant zero. That is exactly the failure mode I hit during hardware bring-up! The version of the design I actually flashed to prove BRAM inference used a throwaway 1-bit `dummy_in` input. I replicated this across the data bus just to give the synthesizer something unpredictable to keep around. That synthesis-only trick and the verification-only top level in this repo still need to be merged into one canonical top module.

## Simulation & Verification

Hardware is super unforgiving, so before I even touched the physical JTAG pins, I had to prove the logic gates actually worked in software.

* **Per-module testbenches:** Standard Verilog/Icarus testbenches to exercise each block in isolation (`mac_tb.v`, `bsram_tb.v`, etc.).
* **Full-integration testbench:** `mini_tpu_tb.v` loads a fixed matrix pair via `$readmemh`, runs the whole pipeline, and prints the final matrix.
* **Randomized golden-model regression:** Powered by Cocotb and `test_mini_tpu.py`. This generates a fresh random 2x2 input pair every run, calculates the expected result with NumPy, drives the DUT, and asserts that the hardware output matches perfectly. I ran this on a loop with different random seeds to make sure it wasn't just passing a lucky fixed case.
* **Waveform debugging:** Icarus dumps a `.vcd` file for each testbench. I used GTKWave (from the YosysHQ OSS CAD Suite) to trace the skewed data wavefront cycle-by-cycle whenever I ran into timing bugs.

## Hardware Bring-Up

Translating simulated logic into physical voltages on cheap FPGA silicon brought up a ton of problems that just do not exist in a simulator.

### The Toolchain

I skipped the official Gowin Programmer because it masked underlying hardware errors. Instead, I used a strictly open-source toolchain.

1. **The Flasher:** `openFPGALoader`, specifically the pre-compiled version bundled inside the **YosysHQ OSS CAD Suite**.
2. **The Driver:** The standard `WinUSB` driver via Zadig, replacing the factory FTDI driver on `Interface 0` ("JTAG Debugger" / "USB Serial Converter A").
3. **The Command:**
```bash
   openFPGALoader -b tangnano9k <path_to_file>.fs
```

### Troubleshooting Log

* **Error -1 (usb bulk write failed):** This was actually a physical power issue, not a software bug. Flashing SRAM draws a big power spike, and my cheap USB-C cable let Windows drop the connection mid-flash. Swapping to a higher-quality data cable fixed it instantly.

  <p align="center">
  <img width="600" alt="cable img" src="https://github.com/user-attachments/assets/3e58b403-54ae-4a49-846b-6a2b4bebe5f1" />
  <br>
  <em>Swapping from the black cable to the white cable fixed it.</em>
</p>

  *Swapping from the black cable to the white cable fixed it.*

* **Error -6 (ftdi_usb_reset failed) and the pin lockout:** If the board already has an old bitstream on it, that design boots the second it gets power and can fight the JTAG pins during a new flash. The fix was to hold **S1** and **S2** while plugging the board in, keeping it in reset so the JTAG pins stay open.

* **Windows driver conflicts:** Drivers like `libusbK` and `libusb-win32` caused USB deadlocks or `-6` errors against the Tang Nano's FTDI clone chip, even though they usually work great for other microcontrollers. Forcing it to strictly use `WinUSB` via Zadig solved the headache.

* **BRAM getting optimized away:** Since no real external input was driving the memory, the synthesis tool had no reason to keep the block RAM and kept collapsing it into constants. I bypassed this during bring-up with a disposable 1-bit input replicated across the write-data bus, which gave the synthesizer something unpredictable to preserve. It was a neat synthesis trick, but as I mentioned earlier, it is not part of the verified top level in this repo yet.

## Roadmap

* **UART host interface:** wire up the RX/TX logic so `tpu_host.py`'s protocol actually reaches the chip.
* **Reconcile the two top levels:** merge the verification top and the synthesis-safe (forced BRAM inference) top into one canonical `mini_tpu.v`.
* **BRAM routing & matrix scaling:** The Tang Nano 9K's logic gate limit is currently the bottleneck before routing congestion even becomes a problem. Moving weight and input buffers explicitly into dedicated Block RAM instead of distributed logic is the next architectural step to scale this past 2x2.
* **Silicon profiling:** I want to add hardware cycle counters to benchmark the real FPGA throughput and latency against the same matrix math running natively on a host CPU.
