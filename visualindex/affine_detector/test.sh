#!/bin/bash

# run detector
./mac_bin/detect_points -i oxford_002336.jpg -hesaff -o det.txt

# run descriptor
./mac_bin/compute_descriptors -i oxford_002336.jpg -p1 det.txt -sift -o3 desc.txt -scale-mult 1.732
