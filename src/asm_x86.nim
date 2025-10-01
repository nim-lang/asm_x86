# Nifasm - x86_64 Binary Assembler
# A dependency-free x86_64 assembler that emits binary instruction bytes

import std/strutils
import elf

type
  # x86_64 64-bit general purpose registers
  Register* = enum
    RAX = 0, RCX = 1, RDX = 2, RBX = 3, RSP = 4, RBP = 5, RSI = 6, RDI = 7,
    R8 = 8, R9 = 9, R10 = 10, R11 = 11, R12 = 12, R13 = 13, R14 = 14, R15 = 15

  # Addressing modes for ModR/M byte
  AddressingMode* = enum
    amIndirect = 0b00,        # Indirect memory addressing
    amIndirectDisp8 = 0b01,   # Indirect with 8-bit displacement
    amIndirectDisp32 = 0b10,  # Indirect with 32-bit displacement
    amDirect = 0b11           # Direct register addressing

  # Memory operand
  MemoryOperand* = object
    base*: Register
    index*: Register
    scale*: int  # 1, 2, 4, or 8
    displacement*: int32
    hasIndex*: bool

  # Label system for jump optimization
  LabelId* = distinct int

  # Label definition in the instruction stream
  LabelDef* = object
    id*: LabelId
    position*: int  # Position where label is defined

  # Jump instruction entry for optimization
  JumpEntry* = object
    position*: int        # Position in buffer where jump instruction starts
    target*: LabelId      # Target label ID
    instruction*: JumpType # Type of jump instruction
    originalSize*: int    # Original instruction size in bytes

  # Types of jump instructions
  JumpType* = enum
    jtCall, jtJmp, jtJe, jtJne, jtJg, jtJl, jtJge, jtJle, jtJa, jtJb, jtJae, jtJbe


  # Buffer for accumulating instruction bytes
  Buffer* = object
    data*: seq[byte]
    jumps*: seq[JumpEntry]  # Track jump instructions for optimization
    labels*: seq[LabelDef]  # Track label definitions
    nextLabelId*: int       # Next available label ID

# LabelId equality comparison
proc `==`*(a, b: LabelId): bool =
  int(a) == int(b)

# Buffer operations
proc initBuffer*(): Buffer =
  result = Buffer(
    data: @[],
    jumps: @[],
    labels: @[],
    nextLabelId: 0
  )

proc add*(buf: var Buffer; b: byte) =
  buf.data.add(b)

proc addUint16*(buf: var Buffer; val: uint16) =
  buf.add(byte(val and 0xFF))
  buf.add(byte((val shr 8) and 0xFF))

proc addUint32*(buf: var Buffer; val: uint32) =
  buf.add(byte(val and 0xFF))
  buf.add(byte((val shr 8) and 0xFF))
  buf.add(byte((val shr 16) and 0xFF))
  buf.add(byte((val shr 24) and 0xFF))

proc addInt32*(buf: var Buffer; val: int32) =
  buf.addUint32(uint32(val))

proc addInt64*(buf: var Buffer; val: int64) =
  buf.add(byte(val and 0xFF))
  buf.add(byte((val shr 8) and 0xFF))
  buf.add(byte((val shr 16) and 0xFF))
  buf.add(byte((val shr 24) and 0xFF))
  buf.add(byte((val shr 32) and 0xFF))
  buf.add(byte((val shr 40) and 0xFF))
  buf.add(byte((val shr 48) and 0xFF))
  buf.add(byte((val shr 56) and 0xFF))

proc len*(buf: Buffer): int =
  ## Get the length of the buffer
  buf.data.len

proc `$`*(buf: Buffer): string =
  result = ""
  for i, b in buf.data:
    if i > 0: result.add(" ")
    result.add(b.toHex(2).toUpper())

# Label system functions
proc createLabel*(buf: var Buffer): LabelId =
  ## Create a new label ID
  result = LabelId(buf.nextLabelId)
  inc(buf.nextLabelId)

proc defineLabel*(buf: var Buffer; label: LabelId) =
  ## Define a label at the current position
  buf.labels.add(LabelDef(id: label, position: buf.data.len))

proc getLabelPosition*(buf: Buffer; label: LabelId): int =
  ## Get the position of a label definition
  for labelDef in buf.labels:
    if labelDef.id == label:
      return labelDef.position
  raise newException(ValueError, "Label not found")

# Jump optimization helper functions
proc addJump*(buf: var Buffer; position: int; target: LabelId; instruction: JumpType; size: int) =
  ## Add a jump entry to the buffer for later optimization
  buf.jumps.add(JumpEntry(
    position: position,
    target: target,
    instruction: instruction,
    originalSize: size
  ))

proc getCurrentPosition*(buf: Buffer): int =
  ## Get the current position in the buffer
  buf.data.len

proc calculateJumpDistance*(fromPos: int; toPos: int; instruction: JumpType = jtJmp): int =
  ## Calculate the distance for a relative jump
  ## For x86-64, the distance is calculated from after the entire instruction
  ## CALL/JMP: 1 byte opcode + 4 bytes displacement = 5 bytes total
  ## Conditional jumps: 2 bytes opcode + 4 bytes displacement = 6 bytes total
  let instructionSize = if instruction in {jtCall, jtJmp}: 5 else: 6
  toPos - (fromPos + instructionSize)  # Distance from after the complete instruction

proc canUseShortJump*(distance: int): bool =
  ## Check if a jump can use 8-bit displacement
  distance >= -128 and distance <= 127

# REX prefix encoding
type RexPrefix* = object
  w*: bool  # 64-bit operand size
  r*: bool  # Extension of ModR/M reg field
  x*: bool  # Extension of SIB index field
  b*: bool  # Extension of ModR/M r/m field

proc encodeRex*(rex: RexPrefix): byte =
  result = 0x40  # Base REX prefix
  if rex.w: result = result or 0x08
  if rex.r: result = result or 0x04
  if rex.x: result = result or 0x02
  if rex.b: result = result or 0x01

proc needsRex*(reg: Register): bool =
  int(reg) >= 8

# ModR/M byte encoding
proc encodeModRM*(mode: AddressingMode; reg: int; rm: int): byte =
  byte((int(mode) shl 6) or ((reg and 0x07) shl 3) or (rm and 0x07))

# SIB byte encoding
proc encodeSIB*(scale: int; index: int; base: int): byte =
  let scaleBits = case scale
    of 1: 0b00
    of 2: 0b01
    of 4: 0b10
    of 8: 0b11
    else: 0b00
  byte((scaleBits shl 6) or ((index and 0x07) shl 3) or (base and 0x07))

