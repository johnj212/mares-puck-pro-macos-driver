#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libdivecomputer/context.h>
#include <libdivecomputer/serial.h>
#include <libdivecomputer/device.h>
#include <libdivecomputer/mares_iconhd.h>

int main() {
    dc_context_t *context = NULL;
    dc_iostream_t *iostream = NULL;
    dc_device_t *device = NULL;
    dc_status_t rc;
    
    printf("Testing Mares Puck Pro communication...\n");
    
    // Create context
    rc = dc_context_new(&context);
    if (rc != DC_STATUS_SUCCESS) {
        printf("Failed to create context: %d\n", rc);
        return 1;
    }
    
    printf("Created context successfully\n");
    
    // Open serial port
    rc = dc_serial_open(&iostream, context, "/dev/cu.usbserial-00085C7C");
    if (rc != DC_STATUS_SUCCESS) {
        printf("Failed to open serial port: %d\n", rc);
        dc_context_free(context);
        return 1;
    }
    
    printf("Opened serial port successfully\n");
    
    // Try to open device with Puck Pro model (0x18)
    rc = mares_iconhd_device_open(&device, context, iostream, 0x18);
    if (rc != DC_STATUS_SUCCESS) {
        printf("Failed to open Mares IconHD device with model 0x18: %d\n", rc);
        
        // Try with default model (0x14)
        rc = mares_iconhd_device_open(&device, context, iostream, 0x14);
        if (rc != DC_STATUS_SUCCESS) {
            printf("Failed to open Mares IconHD device with model 0x14: %d\n", rc);
        } else {
            printf("Successfully opened device with model 0x14!\n");
        }
    } else {
        printf("Successfully opened device with model 0x18!\n");
    }
    
    // Cleanup
    if (device) {
        dc_device_close(device);
    }
    if (iostream) {
        dc_iostream_close(iostream);
    }
    if (context) {
        dc_context_free(context);
    }
    
    return 0;
}