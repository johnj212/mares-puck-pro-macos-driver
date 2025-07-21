#!/usr/bin/env python3
import subprocess
import time
import serial

def test_preconfigured_port():
    device = '/dev/cu.usbserial-00085C7C'
    
    print("=== Pre-configured Port Test ===")
    
    try:
        # Configure port with stty before Python opens it
        print("Pre-configuring serial port with stty...")
        
        stty_commands = [
            ['stty', '-f', device, '9600'],           # Set baud rate
            ['stty', '-f', device, 'cs8'],            # 8 data bits
            ['stty', '-f', device, '-parenb'],        # No parity
            ['stty', '-f', device, '-cstopb'],        # 1 stop bit
            ['stty', '-f', device, '-crtscts'],       # No hardware flow control
            ['stty', '-f', device, '-cdtr_iflow'],    # No DTR input flow control
            ['stty', '-f', device, '-ccts_oflow'],    # No CTS output flow control
        ]
        
        for cmd in stty_commands:
            try:
                result = subprocess.run(cmd, capture_output=True, text=True)
                if result.returncode == 0:
                    print(f"✓ {' '.join(cmd[2:])}")
                else:
                    print(f"✗ {' '.join(cmd[2:])}: {result.stderr.strip()}")
            except Exception as e:
                print(f"✗ {' '.join(cmd[2:])}: {e}")
        
        print("\nWaiting 2 seconds after configuration...")
        time.sleep(2)
        
        # Now try to open with Python - but don't change any settings
        print("Opening port with minimal Python settings...")
        ser = serial.Serial()
        ser.port = device
        ser.timeout = 2
        # Don't set any other parameters - use what stty configured
        
        ser.open()
        print("Port opened successfully")
        
        # Wait and listen
        print("Listening for 3 seconds without sending anything...")
        time.sleep(3)
        
        if ser.in_waiting > 0:
            data = ser.read(ser.in_waiting)
            print(f"Received data: {data.hex()}")
        else:
            print("No data received")
            
        ser.close()
        print("Port closed")
        
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_preconfigured_port()