# Core MOV instruction implementations
proc emitMov*(dest: var Buffer; a, b: Register) =
  ## Emit MOV instruction: MOV a, b (move from b to a)
  var rex = RexPrefix(w: true)

  if needsRex(a): rex.r = true
  if needsRex(b): rex.b = true

  if rex.r or rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x89)  # MOV r/m64, r64 opcode
  dest.add(encodeModRM(amDirect, int(a), int(b)))

proc emitMovImmToReg*(dest: var Buffer; reg: Register; imm: int64) =
  ## Emit MOV instruction: MOV reg, imm
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  # Use the special immediate-to-register MOV opcode
  let opcode = 0xB8 + (int(reg) and 0x07)
  dest.add(byte(opcode))

  # Add 64-bit immediate value
  dest.addInt64(imm)

proc emitMovImmToReg32*(dest: var Buffer; reg: Register; imm: int32) =
  ## Emit MOV instruction: MOV reg, imm32 (sign-extended to 64-bit)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0xC7)  # MOV r/m64, imm32 opcode
  dest.add(encodeModRM(amDirect, 0, int(reg)))  # /0 extension
  dest.addInt32(imm)

# Arithmetic instructions
proc emitAdd*(dest: var Buffer; a, b: Register) =
  ## Emit ADD instruction: ADD a, b
  var rex = RexPrefix(w: true)

  if needsRex(a): rex.r = true
  if needsRex(b): rex.b = true

  if rex.r or rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x01)  # ADD r/m64, r64 opcode
  dest.add(encodeModRM(amDirect, int(a), int(b)))

proc emitSub*(dest: var Buffer; a, b: Register) =
  ## Emit SUB instruction: SUB a, b
  var rex = RexPrefix(w: true)

  if needsRex(a): rex.r = true
  if needsRex(b): rex.b = true

  if rex.r or rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x29)  # SUB r/m64, r64 opcode
  dest.add(encodeModRM(amDirect, int(a), int(b)))

proc emitImul*(dest: var Buffer; a, b: Register) =
  ## Emit IMUL instruction: IMUL a, b (signed multiply)
  var rex = RexPrefix(w: true)

  if needsRex(a): rex.r = true
  if needsRex(b): rex.b = true

  if rex.r or rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0xAF)  # IMUL r/m64, r64 opcode
  dest.add(encodeModRM(amDirect, int(a), int(b)))

proc emitImulImm*(dest: var Buffer; reg: Register; imm: int32) =
  ## Emit IMUL instruction: IMUL reg, reg, imm32
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x69)  # IMUL r64, r/m64, imm32 opcode
  dest.add(encodeModRM(amDirect, int(reg), int(reg)))
  dest.addInt32(imm)

# Additional arithmetic operations
proc emitMul*(dest: var Buffer; reg: Register) =
  ## Emit MUL instruction: MUL reg (unsigned multiply)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0xF7)  # MUL r/m64 opcode
  dest.add(encodeModRM(amDirect, 4, int(reg)))  # /4 extension

proc emitDiv*(dest: var Buffer; reg: Register) =
  ## Emit DIV instruction: DIV reg (unsigned divide)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0xF7)  # DIV r/m64 opcode
  dest.add(encodeModRM(amDirect, 6, int(reg)))  # /6 extension

proc emitIdiv*(dest: var Buffer; reg: Register) =
  ## Emit IDIV instruction: IDIV reg (signed divide)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0xF7)  # IDIV r/m64 opcode
  dest.add(encodeModRM(amDirect, 7, int(reg)))  # /7 extension

proc emitInc*(dest: var Buffer; reg: Register) =
  ## Emit INC instruction: INC reg (increment)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0xFF)  # INC r/m64 opcode
  dest.add(encodeModRM(amDirect, 0, int(reg)))  # /0 extension

proc emitDec*(dest: var Buffer; reg: Register) =
  ## Emit DEC instruction: DEC reg (decrement)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0xFF)  # DEC r/m64 opcode
  dest.add(encodeModRM(amDirect, 1, int(reg)))  # /1 extension

proc emitNeg*(dest: var Buffer; reg: Register) =
  ## Emit NEG instruction: NEG reg (negate)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0xF7)  # NEG r/m64 opcode
  dest.add(encodeModRM(amDirect, 3, int(reg)))  # /3 extension

proc emitCmp*(dest: var Buffer; a, b: Register) =
  ## Emit CMP instruction: CMP a, b (compare)
  var rex = RexPrefix(w: true)

  if needsRex(a): rex.r = true
  if needsRex(b): rex.b = true

  if rex.r or rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x39)  # CMP r/m64, r64 opcode
  dest.add(encodeModRM(amDirect, int(a), int(b)))

proc emitTest*(dest: var Buffer; a, b: Register) =
  ## Emit TEST instruction: TEST a, b (test)
  var rex = RexPrefix(w: true)

  if needsRex(a): rex.r = true
  if needsRex(b): rex.b = true

  if rex.r or rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x85)  # TEST r/m64, r64 opcode
  dest.add(encodeModRM(amDirect, int(a), int(b)))

# Arithmetic with immediate values
proc emitAddImm*(dest: var Buffer; reg: Register; imm: int32) =
  ## Emit ADD instruction: ADD reg, imm32
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x81)  # ADD r/m64, imm32 opcode
  dest.add(encodeModRM(amDirect, 0, int(reg)))  # /0 extension
  dest.addInt32(imm)

proc emitSubImm*(dest: var Buffer; reg: Register; imm: int32) =
  ## Emit SUB instruction: SUB reg, imm32
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x81)  # SUB r/m64, imm32 opcode
  dest.add(encodeModRM(amDirect, 5, int(reg)))  # /5 extension
  dest.addInt32(imm)

proc emitAndImm*(dest: var Buffer; reg: Register; imm: int32) =
  ## Emit AND instruction: AND reg, imm32
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x81)  # AND r/m64, imm32 opcode
  dest.add(encodeModRM(amDirect, 4, int(reg)))  # /4 extension
  dest.addInt32(imm)

proc emitOrImm*(dest: var Buffer; reg: Register; imm: int32) =
  ## Emit OR instruction: OR reg, imm32
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x81)  # OR r/m64, imm32 opcode
  dest.add(encodeModRM(amDirect, 1, int(reg)))  # /1 extension
  dest.addInt32(imm)

proc emitXorImm*(dest: var Buffer; reg: Register; imm: int32) =
  ## Emit XOR instruction: XOR reg, imm32
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x81)  # XOR r/m64, imm32 opcode
  dest.add(encodeModRM(amDirect, 6, int(reg)))  # /6 extension
  dest.addInt32(imm)

