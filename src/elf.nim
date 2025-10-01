# ELF Object File Generation
# Handles ELF64 object file creation and manipulation

# ELF object file structures
type
  Elf64_Addr* = uint64
  Elf64_Off* = uint64
  Elf64_Half* = uint16
  Elf64_Word* = uint32
  Elf64_Sword* = int32
  Elf64_Xword* = uint64
  Elf64_Sxword* = int64
  Elf64_Byte* = uint8

  # ELF header
  Elf64_Ehdr* = object
    e_ident*: array[16, Elf64_Byte]
    e_type*: Elf64_Half
    e_machine*: Elf64_Half
    e_version*: Elf64_Word
    e_entry*: Elf64_Addr
    e_phoff*: Elf64_Off
    e_shoff*: Elf64_Off
    e_flags*: Elf64_Word
    e_ehsize*: Elf64_Half
    e_phentsize*: Elf64_Half
    e_phnum*: Elf64_Half
    e_shentsize*: Elf64_Half
    e_shnum*: Elf64_Half
    e_shstrndx*: Elf64_Half

  # Section header
  Elf64_Shdr* = object
    sh_name*: Elf64_Word
    sh_type*: Elf64_Word
    sh_flags*: Elf64_Xword
    sh_addr*: Elf64_Addr
    sh_offset*: Elf64_Off
    sh_size*: Elf64_Xword
    sh_link*: Elf64_Word
    sh_info*: Elf64_Word
    sh_addralign*: Elf64_Xword
    sh_entsize*: Elf64_Xword

  # Symbol table entry
  Elf64_Sym* = object
    st_name*: Elf64_Word
    st_info*: Elf64_Byte
    st_other*: Elf64_Byte
    st_shndx*: Elf64_Half
    st_value*: Elf64_Addr
    st_size*: Elf64_Xword

  # Relocation entry
  Elf64_Rela* = object
    r_offset*: Elf64_Addr
    r_info*: Elf64_Xword
    r_addend*: Elf64_Sxword

  # Symbol binding types
  SymbolBinding* = enum
    sbLocal = 0
    sbGlobal = 1
    sbWeak = 2

  # Symbol types
  SymbolType* = enum
    stNotype = 0
    stObject = 1
    stFunc = 2
    stSection = 3
    stFile = 4

  # Symbol information
  Symbol* = object
    name*: string
    value*: uint64
    size*: uint64
    section*: int
    binding*: SymbolBinding
    symbolType*: SymbolType
    defined*: bool

  # Section types
  SectionType* = enum
    stNull = 0
    stProgbits = 1
    stSymtab = 2
    stStrtab = 3
    stRela = 4
    stNoBits = 8

  # Section information
  Section* = object
    name*: string
    data*: seq[byte]
    address*: uint64
    alignment*: uint64
    sectionType*: SectionType

  # Relocation types for x86_64
  RelocationType* = enum
    rtRipRel32 = 1      # R_X86_64_PC32
    rtAbs32 = 10        # R_X86_64_32
    rtAbs64 = 2         # R_X86_64_64
    rtRipRel8 = 3       # R_X86_64_PC8
    rtTlsGd = 4         # R_X86_64_TLSGD
    rtTlsLd = 5         # R_X86_64_TLSLD
    rtTlsLdo = 6        # R_X86_64_DTPOFF32
    rtTlsIe = 7         # R_X86_64_GOTTPOFF
    rtTlsLe = 8         # R_X86_64_TPOFF32

  # Relocation information
  Relocation* = object
    offset*: uint64
    symbol*: string
    relType*: RelocationType
    addend*: int64

  # TLS data structures
  TlsSymbol* = object
    name*: string
    size*: uint64
    alignment*: uint64
    binding*: SymbolBinding
    defined*: bool
    offset*: uint64        # Offset within TLS block

  TlsBlock* = object
    name*: string
    symbols*: seq[TlsSymbol]
    size*: uint64
    alignment*: uint64

  # TLS model enumeration
  TlsModel* = enum
    tmGeneralDynamic  # GD - General Dynamic model
    tmLocalDynamic    # LD - Local Dynamic model
    tmInitialExec     # IE - Initial Exec model
    tmLocalExec       # LE - Local Exec model

