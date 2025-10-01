# ELF Object File Generation with Nifasm

## Overview

Nifasm supports generating complete ELF (.o) object files that are compatible with GCC and other standard linkers. This allows you to create object files that can be linked with other code to produce executables or libraries.

## Key Features

### ✅ **Complete ELF Support**
- **ELF64 Headers**: Proper ELF64 header generation for x86_64
- **Section Management**: Support for .text, .data, .bss, .symtab, .strtab sections
- **Symbol Tables**: Full symbol table with string names for linking
- **Relocations**: Relocation entries for external symbol references
- **String Tables**: Proper string table management for symbol names

### ✅ **Symbol Management**
- **String-based symbols**: Use regular strings for symbol names
- **Global/Local binding**: Support for different symbol binding types
- **Function/Object types**: Different symbol types (functions, variables, etc.)
- **External references**: Support for undefined symbols for linking

### ✅ **Section Support**
- **.text**: Executable code section
- **.data**: Initialized data section
- **.bss**: Uninitialized data section
- **.symtab**: Symbol table
- **.strtab**: String table
- **.rela.text**: Relocation table for text section

## API Reference

### Symbol Management

```nim
# Add a global function symbol
buf.addSymbol("my_function", value=0, size=0, sbGlobal, stFunc, defined=true)

# Add an external function reference
buf.addSymbol("printf", value=0, size=0, sbGlobal, stFunc, defined=false)

# Add a global variable
buf.addSymbol("global_var", value=0, size=8, sbGlobal, stObject, defined=true)

# Check if symbol exists
if buf.hasSymbol("my_function"):
  let sym = buf.getSymbol("my_function")
```

### Section Management

```nim
# Add a new section
buf.addSection(".mydata", stProgbits, alignment=4)

# Add data to a section
buf.addToSection(".data", @[0x48.byte, 0x65, 0x6C, 0x6C, 0x6F]) # "Hello"

# Check if section exists
if buf.hasSection(".text"):
  let sec = buf.getSection(".text")
```

### Relocation Management

```nim
# Add a relocation for external symbol reference
buf.addRelocation(offset=5, symbol="printf", rtRipRel32, addend=-4)

# Add absolute relocation
buf.addRelocation(offset=10, symbol="global_var", rtAbs64, addend=0)
```

### Object File Generation

```nim
# Generate complete ELF object file
let objectFile = buf.generateObjectFile()

# Write to disk
let file = newFileStream("output.o", fmWrite)
for b in objectFile:
  file.write(b)
file.close()
```

## Complete Example

```nim
import nifasm
import std/streams

proc createObjectFile() =
  var buf = initBuffer()

  # 1. Add symbols
  buf.addSymbol("main", 0, 0, sbGlobal, stFunc, true)      # Our function
  buf.addSymbol("printf", 0, 0, sbGlobal, stFunc, false)   # External function
  buf.addSymbol("message", 0, 0, sbGlobal, stObject, true) # Our data

  # 2. Generate code in .text section
  let printfLabel = buf.createLabel()

  # Simple main function
  emitMov(buf, RAX, RBX)           # Some operation
  emitCall(buf, printfLabel)       # Call printf
  emitRet(buf)                     # Return

  # Add code to .text section
  buf.addToSection(".text", buf.data)

  # 3. Add data to .data section
  let message = "Hello, World!\0"
  var messageBytes: seq[byte] = @[]
  for c in message:
    messageBytes.add(byte(c))
  buf.addToSection(".data", messageBytes)

  # 4. Add relocations
  buf.addRelocation(5, "printf", rtRipRel32, -4)  # Call instruction relocation

  # 5. Generate object file
  let objectFile = buf.generateObjectFile()

  # 6. Write to disk
  let file = newFileStream("example.o", fmWrite)
  for b in objectFile:
    file.write(b)
  file.close()

  echo "Generated example.o (", objectFile.len, " bytes)"
  echo "Link with: gcc example.o -o example"

when isMainModule:
  createObjectFile()
```

## ELF Structure

The generated object files follow the standard ELF64 format:

```
┌─────────────────┐
│   ELF Header    │  64 bytes
├─────────────────┤
│  .text section  │  Your code
├─────────────────┤
│  .data section  │  Your data
├─────────────────┤
│  .bss section   │  Uninitialized data
├─────────────────┤
│ .symtab section │  Symbol table
├─────────────────┤
│ .strtab section │  String table
├─────────────────┤
│.rela.text sect. │  Relocations
├─────────────────┤
│.shstrtab section│  Section name strings
├─────────────────┤
│ Section Headers │  Section header table
└─────────────────┘
```

## Symbol Types

### Symbol Binding
- `sbLocal` - Local symbols (not visible outside object file)
- `sbGlobal` - Global symbols (visible for linking)
- `sbWeak` - Weak symbols (can be overridden)

### Symbol Types
- `stNotype` - No specific type
- `stObject` - Data object (variable)
- `stFunc` - Function
- `stSection` - Section symbol
- `stFile` - File symbol

## Relocation Types

### x86_64 Relocations
- `rtRipRel32` - RIP-relative 32-bit (for calls, jumps)
- `rtAbs32` - Absolute 32-bit address
- `rtAbs64` - Absolute 64-bit address
- `rtRipRel8` - RIP-relative 8-bit

## Linking with GCC

Once you generate an object file, you can link it with GCC:

```bash
# Link with C runtime
gcc myfile.o -o myprogram

# Link multiple object files
gcc file1.o file2.o -o myprogram

# Link with libraries
gcc myfile.o -lm -o myprogram

# View symbols in object file
objdump -t myfile.o

# View relocations
objdump -r myfile.o

# View sections
objdump -h myfile.o
```

## Advanced Features

### Custom Sections
```nim
# Add custom section
buf.addSection(".myconfig", stProgbits, 8)
buf.addToSection(".myconfig", configData)
```

### Complex Relocations
```nim
# Multiple relocations for same symbol
buf.addRelocation(10, "extern_func", rtRipRel32, -4)
buf.addRelocation(25, "extern_func", rtRipRel32, -4)
```

### String Table Management
```nim
# Add strings to string table
let offset1 = buf.addToStringTable("function_name")
let offset2 = buf.addToStringTable("variable_name")

# Get string offset
let offset = buf.getStringOffset("existing_string")
```

## Debugging and Verification

### Verify Generated Files
```bash
# Check if ELF file is valid
file myfile.o

# View detailed ELF structure
readelf -a myfile.o

# Check symbols
nm myfile.o

# Verify sections
readelf -S myfile.o
```

### Common Issues
1. **Missing relocations**: External symbol references need relocations
2. **Wrong section types**: Use correct section types for different data
3. **Symbol binding**: Make sure symbols have correct binding (global/local)
4. **Alignment**: Some sections need proper alignment

## Integration with Build Systems

### Makefile Example
```makefile
myprogram: myfile.o
	gcc myfile.o -o myprogram

myfile.o: generate_object
	./generate_object

clean:
	rm -f *.o myprogram
```

### CMake Example
```cmake
add_custom_command(
  OUTPUT myfile.o
  COMMAND ./generate_object
  DEPENDS generate_object
)

add_executable(myprogram myfile.o)
```

The ELF object file generation makes Nifasm a complete solution for creating linkable machine code that integrates seamlessly with existing C/C++ toolchains and build systems.