proc emitCmpImm*(dest: var Buffer; reg: Register; imm: int32) =
  ## Emit CMP instruction: CMP reg, imm32
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x81)  # CMP r/m64, imm32 opcode
  dest.add(encodeModRM(amDirect, 7, int(reg)))  # /7 extension
  dest.addInt32(imm)

# Shift operations
proc emitShl*(dest: var Buffer; reg: Register; count: int) =
  ## Emit SHL instruction: SHL reg, count (shift left)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  if count == 1:
    dest.add(0xD1)  # SHL r/m64, 1 opcode
    dest.add(encodeModRM(amDirect, 4, int(reg)))  # /4 extension
  else:
    dest.add(0xC1)  # SHL r/m64, imm8 opcode
    dest.add(encodeModRM(amDirect, 4, int(reg)))  # /4 extension
    dest.add(byte(count))

proc emitShr*(dest: var Buffer; reg: Register; count: int) =
  ## Emit SHR instruction: SHR reg, count (shift right)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  if count == 1:
    dest.add(0xD1)  # SHR r/m64, 1 opcode
    dest.add(encodeModRM(amDirect, 5, int(reg)))  # /5 extension
  else:
    dest.add(0xC1)  # SHR r/m64, imm8 opcode
    dest.add(encodeModRM(amDirect, 5, int(reg)))  # /5 extension
    dest.add(byte(count))

proc emitSal*(dest: var Buffer; reg: Register; count: int) =
  ## Emit SAL instruction: SAL reg, count (shift arithmetic left)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  if count == 1:
    dest.add(0xD1)  # SAL r/m64, 1 opcode
    dest.add(encodeModRM(amDirect, 6, int(reg)))  # /6 extension
  else:
    dest.add(0xC1)  # SAL r/m64, imm8 opcode
    dest.add(encodeModRM(amDirect, 6, int(reg)))  # /6 extension
    dest.add(byte(count))

proc emitSar*(dest: var Buffer; reg: Register; count: int) =
  ## Emit SAR instruction: SAR reg, count (shift arithmetic right)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  if count == 1:
    dest.add(0xD1)  # SAR r/m64, 1 opcode
    dest.add(encodeModRM(amDirect, 7, int(reg)))  # /7 extension
  else:
    dest.add(0xC1)  # SAR r/m64, imm8 opcode
    dest.add(encodeModRM(amDirect, 7, int(reg)))  # /7 extension
    dest.add(byte(count))

# Rotate operations
proc emitRol*(dest: var Buffer; reg: Register; count: int) =
  ## Emit ROL instruction: ROL reg, count (rotate left)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  if count == 1:
    dest.add(0xD1)  # ROL r/m64, 1 opcode
    dest.add(encodeModRM(amDirect, 0, int(reg)))  # /0 extension
  else:
    dest.add(0xC1)  # ROL r/m64, imm8 opcode
    dest.add(encodeModRM(amDirect, 0, int(reg)))  # /0 extension
    dest.add(byte(count))

proc emitRor*(dest: var Buffer; reg: Register; count: int) =
  ## Emit ROR instruction: ROR reg, count (rotate right)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  if count == 1:
    dest.add(0xD1)  # ROR r/m64, 1 opcode
    dest.add(encodeModRM(amDirect, 1, int(reg)))  # /1 extension
  else:
    dest.add(0xC1)  # ROR r/m64, imm8 opcode
    dest.add(encodeModRM(amDirect, 1, int(reg)))  # /1 extension
    dest.add(byte(count))

proc emitRcl*(dest: var Buffer; reg: Register; count: int) =
  ## Emit RCL instruction: RCL reg, count (rotate left through carry)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  if count == 1:
    dest.add(0xD1)  # RCL r/m64, 1 opcode
    dest.add(encodeModRM(amDirect, 2, int(reg)))  # /2 extension
  else:
    dest.add(0xC1)  # RCL r/m64, imm8 opcode
    dest.add(encodeModRM(amDirect, 2, int(reg)))  # /2 extension
    dest.add(byte(count))

proc emitRcr*(dest: var Buffer; reg: Register; count: int) =
  ## Emit RCR instruction: RCR reg, count (rotate right through carry)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  if count == 1:
    dest.add(0xD1)  # RCR r/m64, 1 opcode
    dest.add(encodeModRM(amDirect, 3, int(reg)))  # /3 extension
  else:
    dest.add(0xC1)  # RCR r/m64, imm8 opcode
    dest.add(encodeModRM(amDirect, 3, int(reg)))  # /3 extension
    dest.add(byte(count))

# Bit manipulation operations
proc emitNot*(dest: var Buffer; reg: Register) =
  ## Emit NOT instruction: NOT reg (bitwise not)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0xF7)  # NOT r/m64 opcode
  dest.add(encodeModRM(amDirect, 2, int(reg)))  # /2 extension

proc emitBsf*(dest: var Buffer; destReg, srcReg: Register) =
  ## Emit BSF instruction: BSF destReg, srcReg (bit scan forward)
  var rex = RexPrefix(w: true)

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0xBC)  # BSF r64, r/m64 opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitBsr*(dest: var Buffer; destReg, srcReg: Register) =
  ## Emit BSR instruction: BSR destReg, srcReg (bit scan reverse)
  var rex = RexPrefix(w: true)

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0xBD)  # BSR r64, r/m64 opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitBt*(dest: var Buffer; reg: Register; bit: int) =
  ## Emit BT instruction: BT reg, bit (bit test)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0xBA)  # BT r/m64, imm8 opcode
  dest.add(encodeModRM(amDirect, 4, int(reg)))  # /4 extension
  dest.add(byte(bit))

proc emitBtc*(dest: var Buffer; reg: Register; bit: int) =
  ## Emit BTC instruction: BTC reg, bit (bit test and complement)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0xBA)  # BTC r/m64, imm8 opcode
  dest.add(encodeModRM(amDirect, 7, int(reg)))  # /7 extension
  dest.add(byte(bit))

proc emitBtr*(dest: var Buffer; reg: Register; bit: int) =
  ## Emit BTR instruction: BTR reg, bit (bit test and reset)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0xBA)  # BTR r/m64, imm8 opcode
  dest.add(encodeModRM(amDirect, 6, int(reg)))  # /6 extension
  dest.add(byte(bit))

proc emitBts*(dest: var Buffer; reg: Register; bit: int) =
  ## Emit BTS instruction: BTS reg, bit (bit test and set)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0xBA)  # BTS r/m64, imm8 opcode
  dest.add(encodeModRM(amDirect, 5, int(reg)))  # /5 extension
  dest.add(byte(bit))