# Helper functions for writing binary data
proc addUint16*(buf: var seq[byte]; val: uint16) =
  buf.add(byte(val and 0xFF))
  buf.add(byte((val shr 8) and 0xFF))

proc addUint32*(buf: var seq[byte]; val: uint32) =
  buf.add(byte(val and 0xFF))
  buf.add(byte((val shr 8) and 0xFF))
  buf.add(byte((val shr 16) and 0xFF))
  buf.add(byte((val shr 24) and 0xFF))

proc addUint64*(buf: var seq[byte]; val: uint64) =
  buf.add(byte(val and 0xFF))
  buf.add(byte((val shr 8) and 0xFF))
  buf.add(byte((val shr 16) and 0xFF))
  buf.add(byte((val shr 24) and 0xFF))
  buf.add(byte((val shr 32) and 0xFF))
  buf.add(byte((val shr 40) and 0xFF))
  buf.add(byte((val shr 48) and 0xFF))
  buf.add(byte((val shr 56) and 0xFF))

# ELF object file generation
proc createElfHeader*(): Elf64_Ehdr =
  ## Create a standard ELF64 header for x86_64 object files
  result = Elf64_Ehdr()

  # ELF magic number
  result.e_ident[0] = 0x7F.byte
  result.e_ident[1] = 'E'.byte
  result.e_ident[2] = 'L'.byte
  result.e_ident[3] = 'F'.byte
  result.e_ident[4] = 2.byte  # ELFCLASS64
  result.e_ident[5] = 1.byte  # ELFDATA2LSB
  result.e_ident[6] = 1.byte  # EV_CURRENT
  result.e_ident[7] = 0.byte  # ELFOSABI_SYSV
  result.e_ident[8] = 0.byte  # ABI version
  for i in 9..15:
    result.e_ident[i] = 0.byte

  result.e_type = 1      # ET_REL (relocatable file)
  result.e_machine = 62  # EM_X86_64
  result.e_version = 1   # EV_CURRENT
  result.e_entry = 0     # No entry point for object files
  result.e_phoff = 0    # No program headers
  result.e_flags = 0
  result.e_ehsize = 64  # Size of ELF header
  result.e_phentsize = 0
  result.e_phnum = 0
  result.e_shentsize = 64 # Size of section header
  result.e_shnum = 0    # Will be set later
  result.e_shstrndx = 0  # Will be set later

proc createSectionHeader*(name: string; sectionType: SectionType; flags: uint64;
                        size: uint64; offset: uint64; link: uint32 = 0;
                        info: uint32 = 0; alignment: uint64 = 1): Elf64_Shdr =
  ## Create a section header
  result = Elf64_Shdr()
  result.sh_name = 0  # Will be set later from string table
  result.sh_type = uint32(sectionType)
  result.sh_flags = flags
  result.sh_addr = 0
  result.sh_offset = offset
  result.sh_size = size
  result.sh_link = link
  result.sh_info = info
  result.sh_addralign = alignment
  result.sh_entsize = 0

proc createSymbolEntry*(name: string; value: uint64; size: uint64;
                       binding: SymbolBinding; symbolType: SymbolType;
                       section: int; defined: bool): Elf64_Sym =
  ## Create a symbol table entry
  result = Elf64_Sym()
  result.st_name = 0  # Will be set later from string table
  result.st_info = (uint8(binding) shl 4) or uint8(symbolType)
  result.st_other = 0
  result.st_shndx = if defined: uint16(section) else: 0
  result.st_value = value
  result.st_size = size

proc createRelocationEntry*(offset: uint64; symbolIndex: uint32;
                          relType: RelocationType; addend: int64): Elf64_Rela =
  ## Create a relocation entry
  result = Elf64_Rela()
  result.r_offset = offset
  result.r_info = (uint64(symbolIndex) shl 32) or uint64(relType)
  result.r_addend = addend

