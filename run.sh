#!/bin/bash
source ~/.bashrc

#. /home/xiaohui/test/Optimized-Torch/install/bin/torch-activate
. /home/xiaohui/test/inteltorch-mklml/install/bin/torch-activate

OMP_NUM_THREADS=44 th benchmark.lua