# Floating point operations
# x87 FPU registers (ST0-ST7)
type FpuRegister* = enum
  ST0 = 0, ST1 = 1, ST2 = 2, ST3 = 3, ST4 = 4, ST5 = 5, ST6 = 6, ST7 = 7

# SSE/AVX registers (XMM0-XMM15)
type XmmRegister* = enum
  XMM0 = 0, XMM1 = 1, XMM2 = 2, XMM3 = 3, XMM4 = 4, XMM5 = 5, XMM6 = 6, XMM7 = 7,
  XMM8 = 8, XMM9 = 9, XMM10 = 10, XMM11 = 11, XMM12 = 12, XMM13 = 13, XMM14 = 14, XMM15 = 15

proc needsRex*(reg: XmmRegister): bool =
  int(reg) >= 8

# x87 FPU operations
proc emitFld*(dest: var Buffer; reg: FpuRegister) =
  ## Emit FLD instruction: FLD reg (load floating point)
  dest.add(0xD9)  # FLD opcode
  dest.add(encodeModRM(amDirect, 0, int(reg)))  # /0 extension

proc emitFst*(dest: var Buffer; reg: FpuRegister) =
  ## Emit FST instruction: FST reg (store floating point)
  dest.add(0xDD)  # FST opcode
  dest.add(encodeModRM(amDirect, 2, int(reg)))  # /2 extension

proc emitFstp*(dest: var Buffer; reg: FpuRegister) =
  ## Emit FSTP instruction: FSTP reg (store floating point and pop)
  dest.add(0xDD)  # FSTP opcode
  dest.add(encodeModRM(amDirect, 3, int(reg)))  # /3 extension

proc emitFadd*(dest: var Buffer; reg: FpuRegister) =
  ## Emit FADD instruction: FADD reg (floating point add)
  dest.add(0xD8)  # FADD opcode
  dest.add(encodeModRM(amDirect, 0, int(reg)))  # /0 extension

proc emitFsub*(dest: var Buffer; reg: FpuRegister) =
  ## Emit FSUB instruction: FSUB reg (floating point subtract)
  dest.add(0xD8)  # FSUB opcode
  dest.add(encodeModRM(amDirect, 4, int(reg)))  # /4 extension

proc emitFmul*(dest: var Buffer; reg: FpuRegister) =
  ## Emit FMUL instruction: FMUL reg (floating point multiply)
  dest.add(0xD8)  # FMUL opcode
  dest.add(encodeModRM(amDirect, 1, int(reg)))  # /1 extension

proc emitFdiv*(dest: var Buffer; reg: FpuRegister) =
  ## Emit FDIV instruction: FDIV reg (floating point divide)
  dest.add(0xD8)  # FDIV opcode
  dest.add(encodeModRM(amDirect, 6, int(reg)))  # /6 extension

proc emitFcom*(dest: var Buffer; reg: FpuRegister) =
  ## Emit FCOM instruction: FCOM reg (floating point compare)
  dest.add(0xD8)  # FCOM opcode
  dest.add(encodeModRM(amDirect, 2, int(reg)))  # /2 extension

proc emitFcomp*(dest: var Buffer; reg: FpuRegister) =
  ## Emit FCOMP instruction: FCOMP reg (floating point compare and pop)
  dest.add(0xD8)  # FCOMP opcode
  dest.add(encodeModRM(amDirect, 3, int(reg)))  # /3 extension

proc emitFsin*(dest: var Buffer) =
  ## Emit FSIN instruction: FSIN (sine)
  dest.add(0xD9)  # FSIN opcode
  dest.add(0xFE)  # /6 extension

proc emitFcos*(dest: var Buffer) =
  ## Emit FCOS instruction: FCOS (cosine)
  dest.add(0xD9)  # FCOS opcode
  dest.add(0xFF)  # /7 extension

proc emitFsqrt*(dest: var Buffer) =
  ## Emit FSQRT instruction: FSQRT (square root)
  dest.add(0xD9)  # FSQRT opcode
  dest.add(0xFA)  # /2 extension

proc emitFabs*(dest: var Buffer) =
  ## Emit FABS instruction: FABS (absolute value)
  dest.add(0xD9)  # FABS opcode
  dest.add(0xE1)  # /4 extension

proc emitFchs*(dest: var Buffer) =
  ## Emit FCHS instruction: FCHS (change sign)
  dest.add(0xD9)  # FCHS opcode
  dest.add(0xE0)  # /4 extension

