#!/usr/bin/env python3
import serial
import time

def test_exact_mares_protocol():
    try:
        # Open serial port
        ser = serial.Serial('/dev/cu.usbserial-00085C7C', 9600, timeout=5)
        print(f"Connected to {ser.name}")
        
        # Clear buffers
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        
        # Mares IconHD Protocol Constants
        ACK = 0xAA
        END = 0xEA
        XOR = 0xA5
        CMD_VERSION = 0xC2
        
        # Send exact Mares command header: [CMD, CMD^XOR]
        cmd_header = bytes([CMD_VERSION, CMD_VERSION ^ XOR])
        print(f"Sending Mares command header: {cmd_header.hex()} ({CMD_VERSION:02x}, {CMD_VERSION ^ XOR:02x})")
        
        ser.write(cmd_header)
        time.sleep(1)  # Give device time to respond
        
        # Read response
        if ser.in_waiting > 0:
            response = ser.read(ser.in_waiting)
            print(f"Raw response: {response.hex()} (length: {len(response)} bytes)")
            
            # Parse the response according to protocol
            if len(response) > 0:
                print("\nProtocol analysis:")
                for i, byte in enumerate(response):
                    if i == 0 and byte == ACK:
                        print(f"  [{i}]: 0x{byte:02x} - ACK (correct!)")
                    elif i == len(response) - 1 and byte == END:
                        print(f"  [{i}]: 0x{byte:02x} - END (correct!)")
                    else:
                        print(f"  [{i}]: 0x{byte:02x} - Data byte")
                        
                # Check if we have a valid Mares response
                if len(response) >= 2 and response[0] == ACK and response[-1] == END:
                    print("\n✅ Valid Mares IconHD response received!")
                    version_data = response[1:-1]  # Remove ACK and END
                    print(f"Version data: {version_data.hex()}")
                else:
                    print("\n❌ Invalid response format")
        else:
            print("No response received")
            
        ser.close()
        
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_exact_mares_protocol()