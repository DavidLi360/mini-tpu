# Mini TPU Accelerator

![Status](https://img.shields.io/badge/Status-Cocotb_Verified-success)
![Board](https://img.shields.io/badge/Board-Sipeed_Tang_Nano_9K-blue)

<img width="3072" height="4096" alt="pc and fpga" src="https://github.com/user-attachments/assets/f3db03a6-b6fe-4645-8a24-ceef468db0e3" />

This repository contains the physical implementation of a custom Tensor Processing Unit (TPU) and matrix multiplication accelerator, designed from scratch for the Sipeed Tang Nano 9K FPGA. 

[![Mini-TPU Hardware Demo](https://img.youtube.com/vi/yrxMmgOofpQ/maxresdefault.jpg)](https://youtu.be/yrxMmgOofpQ)

---

### Motivation

As an electrical engineering student, I noticed a massive gap between studying digital logic in a textbook and actually getting a custom accelerator to run on physical silicon. The semiconductor industry is largely closed-source, so I built this Mini-TPU from scratch to understand on how these architectures work 'under the hood'.

While my academic coursework gave me the theoretical foundation, I took on this project to dive headfirst into real-world semiconductor design and hardware verification. Building this was much more than just writing Verilog and passing Cocotb software simulations against a NumPy golden reference. I basically learned the hard way how unforgiving the hardware stuff is, forcing me to navigate problems that would not exist in a simulation based testing environment.

## Architecture 

The fundamental hardware relies on highly parallelized matrix multiplication. This project implements a custom systolic array designed specifically to fit within the logic gate constraints of the Tang Nano 9K.

### The Processing Element (PE)
At the core of the accelerator is the Processing Element. Unlike a general-purpose CPU core that handles branching logic and memory management, a PE is highly specialized to do exactly one hardware operation: Multiply-Accumulate (MAC). 

* **The Operation:** `Output = (Input × Weight) + Partial_Sum`
* **Execution:** Each PE computes its local MAC operation in a single clock cycle and passes the resulting partial sum down to the adjacent PE in the next clock cycle.

### The Systolic Array
To achieve massive parallelism, the individual PEs are tiled into a grid known as a Systolic Array. 

* **Weight Stationary Architecture:** Before a calculation begins, the target matrix weights are pre-loaded and locked into the local PE registers. 
* **Wavefront Data Flow:** Input data (matrices) flows horizontally across the array, while the calculated partial sums flow vertically. This continuous "pumping" of data through the physical hardware grid allows the FPGA to calculate an entire matrix dot-product without needing to constantly read and write to standard memory (SRAM). 

### Instruction Set & Control
This TPU operates as a coprocessor. It does not fetch its own code; it waits for the host machine (via Python serial communication) to send it specific byte-encoded instructions. 

A standard matrix execution pipeline follows this sequence:
1. `LOAD_WEIGHTS`: Streams the static matrix weights into the PE grid.
2. `LOAD_INPUTS`: Streams the target input vectors into the hardware data buffers.
3. `EXECUTE_MATMUL`: Triggers the PE clock cycles, pumping the data through the systolic array.
4. `READ_OUT`: Fetches the final accumulated matrix from the output buffer back over the serial bus to the host.


## Hardware Execution 

Translating simulated logic gates into physical voltage on a cheap FPGA introduces many different engineering problems. 

### The Toolchain

I skipped the Gowin Programmer. It masked underlying hardware errors. We are using a strictly open-source, explicit toolchain.

1. **The Flasher:** I used `openFPGALoader`, specifically the pre-compiled version bundled inside the **YosysHQ OSS CAD Suite**. 
2. **The Driver:** You must use the standard `WinUSB` driver. Use Zadig to replace the factory FTDI driver on `Interface 0` (usually labeled "JTAG Debugger" or "USB Serial Converter A") with `WinUSB`.
3. **The Command:** Open the OSS CAD Suite terminal and execute the physical flash:
   ```bash
   openFPGALoader -b tangnano9k <path_to_file>.fs

### Hardware Troubleshooting

Getting dense matrix multiplication logic to successfully flash onto cheap silicon is rarely a clean process. Some of the roadblocks I've encountered whilst implementing on hardware include:
* Error -1 (usb bulk write failed): This is a physical power issue, rather than a software bug. When you try to flash the SRAM, the board draws a massive power spike. If you are using a cheap USB-C cable like I was, windows severs the connection mid-flash. I fixed this problem by using a more high quality data cable (like a laptop/phone charger)

<img width="4096" height="3072" alt="cable img" src="https://github.com/user-attachments/assets/3e58b403-54ae-4a49-846b-6a2b4bebe5f1" />

*I used the black cable at first, and when I swapped to the white cable, the problem fixed itself.*


* **The Pin Lockout: Error -6 (ftdi_usb_reset failed):** If your Tang Nano has an old bitstream already on it, that design boots up the second you plug the board in. If that old design is actively driving the JTAG pins or drawing heavy power, it fights the USB cable when you try to flash the new design, causing `openFPGALoader` to panic and fail the reset handshake. I got around this by forcing the FPGA to stay asleep during power-up. Just unplug the board, hold down both the **S1** and **S2** buttons, and plug it back in while holding them down. The JTAG pins will remain open and silent.

* **Windows Driver Conflicts:** When dealing with clone FTDI chips on modern Windows builds, driver selection is an absolute minefield. I found out the hard way that using `libusbK` or `libusb-win32` will just cause USB deadlocks or throw `-6` errors with the Tang Nano's emulator chip, even though those drivers are robust for other microcontrollers. To fix this, stick strictly to the **`WinUSB`** driver via Zadig.

## Simulation & Testing (The "Verification")

Hardware is incredibly unforgiving. Before I even thought about touching physical JTAG pins or fighting with USB drivers, I had to prove the logic gates actually worked in software. If the math is wrong in the simulation, it is going to be wrong on the silicon. 

### The Python/Cocotb Testbench

Traditional Verilog testbenches are notoriously tedious when you are dealing with complex tensor math. Instead, I used Cocotb. This framework allowed me to write my hardware testbenches entirely in Python, bridging high-level software abstractions with low-level RTL.

* **The Golden Reference:** I used standard Python `NumPy` arrays to calculate the exact, correct matrix multiplication results. This served as my undisputed "golden reference."
* **The Hardware Execution:** The Cocotb script injects those same input matrices into the simulated Verilog design, drives the clock cycles, and reads the final accumulated output back out of the buffers.
* **The Verification:** The script asserts that the Verilog output perfectly matches the NumPy output. If it passes, the logic is sound.

### Viewing Waveforms (GTKWave)

When a hardware test fails, you cannot just `print()` a variable to the console to see what went wrong. You have to look at the physical timing of the simulated electrical signals. 

* **The VCD Dump:** During the Cocotb simulation, the toolchain dumps a `.vcd` (Value Change Dump) file. This file records the state of every single wire, register, and bus in the TPU at every simulated nanosecond.
* **GTKWave:** I use GTKWave (which is conveniently bundled in the YosysHQ OSS CAD Suite alongside our flasher tool) to open these `.vcd` files. This allows me to visually inspect the clock cycles, trace the data wavefront pumping through the systolic array, and pinpoint exactly which Processing Element stalled or dropped a bit.

## Future Steps & Roadmap

Getting the systolic array pumping data and returning verified matrix multiplication on physical silicon was the primary goal of this V1 build. Now that the hardware pipeline and the USB/JTAG toolchain are completely rock-solid, the next phase is scaling the architecture from a basic math coprocessor into a true neural accelerator.

Here is what is next on the development roadmap:

* **BRAM Routing & Matrix Scaling:** The Tang Nano 9K has a strict logic gate limit, which currently bottlenecks the maximum matrix dimensions I can compile without causing massive routing congestion. The next architectural revision will focus heavily on migrating the matrix weight registers and input buffers away from distributed logic and explicitly mapping them into the FPGA's dedicated Block RAM (BRAM).
* **Silicon Profiling:** I plan to implement hardware counters directly in the Verilog to measure clock cycles, operational latency, and exact throughput to benchmark the FPGA's performance against running the exact same tensor math natively on the host CPU.