# SSE operations
proc emitMovss*(dest: var Buffer; destReg, srcReg: XmmRegister) =
  ## Emit MOVSS instruction: MOVSS destReg, srcReg (move scalar single precision)
  var rex = RexPrefix()

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b:
    dest.add(encodeRex(rex))

  dest.add(0xF3)  # MOVSS prefix
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x10)  # MOVSS opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitMovsd*(dest: var Buffer; destReg, srcReg: XmmRegister) =
  ## Emit MOVSD instruction: MOVSD destReg, srcReg (move scalar double precision)
  var rex = RexPrefix()

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b:
    dest.add(encodeRex(rex))

  dest.add(0xF2)  # MOVSD prefix
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x10)  # MOVSD opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitAddss*(dest: var Buffer; destReg, srcReg: XmmRegister) =
  ## Emit ADDSS instruction: ADDSS destReg, srcReg (add scalar single precision)
  var rex = RexPrefix()

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b:
    dest.add(encodeRex(rex))

  dest.add(0xF3)  # ADDSS prefix
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x58)  # ADDSS opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitAddsd*(dest: var Buffer; destReg, srcReg: XmmRegister) =
  ## Emit ADDSD instruction: ADDSD destReg, srcReg (add scalar double precision)
  var rex = RexPrefix()

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b:
    dest.add(encodeRex(rex))

  dest.add(0xF2)  # ADDSD prefix
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x58)  # ADDSD opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitSubss*(dest: var Buffer; destReg, srcReg: XmmRegister) =
  ## Emit SUBSS instruction: SUBSS destReg, srcReg (subtract scalar single precision)
  var rex = RexPrefix()

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b:
    dest.add(encodeRex(rex))

  dest.add(0xF3)  # SUBSS prefix
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x5C)  # SUBSS opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitSubsd*(dest: var Buffer; destReg, srcReg: XmmRegister) =
  ## Emit SUBSD instruction: SUBSD destReg, srcReg (subtract scalar double precision)
  var rex = RexPrefix()

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b:
    dest.add(encodeRex(rex))

  dest.add(0xF2)  # SUBSD prefix
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x5C)  # SUBSD opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitMulss*(dest: var Buffer; destReg, srcReg: XmmRegister) =
  ## Emit MULSS instruction: MULSS destReg, srcReg (multiply scalar single precision)
  var rex = RexPrefix()

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b:
    dest.add(encodeRex(rex))

  dest.add(0xF3)  # MULSS prefix
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x59)  # MULSS opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitMulsd*(dest: var Buffer; destReg, srcReg: XmmRegister) =
  ## Emit MULSD instruction: MULSD destReg, srcReg (multiply scalar double precision)
  var rex = RexPrefix()

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b:
    dest.add(encodeRex(rex))

  dest.add(0xF2)  # MULSD prefix
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x59)  # MULSD opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitDivss*(dest: var Buffer; destReg, srcReg: XmmRegister) =
  ## Emit DIVSS instruction: DIVSS destReg, srcReg (divide scalar single precision)
  var rex = RexPrefix()

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b:
    dest.add(encodeRex(rex))

  dest.add(0xF3)  # DIVSS prefix
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x5E)  # DIVSS opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitDivsd*(dest: var Buffer; destReg, srcReg: XmmRegister) =
  ## Emit DIVSD instruction: DIVSD destReg, srcReg (divide scalar double precision)
  var rex = RexPrefix()

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b:
    dest.add(encodeRex(rex))

  dest.add(0xF2)  # DIVSD prefix
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x5E)  # DIVSD opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitSqrtss*(dest: var Buffer; destReg, srcReg: XmmRegister) =
  ## Emit SQRTSS instruction: SQRTSS destReg, srcReg (square root scalar single precision)
  var rex = RexPrefix()

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b:
    dest.add(encodeRex(rex))

  dest.add(0xF3)  # SQRTSS prefix
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x51)  # SQRTSS opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitSqrtsd*(dest: var Buffer; destReg, srcReg: XmmRegister) =
  ## Emit SQRTSD instruction: SQRTSD destReg, srcReg (square root scalar double precision)
  var rex = RexPrefix()

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b:
    dest.add(encodeRex(rex))

  dest.add(0xF2)  # SQRTSD prefix
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x51)  # SQRTSD opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitComiss*(dest: var Buffer; destReg, srcReg: XmmRegister) =
  ## Emit COMISS instruction: COMISS destReg, srcReg (compare scalar single precision)
  var rex = RexPrefix()

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b:
    dest.add(encodeRex(rex))

  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x2F)  # COMISS opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitComisd*(dest: var Buffer; destReg, srcReg: XmmRegister) =
  ## Emit COMISD instruction: COMISD destReg, srcReg (compare scalar double precision)
  var rex = RexPrefix()

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b:
    dest.add(encodeRex(rex))

  dest.add(0x66)  # COMISD prefix
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x2F)  # COMISD opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitCvtss2sd*(dest: var Buffer; destReg, srcReg: XmmRegister) =
  ## Emit CVTSS2SD instruction: CVTSS2SD destReg, srcReg (convert single to double)
  var rex = RexPrefix()

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b:
    dest.add(encodeRex(rex))

  dest.add(0xF3)  # CVTSS2SD prefix
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x5A)  # CVTSS2SD opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitCvtsd2ss*(dest: var Buffer; destReg, srcReg: XmmRegister) =
  ## Emit CVTSD2SS instruction: CVTSD2SS destReg, srcReg (convert double to single)
  var rex = RexPrefix()

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b:
    dest.add(encodeRex(rex))

  dest.add(0xF2)  # CVTSD2SS prefix
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x5A)  # CVTSD2SS opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitCvtsi2ss*(dest: var Buffer; destReg: XmmRegister; srcReg: Register) =
  ## Emit CVTSI2SS instruction: CVTSI2SS destReg, srcReg (convert integer to single)
  var rex = RexPrefix()

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b:
    dest.add(encodeRex(rex))

  dest.add(0xF3)  # CVTSI2SS prefix
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x2A)  # CVTSI2SS opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitCvtsi2sd*(dest: var Buffer; destReg: XmmRegister; srcReg: Register) =
  ## Emit CVTSI2SD instruction: CVTSI2SD destReg, srcReg (convert integer to double)
  var rex = RexPrefix()

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b:
    dest.add(encodeRex(rex))

  dest.add(0xF2)  # CVTSI2SD prefix
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x2A)  # CVTSI2SD opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitCvtss2si*(dest: var Buffer; destReg: Register; srcReg: XmmRegister) =
  ## Emit CVTSS2SI instruction: CVTSS2SI destReg, srcReg (convert single to integer)
  var rex = RexPrefix(w: true)

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0xF3)  # CVTSS2SI prefix
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x2D)  # CVTSS2SI opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

proc emitCvtsd2si*(dest: var Buffer; destReg: Register; srcReg: XmmRegister) =
  ## Emit CVTSD2SI instruction: CVTSD2SI destReg, srcReg (convert double to integer)
  var rex = RexPrefix(w: true)

  if needsRex(destReg): rex.r = true
  if needsRex(srcReg): rex.b = true

  if rex.r or rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0xF2)  # CVTSD2SI prefix
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x2D)  # CVTSD2SI opcode
  dest.add(encodeModRM(amDirect, int(destReg), int(srcReg)))

# Atomic operations
# Lock prefix for atomic operations
proc emitLock*(dest: var Buffer) =
  ## Emit LOCK prefix for atomic operations
  dest.add(0xF0)

# Atomic exchange operations
proc emitXchg*(dest: var Buffer; a, b: Register) =
  ## Emit XCHG instruction: XCHG a, b (exchange)
  var rex = RexPrefix(w: true)

  if needsRex(a): rex.r = true
  if needsRex(b): rex.b = true

  if rex.r or rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x87)  # XCHG r/m64, r64 opcode
  dest.add(encodeModRM(amDirect, int(a), int(b)))

proc emitXadd*(dest: var Buffer; a, b: Register) =
  ## Emit XADD instruction: XADD a, b (exchange and add)
  var rex = RexPrefix(w: true)

  if needsRex(a): rex.r = true
  if needsRex(b): rex.b = true

  if rex.r or rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0xC1)  # XADD r/m64, r64 opcode
  dest.add(encodeModRM(amDirect, int(a), int(b)))