# Buffer type for ELF operations (needed for generateObjectFile)
type
  Buffer* = object
    data*: seq[byte]
    symbols*: seq[Symbol]   # Symbol table
    sections*: seq[Section] # Section table
    relocations*: seq[Relocation] # Relocation entries
    stringTable*: seq[byte] # String table
    symbolTable*: seq[byte] # Symbol table data
    tlsBlocks*: seq[TlsBlock] # TLS blocks
    tlsSymbols*: seq[TlsSymbol] # TLS symbols

# String table management
proc addToStringTable*(buf: var Buffer; str: string): uint32 =
  ## Add a string to the string table and return its offset
  let offset = uint32(buf.stringTable.len)
  for c in str:
    buf.stringTable.add(byte(c))
  buf.stringTable.add(0.byte) # Null terminator
  return offset

proc getStringOffset*(buf: Buffer; str: string): uint32 =
  ## Get the offset of a string in the string table
  var currentOffset = 0u32
  var currentString = ""

  for i, b in buf.stringTable:
    if b == 0:
      if currentString == str:
        return currentOffset
      currentOffset = uint32(i + 1)
      currentString = ""
    else:
      currentString.add(char(b))

  raise newException(ValueError, "String not found in string table: " & str)

# Section management functions
proc hasSection*(buf: Buffer; name: string): bool =
  ## Check if a section exists
  for sec in buf.sections:
    if sec.name == name:
      return true
  return false

proc addSection*(buf: var Buffer; name: string; sectionType: SectionType = stProgbits;
                 alignment: uint64 = 1) =
  ## Add a section to the section table
  buf.sections.add(Section(
    name: name,
    data: @[],
    address: 0,
    alignment: alignment,
    sectionType: sectionType
  ))

proc addToSection*(buf: var Buffer; sectionName: string; data: seq[byte]) =
  ## Add data to a section. Creates the section if it doesn't exist.
  for i, sec in buf.sections:
    if sec.name == sectionName:
      buf.sections[i].data.add(data)
      return

  # Section doesn't exist, create it
  buf.addSection(sectionName)
  buf.sections[^1].data.add(data)

# Symbol management functions
proc addSymbol*(buf: var Buffer; name: string; value: uint64 = 0; size: uint64 = 0;
                binding: SymbolBinding = sbGlobal; symbolType: SymbolType = stFunc;
                defined: bool = true) =
  ## Add a symbol to the symbol table
  buf.symbols.add(Symbol(
    name: name,
    value: value,
    size: size,
    section: 1, # Default to .text section
    binding: binding,
    symbolType: symbolType,
    defined: defined
  ))

proc getSymbol*(buf: Buffer; name: string): Symbol =
  ## Get a symbol by name
  for sym in buf.symbols:
    if sym.name == name:
      return sym
  raise newException(ValueError, "Symbol not found: " & name)

proc hasSymbol*(buf: Buffer; name: string): bool =
  ## Check if a symbol exists
  for sym in buf.symbols:
    if sym.name == name:
      return true
  return false

# Relocation management functions
proc addRelocation*(buf: var Buffer; offset: uint64; symbol: string;
                   relType: RelocationType; addend: int64 = 0) =
  ## Add a relocation entry
  buf.relocations.add(Relocation(
    offset: offset,
    symbol: symbol,
    relType: relType,
    addend: addend
  ))

# TLS management functions
proc addTlsBlock*(buf: var Buffer; name: string; alignment: uint64 = 1) =
  ## Add a TLS block for thread-local storage
  buf.tlsBlocks.add(TlsBlock(
    name: name,
    symbols: @[],
    size: 0,
    alignment: alignment
  ))

proc addTlsSymbol*(buf: var Buffer; name: string; size: uint64; alignment: uint64 = 1;
                  binding: SymbolBinding = sbGlobal; defined: bool = true) =
  ## Add a TLS symbol to the current TLS block
  let tlsSymbol = TlsSymbol(
    name: name,
    size: size,
    alignment: alignment,
    binding: binding,
    defined: defined,
    offset: 0  # Will be calculated later
  )

  buf.tlsSymbols.add(tlsSymbol)

  # Add to symbol table with TLS binding
  buf.addSymbol(name, 0, size, binding, stObject, defined)

