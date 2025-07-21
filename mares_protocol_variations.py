#!/usr/bin/env python3
import serial
import time

def test_mares_variations():
    device = '/dev/cu.usbserial-00085C7C'
    
    try:
        # Set up serial port with RTS control
        ser = serial.Serial()
        ser.port = device
        ser.baudrate = 9600
        ser.timeout = 3
        ser.rtscts = False
        ser.dsrdtr = False
        ser.open()
        
        # Clear RTS and DTR
        ser.rts = False
        ser.dtr = False
        time.sleep(0.5)
        
        # Clear buffers
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        
        # Test different command variations
        ACK = 0xAA
        END = 0xEA
        XOR = 0xA5
        
        test_commands = [
            ("CMD_VERSION standard", [0xC2, 0xC2 ^ XOR]),
            ("CMD_VERSION inverted", [0xC2 ^ XOR, 0xC2]),
            ("Just CMD_VERSION", [0xC2]),
            ("Wake up + CMD_VERSION", [0x1B, 0xC2, 0xC2 ^ XOR]),
            ("Different Mares wake", [0x55, 0xAA, 0xC2, 0xC2 ^ XOR]),
            ("IconHD specific", [0x10, 0x10, 0xC2, 0xC2 ^ XOR]),
        ]
        
        for name, cmd_bytes in test_commands:
            print(f"\n--- Testing {name} ---")
            print(f"Sending: {bytes(cmd_bytes).hex()}")
            
            # Clear buffers before each test
            ser.reset_input_buffer()
            ser.reset_output_buffer()
            
            # Send command
            ser.write(bytes(cmd_bytes))
            time.sleep(1.5)
            
            # Read response
            if ser.in_waiting > 0:
                response = ser.read(ser.in_waiting)
                print(f"Response: {response.hex()} ({len(response)} bytes)")
                
                # Check for valid Mares protocol
                if len(response) >= 2 and response[0] == ACK and response[-1] == END:
                    print("✅ VALID MARES RESPONSE!")
                    print(f"Data: {response[1:-1].hex()}")
                    break  # Found working command
                elif response == b'\x8f\x02':
                    print("Got error response 8f02")
                else:
                    print("Unknown response format")
            else:
                print("No response")
                
            time.sleep(0.5)  # Brief pause between tests
        
        ser.close()
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_mares_variations()