# Atomic compare and exchange
proc emitCmpxchg*(dest: var Buffer; a, b: Register) =
  ## Emit CMPXCHG instruction: CMPXCHG a, b (compare and exchange)
  var rex = RexPrefix(w: true)

  if needsRex(a): rex.r = true
  if needsRex(b): rex.b = true

  if rex.r or rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0xB1)  # CMPXCHG r/m64, r64 opcode
  dest.add(encodeModRM(amDirect, int(a), int(b)))

# Atomic compare and exchange with 8-byte operand
proc emitCmpxchg8b*(dest: var Buffer; reg: Register) =
  ## Emit CMPXCHG8B instruction: CMPXCHG8B reg (compare and exchange 8 bytes)
  var rex = RexPrefix(w: true)

  if needsRex(reg): rex.b = true

  if rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0xC7)  # CMPXCHG8B r/m64 opcode
  dest.add(encodeModRM(amDirect, 1, int(reg)))  # /1 extension

# Atomic bit operations
proc emitBtsAtomic*(dest: var Buffer; reg: Register; bit: int) =
  ## Emit atomic BTS instruction: LOCK BTS reg, bit (atomic bit test and set)
  dest.emitLock()
  dest.emitBts(reg, bit)

proc emitBtrAtomic*(dest: var Buffer; reg: Register; bit: int) =
  ## Emit atomic BTR instruction: LOCK BTR reg, bit (atomic bit test and reset)
  dest.emitLock()
  dest.emitBtr(reg, bit)

proc emitBtcAtomic*(dest: var Buffer; reg: Register; bit: int) =
  ## Emit atomic BTC instruction: LOCK BTC reg, bit (atomic bit test and complement)
  dest.emitLock()
  dest.emitBtc(reg, bit)


# Memory fence operations
proc emitMfence*(dest: var Buffer) =
  ## Emit MFENCE instruction: MFENCE (memory fence)
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0xAE)  # MFENCE opcode
  dest.add(0xF0)  # /6 extension

proc emitSfence*(dest: var Buffer) =
  ## Emit SFENCE instruction: SFENCE (store fence)
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0xAE)  # SFENCE opcode
  dest.add(0xF8)  # /7 extension

proc emitLfence*(dest: var Buffer) =
  ## Emit LFENCE instruction: LFENCE (load fence)
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0xAE)  # LFENCE opcode
  dest.add(0xE8)  # /5 extension

# Pause instruction for spin loops
proc emitPause*(dest: var Buffer) =
  ## Emit PAUSE instruction: PAUSE (pause for spin loops)
  dest.add(0xF3)  # PAUSE prefix
  dest.add(0x90)  # NOP opcode

# Memory ordering operations
proc emitClflush*(dest: var Buffer; reg: Register) =
  ## Emit CLFLUSH instruction: CLFLUSH reg (cache line flush)
  var rex = RexPrefix()

  if needsRex(reg): rex.b = true

  if rex.b:
    dest.add(encodeRex(rex))

  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0xAE)  # CLFLUSH opcode
  dest.add(encodeModRM(amDirect, 7, int(reg)))  # /7 extension

proc emitClflushopt*(dest: var Buffer; reg: Register) =
  ## Emit CLFLUSHOPT instruction: CLFLUSHOPT reg (cache line flush optimized)
  var rex = RexPrefix()

  if needsRex(reg): rex.b = true

  if rex.b:
    dest.add(encodeRex(rex))

  dest.add(0x66)  # CLFLUSHOPT prefix
  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0xAE)  # CLFLUSHOPT opcode
  dest.add(encodeModRM(amDirect, 7, int(reg)))  # /7 extension

# Prefetch operations
proc emitPrefetchT0*(dest: var Buffer; reg: Register) =
  ## Emit PREFETCHT0 instruction: PREFETCHT0 reg (prefetch for all caches)
  var rex = RexPrefix()

  if needsRex(reg): rex.b = true

  if rex.b:
    dest.add(encodeRex(rex))

  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x18)  # PREFETCH opcode
  dest.add(encodeModRM(amDirect, 1, int(reg)))  # /1 extension

proc emitPrefetchT1*(dest: var Buffer; reg: Register) =
  ## Emit PREFETCHT1 instruction: PREFETCHT1 reg (prefetch for L2 cache)
  var rex = RexPrefix()

  if needsRex(reg): rex.b = true

  if rex.b:
    dest.add(encodeRex(rex))

  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x18)  # PREFETCH opcode
  dest.add(encodeModRM(amDirect, 2, int(reg)))  # /2 extension

proc emitPrefetchT2*(dest: var Buffer; reg: Register) =
  ## Emit PREFETCHT2 instruction: PREFETCHT2 reg (prefetch for L3 cache)
  var rex = RexPrefix()

  if needsRex(reg): rex.b = true

  if rex.b:
    dest.add(encodeRex(rex))

  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x18)  # PREFETCH opcode
  dest.add(encodeModRM(amDirect, 3, int(reg)))  # /3 extension

proc emitPrefetchNta*(dest: var Buffer; reg: Register) =
  ## Emit PREFETCHNTA instruction: PREFETCHNTA reg (prefetch non-temporal)
  var rex = RexPrefix()

  if needsRex(reg): rex.b = true

  if rex.b:
    dest.add(encodeRex(rex))

  dest.add(0x0F)  # Two-byte opcode prefix
  dest.add(0x18)  # PREFETCH opcode
  dest.add(encodeModRM(amDirect, 0, int(reg)))  # /0 extension


# Control flow instructions
proc emitRet*(dest: var Buffer) =
  ## Emit RET instruction
  dest.add(0xC3)

proc emitCall*(dest: var Buffer; target: LabelId) =
  ## Emit CALL instruction: CALL target (relative call)
  let pos = dest.getCurrentPosition()
  dest.add(0xE8)
  dest.addInt32(0)  # Placeholder, will be filled during optimization
  dest.addJump(pos, target, jtCall, 5)  # 1 byte opcode + 4 bytes displacement

proc emitJmp*(dest: var Buffer; target: LabelId) =
  ## Emit JMP instruction: JMP target (relative jump)
  let pos = dest.getCurrentPosition()
  dest.add(0xE9)
  dest.addInt32(0)  # Placeholder, will be filled during optimization
  dest.addJump(pos, target, jtJmp, 5)  # 1 byte opcode + 4 bytes displacement

# Conditional jump instructions
proc emitJe*(dest: var Buffer; target: LabelId) =
  ## Emit JE instruction: JE target (jump if equal)
  let pos = dest.getCurrentPosition()
  dest.add(0x0F)
  dest.add(0x84)
  dest.addInt32(0)  # Placeholder, will be filled during optimization
  dest.addJump(pos, target, jtJe, 6)  # 2 bytes opcode + 4 bytes displacement