proc getTlsSymbol*(buf: Buffer; name: string): TlsSymbol =
  ## Get a TLS symbol by name
  for sym in buf.tlsSymbols:
    if sym.name == name:
      return sym
  raise newException(ValueError, "TLS symbol not found: " & name)

proc hasTlsSymbol*(buf: Buffer; name: string): bool =
  ## Check if a TLS symbol exists
  for sym in buf.tlsSymbols:
    if sym.name == name:
      return true
  return false

proc generateObjectFile*(buf: var Buffer): seq[byte] =
  ## Generate a complete ELF object file from the buffer
  var objectFile: seq[byte] = @[]

  # Ensure we have standard sections
  if not buf.hasSection(".text"):
    buf.addSection(".text", stProgbits, 16)
  if not buf.hasSection(".data"):
    buf.addSection(".data", stProgbits, 1)
  if not buf.hasSection(".bss"):
    buf.addSection(".bss", stNoBits, 1)

  # Add TLS sections if we have TLS symbols
  if buf.tlsSymbols.len > 0:
    if not buf.hasSection(".tdata"):
      buf.addSection(".tdata", stProgbits, 1)  # TLS initialized data
    if not buf.hasSection(".tbss"):
      buf.addSection(".tbss", stNoBits, 1)    # TLS uninitialized data

  # Add string table section
  buf.addSection(".strtab", stStrtab, 1)
  buf.addSection(".shstrtab", stStrtab, 1)

  # Add symbol table section
  buf.addSection(".symtab", stSymtab, 8)

  # Add relocation sections
  buf.addSection(".rela.text", stRela, 8)

  # Build string tables
  var shstrtab: seq[byte] = @[0.byte]  # Start with null terminator
  var strtab: seq[byte] = @[0.byte]   # Start with null terminator

  # Add section names to shstrtab
  var sectionNameOffsets: seq[uint32] = @[]
  for sec in buf.sections:
    sectionNameOffsets.add(uint32(shstrtab.len))
    for c in sec.name:
      shstrtab.add(byte(c))
    shstrtab.add(0.byte)  # Null terminator

  # Add symbol names to strtab
  var symbolNameOffsets: seq[uint32] = @[]
  for sym in buf.symbols:
    symbolNameOffsets.add(uint32(strtab.len))
    for c in sym.name:
      strtab.add(byte(c))
    strtab.add(0.byte)  # Null terminator

  # Find section indices for linking and update symbol section indices
  var strtabIndex = 0u32
  var symtabIndex = 0u32
  var textIndex = 0u32
  for i, sec in buf.sections:
    if sec.name == ".strtab":
      strtabIndex = uint32(i + 1)  # +1 for null section header
    elif sec.name == ".symtab":
      symtabIndex = uint32(i + 1)  # +1 for null section header
    elif sec.name == ".text":
      textIndex = uint32(i + 1)  # +1 for null section header

  # Update symbol section indices to point to correct sections
  for i, sym in buf.symbols:
    if sym.symbolType == stFunc:
      # Function symbols should point to .text section
      buf.symbols[i].section = int(textIndex - 1)  # Convert back to 0-based index
    elif sym.symbolType == stObject:
      # Object symbols should point to .data section
      for j, sec in buf.sections:
        if sec.name == ".data":
          buf.symbols[i].section = j
          break

  # Create symbol table entries
  var symtab: seq[byte] = @[]

  # Add symbol entries
  for i, sym in buf.symbols:
    symtab.addUint32(symbolNameOffsets[i])  # st_name
    symtab.add(byte((uint8(sym.binding) shl 4) or uint8(sym.symbolType)))  # st_info
    symtab.add(0.byte)  # st_other
    symtab.addUint16(if sym.defined: uint16(sym.section + 1) else: 0)  # st_shndx
    symtab.addUint64(sym.value)  # st_value
    symtab.addUint64(sym.size)   # st_size

  # Update section data with string tables and symbol table
  for i, sec in buf.sections:
    if sec.name == ".shstrtab":
      buf.sections[i].data = shstrtab
    elif sec.name == ".strtab":
      buf.sections[i].data = strtab
    elif sec.name == ".symtab":
      buf.sections[i].data = symtab

  # Calculate section offsets
  var currentOffset = 64u64  # Start after ELF header

  # Update section offsets
  for i, sec in buf.sections:
    buf.sections[i].address = currentOffset
    currentOffset += uint64(sec.data.len)

  # Find the .shstrtab section index
  var shstrtabIndex = 0u16
  for i, sec in buf.sections:
    if sec.name == ".shstrtab":
      shstrtabIndex = uint16(i + 1)  # +1 because of null section header
      break

  # Create ELF header
  var elfHeader = createElfHeader()
  elfHeader.e_shoff = currentOffset
  elfHeader.e_shnum = uint16(buf.sections.len + 1) # +1 for null section
  elfHeader.e_shstrndx = shstrtabIndex

  # Write ELF header
  objectFile.add(elfHeader.e_ident)
  objectFile.addUint16(elfHeader.e_type)
  objectFile.addUint16(elfHeader.e_machine)
  objectFile.addUint32(elfHeader.e_version)
  objectFile.addUint64(elfHeader.e_entry)
  objectFile.addUint64(elfHeader.e_phoff)
  objectFile.addUint64(elfHeader.e_shoff)
  objectFile.addUint32(elfHeader.e_flags)
  objectFile.addUint16(elfHeader.e_ehsize)
  objectFile.addUint16(elfHeader.e_phentsize)
  objectFile.addUint16(elfHeader.e_phnum)
  objectFile.addUint16(elfHeader.e_shentsize)
  objectFile.addUint16(elfHeader.e_shnum)
  objectFile.addUint16(elfHeader.e_shstrndx)

  # Write section data
  for sec in buf.sections:
    objectFile.add(sec.data)

  # Create section headers
  var sectionHeaders: seq[Elf64_Shdr] = @[]

  # Null section header
  sectionHeaders.add(createSectionHeader("", stNull, 0, 0, 0))


  # Section headers for each section
  for i, sec in buf.sections:
    let flags = case sec.name:
    of ".text": 0x6u64  # SHF_ALLOC | SHF_EXECINSTR
    of ".data": 0x3u64  # SHF_ALLOC | SHF_WRITE
    of ".bss": 0x3u64   # SHF_ALLOC | SHF_WRITE
    else: 0u64

    var shdr = createSectionHeader(
      sec.name, sec.sectionType, flags,
      uint64(sec.data.len), sec.address, 0, 0, sec.alignment
    )
    # Set the name offset in the string table
    shdr.sh_name = sectionNameOffsets[i]

    # Set section-specific information
    if sec.name == ".symtab":
      shdr.sh_link = strtabIndex
      shdr.sh_info = 0  # Number of local symbols (we don't have any)
      shdr.sh_entsize = 24  # Size of Elf64_Sym
    elif sec.name == ".strtab":
      shdr.sh_entsize = 0
    elif sec.name == ".shstrtab":
      shdr.sh_entsize = 0
    elif sec.name == ".rela.text":
      shdr.sh_link = symtabIndex
      shdr.sh_info = textIndex
      shdr.sh_entsize = 24  # Size of Elf64_Rela

    sectionHeaders.add(shdr)

  # Write section headers
  for shdr in sectionHeaders:
    objectFile.addUint32(shdr.sh_name)
    objectFile.addUint32(shdr.sh_type)
    objectFile.addUint64(shdr.sh_flags)
    objectFile.addUint64(shdr.sh_addr)
    objectFile.addUint64(shdr.sh_offset)
    objectFile.addUint64(shdr.sh_size)
    objectFile.addUint32(shdr.sh_link)
    objectFile.addUint32(shdr.sh_info)
    objectFile.addUint64(shdr.sh_addralign)
    objectFile.addUint64(shdr.sh_entsize)

  return objectFile
