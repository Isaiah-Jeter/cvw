#!/bin/bash
###########################################
## Tool chain install script.
##
## Written: Ross Thompson ross1728@gmail.com
## Created: 18 January 2023
## Modified: 22 January 2023
## Modified: 23 March 2023
##
## Purpose: Open source tool chain installation script
##
## A component of the CORE-V-WALLY configurable RISC-V project.
##
## Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
##
## SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
## Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file 
## except in compliance with the License, or, at your option, the Apache License version 2.0. You 
## may obtain a copy of the License at
##
## https:##solderpad.org/licenses/SHL-2.1/
##
## Unless required by applicable law or agreed to in writing, any work distributed under the 
## License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
## either express or implied. See the License for the specific language governing permissions 
## and limitations under the License.
################################################################################################

# Use /opt/riscv for installation - may require running script with sudo
export RISCV="${1:-/opt/riscv}"
export PATH=$PATH:$RISCV/bin

set -e # break on error

# Modify accordingly for your machine
# Increasing NUM_THREADS will speed up parallel compilation of the tools
#NUM_THREADS=2 # for low memory machines > 16GiB
NUM_THREADS=8  # for >= 32GiB
#NUM_THREADS=16  # for >= 64GiB

sudo mkdir -p $RISCV

# Update and Upgrade tools (see https://itsfoss.com/apt-update-vs-upgrade/)
apt update -y
apt upgrade -y
apt install -y git gawk make texinfo bison flex build-essential python3 libz-dev libexpat-dev autoconf device-tree-compiler ninja-build libpixman-1-dev ncurses-base ncurses-bin libncurses5-dev dialog curl wget ftp libgmp-dev libglib2.0-dev python3-pip pkg-config opam z3 zlib1g-dev verilator

# Other python libraries used through the book.
pip3 install matplotlib scipy scikit-learn adjustText lief

# needed for Ubuntu 22.04, gcc cross compiler expects python not python2 or python3.
if ! command -v python &> /dev/null
then
    echo "WARNING: python3 was installed as python3 rather than python. Creating symlink."
    ln -sf /usr/bin/python3 /usr/bin/python
fi

# gcc cross-compiler (https://github.com/riscv-collab/riscv-gnu-toolchain)
# To install GCC from source can take hours to compile. 
#This configuration enables multilib to target many flavors of RISC-V.   
# This book is tested with GCC 12.2 (tagged 2023.01.31), but will likely work with newer versions as well. 
# Note that GCC12.2 has binutils 2.39, which has a known performance bug that causes
# objdump to run 100x slower than in previous versions, causing riscof to make versy slowly.
# However GCC12.x is needed for bit manipulation instructions.  There is an open issue to fix this:
# https://github.com/riscv-collab/riscv-gnu-toolchain/issues/1188

cd $RISCV
git clone https://github.com/riscv/riscv-gnu-toolchain
cd riscv-gnu-toolchain
git checkout 2023.01.31 
./configure --prefix=${RISCV} --with-multilib-generator="rv32e-ilp32e--;rv32i-ilp32--;rv32im-ilp32--;rv32iac-ilp32--;rv32imac-ilp32--;rv32imafc-ilp32f--;rv32imafdc-ilp32d--;rv64i-lp64--;rv64ic-lp64--;rv64iac-lp64--;rv64imac-lp64--;rv64imafdc-lp64d--;rv64im-lp64--;"
make -j ${NUM_THREADS}
make install

# elf2hex (https://github.com/sifive/elf2hex)
#The elf2hex utility to converts executable files into hexadecimal files for Verilog simulation. 
# Note: The exe2hex utility that comes with Spike doesn’t work for our purposes because it doesn’t 
# handle programs that start at 0x80000000. The SiFive version above is touchy to install. 
# For example, if Python version 2.x is in your path, it won’t install correctly. 
# Also, be sure riscv64-unknown-elf-objcopy shows up in your path in $RISCV/riscv-gnu-toolchain/bin 
# at the time of compilation, or elf2hex won’t work properly.
cd $RISCV
export PATH=$RISCV/bin:$PATH
git clone https://github.com/sifive/elf2hex.git
cd elf2hex
autoreconf -i
./configure --target=riscv64-unknown-elf --prefix=$RISCV
make
make install


# QEMU (https://www.qemu.org/docs/master/system/target-riscv.html)
cd $RISCV
git clone --recurse-submodules https://github.com/qemu/qemu
cd qemu
./configure --target-list=riscv64-softmmu --prefix=$RISCV 
make -j ${NUM_THREADS}
make install

# Spike (https://github.com/riscv-software-src/riscv-isa-sim)
# Spike also takes a while to install and compile, but this can be done concurrently 
#with the GCC installation. After the build, we need to change two Makefiles to support atomic instructions.
cd $RISCV
git clone https://github.com/riscv-software-src/riscv-isa-sim
mkdir -p riscv-isa-sim/build
cd riscv-isa-sim/build
../configure --prefix=$RISCV 
make -j ${NUM_THREADS}
make install 
cd ../arch_test_target/spike/device
sed -i 's/--isa=rv32ic/--isa=rv32iac/' rv32i_m/privilege/Makefile.include
sed -i 's/--isa=rv64ic/--isa=rv64iac/' rv64i_m/privilege/Makefile.include

# Sail (https://github.com/riscv/sail-riscv)
# Sail is the new golden reference model for RISC-V.  Sail is written in OCaml, which 
# is an object-oriented extension of ML, which in turn is a functional programming 
# language suited to formal verification.  OCaml is installed with the opam OCcaml 
# package manager. Sail has so many dependencies that it can be difficult to install.
# This script works for Ubuntu.

# Do these commands only for RedHat / Rocky 8 to build from source.
#cd $RISCV
#git clone https://github.com/Z3Prover/z3.git
#cd z3
#python scripts/mk_make.py
#cd build
#make  -j ${NUM_THREADS}
#make install
#cd ../..
#pip3 install chardet==3.0.4
#pip3 install urllib3==1.22

opam init -y --disable-sandboxing
opam switch create ocaml-base-compiler.4.06.1
opam install sail -y 

eval $(opam config env)
git clone https://github.com/riscv/sail-riscv.git
cd sail-riscv
# Current bug in Sail - use hash that works for Wally
#   (may remove later if Sail is ever fixed)
git checkout 4d05aa1698a0003a4f6f99e1380c743711c32052
make -j ${NUM_THREADS}
ARCH=RV32 make -j ${NUM_THREADS}
ARCH=RV64 make -j ${NUM_THREADS}
ln -sf $RISCV/sail-riscv/c_emulator/riscv_sim_RV64 /usr/bin/riscv_sim_RV64
ln -sf $RISCV/sail-riscv/c_emulator/riscv_sim_RV32 /usr/bin/riscv_sim_RV32

pip3 install testresources
pip3 install riscof --ignore-installed PyYAML