proc emitJne*(dest: var Buffer; target: LabelId) =
  ## Emit JNE instruction: JNE target (jump if not equal)
  let pos = dest.getCurrentPosition()
  dest.add(0x0F)
  dest.add(0x85)
  dest.addInt32(0)  # Placeholder, will be filled during optimization
  dest.addJump(pos, target, jtJne, 6)  # 2 bytes opcode + 4 bytes displacement

proc emitJg*(dest: var Buffer; target: LabelId) =
  ## Emit JG instruction: JG target (jump if greater)
  let pos = dest.getCurrentPosition()
  dest.add(0x0F)
  dest.add(0x8F)
  dest.addInt32(0)  # Placeholder, will be filled during optimization
  dest.addJump(pos, target, jtJg, 6)  # 2 bytes opcode + 4 bytes displacement

proc emitJl*(dest: var Buffer; target: LabelId) =
  ## Emit JL instruction: JL target (jump if less)
  let pos = dest.getCurrentPosition()
  dest.add(0x0F)
  dest.add(0x8C)
  dest.addInt32(0)  # Placeholder, will be filled during optimization
  dest.addJump(pos, target, jtJl, 6)  # 2 bytes opcode + 4 bytes displacement

proc emitJge*(dest: var Buffer; target: LabelId) =
  ## Emit JGE instruction: JGE target (jump if greater or equal)
  let pos = dest.getCurrentPosition()
  dest.add(0x0F)
  dest.add(0x8D)
  dest.addInt32(0)  # Placeholder, will be filled during optimization
  dest.addJump(pos, target, jtJge, 6)  # 2 bytes opcode + 4 bytes displacement

proc emitJle*(dest: var Buffer; target: LabelId) =
  ## Emit JLE instruction: JLE target (jump if less or equal)
  let pos = dest.getCurrentPosition()
  dest.add(0x0F)
  dest.add(0x8E)
  dest.addInt32(0)  # Placeholder, will be filled during optimization
  dest.addJump(pos, target, jtJle, 6)  # 2 bytes opcode + 4 bytes displacement

proc emitJa*(dest: var Buffer; target: LabelId) =
  ## Emit JA instruction: JA target (jump if above, unsigned)
  let pos = dest.getCurrentPosition()
  dest.add(0x0F)
  dest.add(0x87)
  dest.addInt32(0)  # Placeholder, will be filled during optimization
  dest.addJump(pos, target, jtJa, 6)  # 2 bytes opcode + 4 bytes displacement

proc emitJb*(dest: var Buffer; target: LabelId) =
  ## Emit JB instruction: JB target (jump if below, unsigned)
  let pos = dest.getCurrentPosition()
  dest.add(0x0F)
  dest.add(0x82)
  dest.addInt32(0)  # Placeholder, will be filled during optimization
  dest.addJump(pos, target, jtJb, 6)  # 2 bytes opcode + 4 bytes displacement

proc emitJae*(dest: var Buffer; target: LabelId) =
  ## Emit JAE instruction: JAE target (jump if above or equal, unsigned)
  let pos = dest.getCurrentPosition()
  dest.add(0x0F)
  dest.add(0x83)
  dest.addInt32(0)  # Placeholder, will be filled during optimization
  dest.addJump(pos, target, jtJae, 6)  # 2 bytes opcode + 4 bytes displacement

proc emitJbe*(dest: var Buffer; target: LabelId) =
  ## Emit JBE instruction: JBE target (jump if below or equal, unsigned)
  let pos = dest.getCurrentPosition()
  dest.add(0x0F)
  dest.add(0x86)
  dest.addInt32(0)  # Placeholder, will be filled during optimization
  dest.addJump(pos, target, jtJbe, 6)  # 2 bytes opcode + 4 bytes displacement

proc emitJmpReg*(dest: var Buffer; reg: Register) =
  ## Emit JMP instruction: JMP reg (indirect jump)
  var rex = RexPrefix()

  if needsRex(reg): rex.b = true

  if rex.b:
    dest.add(encodeRex(rex))

  dest.add(0xFF)  # JMP r/m64 opcode
  dest.add(encodeModRM(amDirect, 4, int(reg)))  # /4 extension

# Bit manipulation instructions
proc emitAnd*(dest: var Buffer; a, b: Register) =
  ## Emit AND instruction: AND a, b
  var rex = RexPrefix(w: true)

  if needsRex(a): rex.r = true
  if needsRex(b): rex.b = true

  if rex.r or rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x21)  # AND r/m64, r64 opcode
  dest.add(encodeModRM(amDirect, int(a), int(b)))

proc emitOr*(dest: var Buffer; a, b: Register) =
  ## Emit OR instruction: OR a, b
  var rex = RexPrefix(w: true)

  if needsRex(a): rex.r = true
  if needsRex(b): rex.b = true

  if rex.r or rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x09)  # OR r/m64, r64 opcode
  dest.add(encodeModRM(amDirect, int(a), int(b)))

proc emitXor*(dest: var Buffer; a, b: Register) =
  ## Emit XOR instruction: XOR a, b
  var rex = RexPrefix(w: true)

  if needsRex(a): rex.r = true
  if needsRex(b): rex.b = true

  if rex.r or rex.b or rex.w:
    dest.add(encodeRex(rex))

  dest.add(0x31)  # XOR r/m64, r64 opcode
  dest.add(encodeModRM(amDirect, int(a), int(b)))

# Atomic arithmetic operations
proc emitAddAtomic*(dest: var Buffer; a, b: Register) =
  ## Emit atomic ADD instruction: LOCK ADD a, b (atomic add)
  dest.emitLock()
  dest.emitAdd(a, b)

proc emitSubAtomic*(dest: var Buffer; a, b: Register) =
  ## Emit atomic SUB instruction: LOCK SUB a, b (atomic subtract)
  dest.emitLock()
  dest.emitSub(a, b)

proc emitAndAtomic*(dest: var Buffer; a, b: Register) =
  ## Emit atomic AND instruction: LOCK AND a, b (atomic and)
  dest.emitLock()
  dest.emitAnd(a, b)

proc emitOrAtomic*(dest: var Buffer; a, b: Register) =
  ## Emit atomic OR instruction: LOCK OR a, b (atomic or)
  dest.emitLock()
  dest.emitOr(a, b)

proc emitXorAtomic*(dest: var Buffer; a, b: Register) =
  ## Emit atomic XOR instruction: LOCK XOR a, b (atomic xor)
  dest.emitLock()
  dest.emitXor(a, b)

