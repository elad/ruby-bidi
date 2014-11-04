#!/usr/bin/ruby

# Make a simplified version of the BidiMirroring.txt file, 
# that contains characters value and their mirrored version only.

datFile = File.open("BidiMirroring.dat", 'w');

File.open('BidiMirroring.txt', 'r'){|file|
  file.each_line {|line|
    next if line[0]=='#' or line[0].chr=='#'
    sCIndex=line.index(';');   # Where is the semicolon?
    next if not sCIndex        # No semicolon - skip
    ucode=line[0..sCIndex-1]   # Up to the semicolon is
                               #     the unicode value.
    hexValue=ucode.hex         # The integer value of the code
    keyMask = 0xff0000
    bitsToShift = 16;
    while keyMask > 0 do
      datFile.write ((hexValue & keyMask) >> bitsToShift).chr
      keyMask >>= 8
      bitsToShift -= 8
    end
    mirroredValueString = line[sCIndex + 1..-1]
    mirroredValue=mirroredValueString.hex
    mirroedValueMask = 0xff0000
    bitsToShift = 16
    while mirroedValueMask > 0 do
      datFile.write ((mirroredValue & mirroedValueMask) >> bitsToShift).chr
      mirroedValueMask >>= 8
      bitsToShift -= 8
    end
  }
}
datFile.close
