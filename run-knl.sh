#!/bin/bash
source ~/.bashrc

#. /home/xiaohui/test/Optimized-Torch/install/bin/torch-activate
#. /home/xiaohui/test/inteltorch-mklmkl/install/bin/torch-activate
. /home/xiaohui/test/inteltorch-mklml/install/bin/torch-activate

KMP_AFFINITY=scatter,granularity=fine OMP_NUM_THREADS=68 th benchmark.lua