# Atomic increment and decrement
proc emitIncAtomic*(dest: var Buffer; reg: Register) =
  ## Emit atomic INC instruction: LOCK INC reg (atomic increment)
  dest.emitLock()
  dest.emitInc(reg)

proc emitDecAtomic*(dest: var Buffer; reg: Register) =
  ## Emit atomic DEC instruction: LOCK DEC reg (atomic decrement)
  dest.emitLock()
  dest.emitDec(reg)

# System instructions
proc emitSyscall*(dest: var Buffer) =
  ## Emit SYSCALL instruction
  dest.add(0x0F)
  dest.add(0x05)

# NOP instruction
proc emitNop*(dest: var Buffer) =
  ## Emit NOP instruction
  dest.add(0x90)

# Jump optimization functions
proc updateJumpDisplacements*(buf: var Buffer) =
  ## Update all jump displacements based on current label positions
  for jump in buf.jumps:
    let currentPos = jump.position
    let targetPos = buf.getLabelPosition(jump.target)
    let distance = calculateJumpDistance(currentPos, targetPos, jump.instruction)

    # Convert to signed 32-bit for proper encoding
    let signedDistance = int32(distance)

    # Check if we have enough space in the buffer
    let requiredSize = case jump.instruction:
    of jtCall, jtJmp: currentPos + 5
    else: currentPos + 6

    if requiredSize > buf.data.len:
      continue  # Skip this jump if buffer is too small

    # Update the displacement in the instruction
    case jump.instruction:
    of jtCall:
      # CALL uses 32-bit displacement (little-endian)
      buf.data[currentPos + 1] = byte(signedDistance and 0xFF)
      buf.data[currentPos + 2] = byte((signedDistance shr 8) and 0xFF)
      buf.data[currentPos + 3] = byte((signedDistance shr 16) and 0xFF)
      buf.data[currentPos + 4] = byte((signedDistance shr 24) and 0xFF)
    of jtJmp:
      # JMP uses 32-bit displacement (little-endian)
      buf.data[currentPos + 1] = byte(signedDistance and 0xFF)
      buf.data[currentPos + 2] = byte((signedDistance shr 8) and 0xFF)
      buf.data[currentPos + 3] = byte((signedDistance shr 16) and 0xFF)
      buf.data[currentPos + 4] = byte((signedDistance shr 24) and 0xFF)
    else:
      # Conditional jumps use 32-bit displacement (little-endian)
      # Conditional jumps have 2-byte opcode, so displacement starts at +2
      buf.data[currentPos + 2] = byte(signedDistance and 0xFF)
      buf.data[currentPos + 3] = byte((signedDistance shr 8) and 0xFF)
      buf.data[currentPos + 4] = byte((signedDistance shr 16) and 0xFF)
      buf.data[currentPos + 5] = byte((signedDistance shr 24) and 0xFF)

proc optimizeJumps*(buf: Buffer): Buffer =
  ## Optimize all jump instructions by creating a new optimized buffer
  var optimized = initBuffer()

  # Copy all data to new buffer
  optimized.data = buf.data
  optimized.labels = buf.labels
  optimized.jumps = buf.jumps

  # Update all jump displacements in the new buffer
  optimized.updateJumpDisplacements()

  # Try to optimize jumps by creating a new buffer with shorter instructions
  var changed = true
  var iterations = 0
  const maxIterations = 10

  while changed and iterations < maxIterations:
    changed = false
    inc(iterations)

    var newBuf = initBuffer()
    var jumpIndex = 0
    var i = 0

    while i < optimized.data.len:
      # Check if we're at a jump instruction
      if jumpIndex < optimized.jumps.len and optimized.jumps[jumpIndex].position == i:
        let jump = optimized.jumps[jumpIndex]
        let targetPos = optimized.getLabelPosition(jump.target)
        let distance = calculateJumpDistance(i, targetPos, jump.instruction)

        # Check if we can use a short jump
        if canUseShortJump(distance):
          case jump.instruction:
          of jtCall:
            # CALL doesn't have 8-bit form, emit as 32-bit
            newBuf.data.add(0xE8)  # CALL opcode
            newBuf.addInt32(int32(distance))
          of jtJmp:
            # JMP with 8-bit displacement
            newBuf.data.add(0xEB)  # JMP rel8 opcode
            newBuf.data.add(byte(distance and 0xFF))
            changed = true
          else:
            # Conditional jumps with 8-bit displacement
            let shortOpcode = case jump.instruction:
            of jtJe: 0x74
            of jtJne: 0x75
            of jtJg: 0x7F
            of jtJl: 0x7C
            of jtJge: 0x7D
            of jtJle: 0x7E
            of jtJa: 0x77
            of jtJb: 0x72
            of jtJae: 0x73
            of jtJbe: 0x76
            else: 0x74  # Default to JE

            newBuf.data.add(byte(shortOpcode))
            newBuf.data.add(byte(distance and 0xFF))
            changed = true
        else:
          # Use 32-bit displacement
          case jump.instruction:
          of jtCall:
            newBuf.data.add(0xE8)  # CALL opcode
            newBuf.addInt32(int32(distance))
          of jtJmp:
            newBuf.data.add(0xE9)  # JMP rel32 opcode
            newBuf.addInt32(int32(distance))
          else:
            # Conditional jumps with 32-bit displacement
            newBuf.data.add(0x0F)  # Two-byte opcode prefix
            let longOpcode = case jump.instruction:
            of jtJe: 0x84
            of jtJne: 0x85
            of jtJg: 0x8F
            of jtJl: 0x8C
            of jtJge: 0x8D
            of jtJle: 0x8E
            of jtJa: 0x87
            of jtJb: 0x82
            of jtJae: 0x83
            of jtJbe: 0x86
            else: 0x84  # Default to JE
            newBuf.data.add(byte(longOpcode))
            newBuf.addInt32(int32(distance))

        # Skip the original instruction bytes
        let originalSize = case jump.instruction:
        of jtCall, jtJmp: 5
        else: 6
        i += originalSize
        inc(jumpIndex)
      else:
        # Copy non-jump instruction
        newBuf.data.add(optimized.data[i])
        inc(i)

    # Update the optimized buffer
    optimized = newBuf

    # Update jump positions for next iteration
    var pos = 0
    for j in 0..<optimized.jumps.len:
      optimized.jumps[j].position = pos
      let instructionSize = case optimized.jumps[j].instruction:
      of jtCall, jtJmp: 5
      else: 6
      pos += instructionSize

  return optimized

proc finalize*(buf: var Buffer) =
  ## Finalize the buffer by optimizing all jump instructions
  let optimized = buf.optimizeJumps()
  buf = optimized

