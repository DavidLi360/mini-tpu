import serial
import time
import numpy as np

# --- System Configuration ---
COM_PORT = 'COM5'
BAUD_RATE = 115200
TIMEOUT_SEC = 2.0

# --- Hardware Protocol ---
# Command Opcodes (Host -> FPGA)
OP_LOAD_WEIGHTS = b'\x01'
OP_LOAD_INPUTS  = b'\x02'
OP_EXECUTE      = b'\x03'
OP_READ_OUT     = b'\x04'

# Status Codes (FPGA -> Host)
ACK = b'\xAA'  # Acknowledge / Done
ERR = b'\xEE'  # Hardware Error

def wait_for_ack(ser: serial.Serial, timeout: float = TIMEOUT_SEC) -> bool:
    """
    Polls the UART RX buffer for a hardware acknowledgment.
    Replaces blind 'time.sleep()' calls with deterministic handshaking.
    """
    start_time = time.time()
    while (time.time() - start_time) < timeout:
        if ser.in_waiting > 0:
            response = ser.read(1)
            if response == ACK:
                return True
            elif response == ERR:
                print("⚠️ Hardware reported an internal error state.")
                return False
    print(f"⏳ Timeout: No ACK received from FPGA within {timeout}s.")
    return False

def send_matrix(ser: serial.Serial, opcode: bytes, matrix: np.ndarray, name: str):
    """
    Serializes a NumPy matrix to Little-Endian bytes and transmits via UART.
    """
    print(f"[{name}] Transmitting {matrix.shape} tensor...")
    
    # 1. Send Command
    ser.write(opcode)
    
    # 2. Serialize Data: Force explicit Little-Endian ('<') 8-bit integers 
    # to guarantee correct physical mapping in the FPGA's SRAM.
    flat_data = matrix.flatten().astype('<i1').tobytes()
    ser.write(flat_data)
    
    # 3. Wait for hardware to acknowledge receipt
    # Note: If Verilog UART TX isn't implemented yet, replace this with time.sleep(0.1)
    # wait_for_ack(ser)  
    time.sleep(0.1) 

def main():
    print("Initializing Tang Nano 9K TPU Host Interface...")
    
    # Define verification matrices
    weights = np.array([[2, 0], 
                        [1, 3]])
    
    inputs = np.array([[1, 2], 
                       [4, 1]])
    
    expected_output = np.dot(inputs, weights)

    print("\n--- Golden Model Reference ---")
    print(f"Weights:\n{weights}")
    print(f"Inputs:\n{inputs}")
    print(f"Expected Output:\n{expected_output}\n------------------------------\n")

    # Use a Context Manager to guarantee the COM port releases even if the script crashes
    try:
        with serial.Serial(COM_PORT, BAUD_RATE, timeout=1) as ser:
            time.sleep(1.5)  # Allow FTDI chip to stabilize after opening port
            print(f"✅ UART Link Established: {COM_PORT} @ {BAUD_RATE} baud.\n")

            # --- Hardware Pipeline ---
            send_matrix(ser, OP_LOAD_WEIGHTS, weights, "LOAD_WEIGHTS")
            send_matrix(ser, OP_LOAD_INPUTS, inputs, "LOAD_INPUTS")
            
            print("[EXECUTE_MATMUL] Strobing hardware clock cycles...")
            ser.write(OP_EXECUTE)
            
            # Wait for physical wavefront to propagate through the systolic array
            # wait_for_ack(ser)
            time.sleep(0.5) 
            
            print("[READ_OUT] Fetching systolic array output buffers...")
            ser.write(OP_READ_OUT)
            
            # A 2x2 matrix of 8-bit ints requires exactly 4 bytes
            bytes_expected = 4
            result_bytes = ser.read(bytes_expected) 
            
            if len(result_bytes) == bytes_expected:
                # Reconstruct the matrix using explicit Little-Endian formatting
                hardware_result = np.frombuffer(result_bytes, dtype='<i1').reshape((2, 2))
                print(f"\n[HARDWARE OUTPUT]\n{hardware_result}")
                
                # Hardware vs Software Assertion
                if np.array_equal(hardware_result, expected_output):
                    print("\n✅ VERIFICATION PASSED: Silicon output perfectly matches NumPy.")
                else:
                    print("\n❌ VERIFICATION FAILED: Data mismatch.")
            else:
                print(f"\n⚠️ UART ERROR: Dropped frames. Expected {bytes_expected} bytes, got {len(result_bytes)}.")

    except serial.SerialException as e:
        print(f"❌ OS Lockout: Failed to bind to {COM_PORT}. Is it open in Gowin or another terminal?")
        print(f"Debug: {e}")

if __name__ == "__main__":
    main()