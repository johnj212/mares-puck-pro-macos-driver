#!/usr/bin/env python3
import serial
import time

try:
    # Very basic serial connection
    ser = serial.Serial('/dev/cu.usbserial-00085C7C', 9600, timeout=2)
    print(f"Connected to {ser.name}")
    
    # Send Mares VERSION command instead of random data
    print("Sending Mares CMD_VERSION (0xC2)...")
    ser.write(b'\xC2')
    time.sleep(1)
    
    if ser.in_waiting > 0:
        response = ser.read(ser.in_waiting)
        print(f"Got response: {response.hex()} ('{response}')")
    else:
        print("No response")
    
    ser.close()
    
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()