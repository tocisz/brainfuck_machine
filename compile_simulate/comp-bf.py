#!/usr/bin/python
import sys
import pprint

out_bin = bytearray()
NEUTRAL = ['[',']',',','.']
NEGATIVE = ['<','-']
POSITIVE = ['>','+']
OPS = NEUTRAL + NEGATIVE + POSITIVE

# 10000000 is end of loop
# 10000001 to 10011111 is short jump
# 10100000 to 10111111 (plus next byte) is long jump

class Node:
    def __init__(self, l, r):
        assert l < r
        self.l = l
        self.r = r
        self.child = []

    def insert(self, n):
        assert n.l > self.l and n.r < self.r
        if not self.child:
            self.child.append(n)
            return
        # print("Trying to place",n.repr())
        # We want to find:
        #  li s.t. n.l goes into child[li] or just after it (-1 when not found)
        #  ri s.t. n.r goes into child[ri] or just before it (len when not found)
        # If li=ri n goes into child[li=ri]
        # If ri = li+1 n goes in between of them
        # Otherwise all child[li+1]..child[ri-1] go into n
        li = None
        x = n.l
        # print("finding li")
        if x < self.child[0].l:
            li = -1
        else:
            li = len(self.child)-1
            for j,e in reversed(list(enumerate(self.child))):
                # print(j,e.l,x)
                if x > e.l:
                    # print("break")
                    li = j
                    break

        ri = None
        x = n.r
        # print("finding ri")
        if x > self.child[-1].r:
            ri = len(self.child)
        else:
            ri = 0
            for j,e in enumerate(self.child):
                # print(j,e.r,x)
                if x < e.r:
                    # print("break")
                    ri = j
                    break
        # print("li,ri:", li, ri)
        # we want to insert n before i, after i or into i
        if li == ri:
            self.child[li].insert(n)
        elif ri == li+1:
            self.child.insert(ri, n)
        else:
            n.child = self.child[li+1:ri]
            # print(n.repr())
            del self.child[li+1:ri]
            self.child.insert(li+1,n)

    def repr(self):
        return (
            self.l,
            list(map(lambda x: x.repr(), self.child)),
            self.r
            )

def encode(count, op, out_bin):
    if   op in ['>','<']: opc = 0b00000000
    elif op in ['+','-']: opc = 0b01000000
    elif op == ']': opc = 0b10000000 # low bits are 0
    elif op == '[': opc = 0b10111111 # low bits for jump offset
    elif op == ',': opc = 0b11000000 # low bits revserved for channel number
    elif op == '.': opc = 0b11100000 # low bits revserved for channel number
    else: raise SyntaxError ("Unknown opcode")
    if op in NEUTRAL:
        out_bin.append(opc)
        return count-1
    else:
        if op in POSITIVE:
            cnt = min(31, count)
            rest = count-cnt
        else:
            cnt = max(-32, -count)
            rest = count+cnt
        opc |= cnt & 0b00111111
        out_bin.append(opc)
        return rest

def out(count, op):
    b = 0
    if count > 1:
        print(count, end='')
    print(op, end='')
    while count > 0:
        count = encode(count, op, out_bin)

max_depth = 0
def calc_jmp(out_bin, tree, offset, depth):
    global max_depth
    if depth > max_depth:
        max_depth = depth
    inserted = 0
    # First calculate what's inside
    for t in tree.child:
        inserted += calc_jmp(out_bin, t, offset+inserted, depth+1)
    # Now this loop
    if tree.l >= 0:
        length = tree.r - tree.l + inserted + 1
        if length >= 0b00100000:
            # long jump
            high = (length >> 8)
            low  = length & 0xff
            if high > 0b00111111:
                raise SyntaxError ("jump too long at {} (length = {})".format(sptr, length))
            out_bin[tree.l+offset] = 0b10100000 | high
            out_bin.insert(tree.l+offset+1, low)
            inserted += 1
        else:
            out_bin[tree.l+offset] = 0b10000000 | length
    return inserted

def calculate_jumps():
    loop_stack = []
    # interval tree for loop
    tree = Node(-1,len(out_bin))
    for ptr, opc in enumerate(out_bin):
        if opc == 0b10111111: loop_stack.append(ptr)
        if opc == 0b10000000: #close loop
            if not loop_stack:
                raise SyntaxError ("unmatched close loop at {}".format(ptr))
            sptr = loop_stack.pop()
            tree.insert(Node(sptr, ptr))
            # print(tree.repr())
    if loop_stack:
        raise SyntaxError ("unclosed loops at {}".format(loop_stack))
    pp = pprint.PrettyPrinter(indent=4)
    pp.pprint(tree.repr())
    # Traverse tree and insert long jumps starting from innermost loops
    inserted = calc_jmp(out_bin, tree, 0, 1)
    print(f"inserted {inserted} long jumps")
    print(f"max depth is {max_depth}")

def brainfuck (fd=None):
    fd = fd or (open(sys.argv[1]) if sys.argv[1:] else sys.stdin)
    source = fd.read()
    ptr = 0
    last_opcode = None
    count = 0
    while ptr < len(source):
        opcode = source[ptr]
        if opcode in OPS:
            if opcode == last_opcode:
                count += 1
            else:
                if last_opcode:
                    out(count, last_opcode)
                count = 1
                last_opcode = opcode
        ptr += 1

    if count > 0:
        out(count, last_opcode)

    print()
    calculate_jumps()

    outfn = sys.argv[2] if sys.argv[2:] else "out.bin"
    with open(outfn, "wb") as binary_file:
        binary_file.write(out_bin)

if __name__ == "__main__": brainfuck()
