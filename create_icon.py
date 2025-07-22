#!/usr/bin/env python3
"""
Simple script to create a diver silhouette icon for Mares Puck Pro app
"""

import os
import subprocess

def create_diver_svg(size):
    """Create a simple diver silhouette SVG"""
    svg_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" width="{size}" height="{size}">
  <!-- Blue background circle -->
  <circle cx="{size//2}" cy="{size//2}" r="{size//2 - 2}" fill="#1B4D84" stroke="none"/>
  
  <!-- Diver silhouette -->
  <g transform="translate({size//2}, {size//2}) scale({size/100})">
    <!-- Head -->
    <circle cx="0" cy="-25" r="8" fill="white"/>
    
    <!-- Body -->
    <rect x="-4" y="-17" width="8" height="20" fill="white"/>
    
    <!-- Arms -->
    <rect x="-12" y="-12" width="8" height="3" fill="white"/>
    <rect x="4" y="-12" width="8" height="3" fill="white"/>
    
    <!-- Legs -->
    <rect x="-6" y="3" width="3" height="15" fill="white"/>
    <rect x="3" y="3" width="3" height="15" fill="white"/>
    
    <!-- Flippers -->
    <ellipse cx="-4.5" cy="22" rx="4" ry="2" fill="white"/>
    <ellipse cx="4.5" cy="22" rx="4" ry="2" fill="white"/>
    
    <!-- Tank on back -->
    <rect x="-2" y="-15" width="4" height="12" fill="white" opacity="0.8"/>
    
    <!-- Bubbles -->
    <circle cx="-15" cy="-30" r="2" fill="white" opacity="0.6"/>
    <circle cx="-18" cy="-35" r="1.5" fill="white" opacity="0.4"/>
    <circle cx="-12" cy="-38" r="1" fill="white" opacity="0.3"/>
  </g>
</svg>'''
    return svg_content

def main():
    # Sizes needed for macOS app icons
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    
    icon_dir = "Mares Puck Pro/Assets.xcassets/AppIcon.appiconset"
    
    # Create SVG icons and convert to PNG if possible
    for size in sizes:
        svg_content = create_diver_svg(size)
        svg_file = f"{icon_dir}/icon_{size}x{size}.svg"
        
        # Write SVG file
        with open(svg_file, 'w') as f:
            f.write(svg_content)
        
        print(f"Created {svg_file}")
        
        # Try to convert to PNG if rsvg-convert is available
        png_file = f"{icon_dir}/icon_{size}x{size}.png"
        try:
            subprocess.run([
                'rsvg-convert', 
                '-w', str(size), 
                '-h', str(size), 
                svg_file, 
                '-o', png_file
            ], check=True, capture_output=True)
            print(f"Converted to {png_file}")
            # Remove SVG after conversion
            os.remove(svg_file)
        except (subprocess.CalledProcessError, FileNotFoundError):
            print(f"Could not convert to PNG (rsvg-convert not available), keeping SVG")
    
    # Create @2x versions (just copies for simplicity)
    if os.path.exists(f"{icon_dir}/icon_16x16.png"):
        for base_size in [16, 32, 128, 256, 512]:
            src_file = f"{icon_dir}/icon_{base_size * 2}x{base_size * 2}.png"
            dst_file = f"{icon_dir}/icon_{base_size}x{base_size}@2x.png"
            if os.path.exists(src_file):
                subprocess.run(['cp', src_file, dst_file])
                print(f"Created @2x version: {dst_file}")

if __name__ == "__main__":
    main()