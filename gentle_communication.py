#!/usr/bin/env python3
import serial
import time
import subprocess

def test_gentle_communication():
    device = '/dev/cu.usbserial-00085C7C'
    
    print("=== Gentle Communication Test ===")
    
    try:
        # Method 1: Very minimal approach
        print("\n--- Test 1: Minimal serial setup ---")
        ser = serial.Serial(device, 9600, timeout=1)
        print("Port opened")
        
        # Just listen for any data without sending anything
        print("Listening for any spontaneous data (5 seconds)...")
        time.sleep(5)
        
        if ser.in_waiting > 0:
            data = ser.read(ser.in_waiting)
            print(f"Spontaneous data: {data.hex()}")
        else:
            print("No spontaneous data")
            
        ser.close()
        print("Port closed cleanly")
        
        # Wait between tests
        time.sleep(2)
        
        # Method 2: Send single byte very gently
        print("\n--- Test 2: Single gentle byte ---")
        ser = serial.Serial(device, 9600, timeout=2)
        
        # Send just one byte and wait
        print("Sending single 0xC2 byte...")
        ser.write(b'\xC2')
        time.sleep(3)  # Longer wait
        
        if ser.in_waiting > 0:
            response = ser.read(ser.in_waiting)
            print(f"Response: {response.hex()}")
        else:
            print("No response")
            
        ser.close()
        print("Test 2 completed")
        
        # Wait between tests
        time.sleep(2)
        
        # Method 3: Try with different baud rate
        print("\n--- Test 3: Different baud rate (4800) ---")
        ser = serial.Serial(device, 4800, timeout=2)
        
        print("Sending 0xC2 at 4800 baud...")
        ser.write(b'\xC2')
        time.sleep(2)
        
        if ser.in_waiting > 0:
            response = ser.read(ser.in_waiting)
            print(f"Response at 4800: {response.hex()}")
        else:
            print("No response at 4800")
            
        ser.close()
        print("Test 3 completed")
        
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_gentle_communication()