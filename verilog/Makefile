all: build comp run

build:
	verilator -Wall --trace --cc bf1.v --exe bf1.cpp

comp:
	make -C obj_dir -j -f Vbf1.mk Vbf1

run:
	obj_dir/Vbf1 out.bin
