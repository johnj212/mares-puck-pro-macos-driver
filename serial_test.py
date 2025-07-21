#!/usr/bin/env python3
import serial
import time
import sys

def test_serial():
    try:
        # Open serial port
        ser = serial.Serial('/dev/tty.usbserial-00085C7C', 
                           baudrate=9600, 
                           bytesize=8, 
                           parity='N', 
                           stopbits=1, 
                           timeout=2)
        
        print("Serial port opened successfully")
        print(f"Port: {ser.name}")
        print(f"Baudrate: {ser.baudrate}")
        
        # Try gentle single commands with longer delays
        print("\nSending single gentle wake-up...")
        ser.write(b'\x1B')  # Just ESC
        time.sleep(2)  # Longer wait
        
        if ser.in_waiting > 0:
            response = ser.read(ser.in_waiting)
            print(f"Response to ESC: {response.hex()} ('{response}')")
        else:
            print("No response to ESC")
            
        # Try just reading without sending anything
        print("\nListening for any spontaneous data...")
        time.sleep(3)
        if ser.in_waiting > 0:
            data = ser.read(ser.in_waiting)
            print(f"Spontaneous data: {data.hex()} ('{data}')")
        else:
            print("No spontaneous data")
        
        # Try reading any data
        print("\nWaiting for any incoming data...")
        time.sleep(2)
        if ser.in_waiting > 0:
            data = ser.read(ser.in_waiting)
            print(f"Received data: {data.hex()} ('{data}')")
        else:
            print("No data received")
        
        ser.close()
        print("\nSerial port closed")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_serial()