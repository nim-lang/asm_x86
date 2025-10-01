import "../src/asm_x86"

var buf = initBuffer()

# Test MOV RAX, RBX
emitMov(buf, RAX, RBX)
echo "MOV RAX, RBX: ", buf

buf = initBuffer()
# Test MOV RAX, 42
emitMovImmToReg(buf, RAX, 42)
echo "MOV RAX, 42: ", buf

buf = initBuffer()
# Test ADD RAX, RBX
emitAdd(buf, RAX, RBX)
echo "ADD RAX, RBX: ", buf

buf = initBuffer()
# Test RET
emitRet(buf)
echo "RET: ", buf
