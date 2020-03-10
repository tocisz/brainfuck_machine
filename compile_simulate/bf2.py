#!/usr/bin/python
import sys
import collections

def brainfuck (fd=None):
    max_val = 0
    fd = fd or (open(sys.argv[1], 'rb') if sys.argv[1:] else sys.stdin)
    tape_length = int(sys.argv[2]) if sys.argv[2:] else 600
    source = fd.read()
    tape = tape_length * [0]
    ret = []
    cell = 0
    ptr = -1
    while ptr+1 < len(source):
        ptr += 1
        op = source[ptr]
        instr = op >> 6
        if instr == 0: # <>
            if op & 0b00100000: # <
                cell -= (op & 0b11111) + 1
            else:
                cell += (op & 0b11111) + 1
        elif instr == 1: # -+
            if op & 0b00100000: # -
                tape[cell] -= (op & 0b11111) + 1
            else:
                tape[cell] += (op & 0b11111) + 1
        elif instr == 2: # []
            offset = op & 0b111111
            if offset == 0: # ]
                if tape[cell]:
                    ptr = ret[-1]
                else:
                    ret.pop()
            else:
                if offset & 0b100000: # long jump
                    ptr += 1
                    low = source[ptr]
                    high = offset & 0b11111
                    offset = (high << 8) | low
                if not tape[cell]:
                    ptr += offset
                else:
                    ret.append(ptr)
        else: # ,.
            if op & 0b00100000: # .
                sys.stdout.write(chr(tape[cell]))
                sys.stdout.flush()
            else:
                tape[cell] = ord(sys.stdin.read(1))
        # if tape[cell] > max_val:
        #     max_val = tape[cell]
        #     print(f"MAX: {max_val}")
        if cell < 0:
            raise Exception("hit left boundary")
        # print()
        # print(ptr, cell)
        # print(tape)

if __name__ == "__main__": brainfuck()
