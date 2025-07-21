#!/usr/bin/env python3
import serial
import time
import sys

def test_mares_protocol():
    try:
        # Open serial port with proper settings for Mares
        ser = serial.Serial('/dev/tty.usbserial-00085C7C', 
                           baudrate=9600, 
                           bytesize=8, 
                           parity='N', 
                           stopbits=1, 
                           timeout=5)
        
        print("Serial port opened successfully")
        print(f"Port: {ser.name}")
        
        # CRITICAL: Clear RTS line (this is what libdivecomputer does first)
        print("Clearing RTS line...")
        try:
            ser.rts = False  # Clear RTS (set to 0)
            print("RTS cleared successfully")
        except Exception as e:
            print(f"Could not control RTS: {e}")
        time.sleep(0.5)
        
        # Purge buffers
        print("Purging buffers...")
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        time.sleep(0.5)
        
        # Send Mares CMD_VERSION command (0xC2)
        print("Sending Mares CMD_VERSION (0xC2)...")
        ser.write(b'\xC2')
        time.sleep(2)
        
        # Check for response
        if ser.in_waiting > 0:
            response = ser.read(ser.in_waiting)
            print(f"Response to CMD_VERSION: {response.hex()} (length: {len(response)})")
            
            # Decode the response if possible
            if len(response) > 0:
                print("Response bytes:")
                for i, byte in enumerate(response):
                    print(f"  [{i}]: 0x{byte:02x} ({byte})")
        else:
            print("No response to CMD_VERSION")
        
        # Try with DTR control as well
        print("\nTrying with DTR control...")
        ser.dtr = False
        time.sleep(0.5)
        ser.write(b'\xC2')
        time.sleep(2)
        
        if ser.in_waiting > 0:
            response = ser.read(ser.in_waiting)
            print(f"Response with DTR: {response.hex()}")
        else:
            print("No response with DTR")
        
        ser.close()
        print("\nSerial port closed")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_mares_protocol()