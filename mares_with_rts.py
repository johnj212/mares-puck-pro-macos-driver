#!/usr/bin/env python3
import serial
import time
import subprocess
import os

def test_mares_with_rts():
    device = '/dev/cu.usbserial-00085C7C'
    
    try:
        print("Setting up serial port with RTS control...")
        
        # Method 1: Try to control RTS via stty (may not work on macOS)
        try:
            subprocess.run(['stty', '-f', device, '-crtscts'], check=True)
            print("Disabled RTS/CTS flow control")
        except subprocess.CalledProcessError:
            print("Could not control RTS via stty")
        
        # Method 2: Open serial port with specific settings
        ser = serial.Serial()
        ser.port = device
        ser.baudrate = 9600
        ser.bytesize = 8
        ser.parity = 'N'
        ser.stopbits = 1
        ser.timeout = 5
        ser.rtscts = False  # Disable hardware flow control
        ser.dsrdtr = False  # Disable DTR/DSR flow control
        
        ser.open()
        print(f"Serial port opened: {ser.name}")
        
        # Critical: Set RTS to False (clear RTS line) like libdivecomputer does
        print("Clearing RTS line (set to False)...")
        ser.rts = False
        ser.dtr = False  # Also clear DTR
        time.sleep(0.5)  # Allow line to stabilize
        
        # Clear buffers after RTS control
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        print("Buffers cleared")
        
        # Now send the Mares protocol
        ACK = 0xAA
        END = 0xEA
        XOR = 0xA5
        CMD_VERSION = 0xC2
        
        cmd_header = bytes([CMD_VERSION, CMD_VERSION ^ XOR])
        print(f"Sending Mares CMD_VERSION: {cmd_header.hex()}")
        
        ser.write(cmd_header)
        time.sleep(2)  # Longer wait
        
        # Check for response
        if ser.in_waiting > 0:
            response = ser.read(ser.in_waiting)
            print(f"Response: {response.hex()} (length: {len(response)})")
            
            # Analyze response
            if len(response) >= 2 and response[0] == ACK and response[-1] == END:
                print("✅ Valid Mares response!")
                print(f"Version data: {response[1:-1].hex()}")
            else:
                print(f"Response analysis:")
                # Show each byte
                for i, byte in enumerate(response):
                    if byte == ACK:
                        print(f"  [{i}]: 0x{byte:02x} - ACK!")
                    elif byte == END:
                        print(f"  [{i}]: 0x{byte:02x} - END!")
                    else:
                        print(f"  [{i}]: 0x{byte:02x} - Unknown")
                
                # Maybe we need to wait for more data?
                print("\nWaiting for more data...")
                time.sleep(2)
                if ser.in_waiting > 0:
                    more_data = ser.read(ser.in_waiting)
                    print(f"Additional data: {more_data.hex()}")
                else:
                    print("No additional data")
        else:
            print("No response")
            
        ser.close()
        
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_mares_with_rts()