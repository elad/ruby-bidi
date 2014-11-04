#!/usr/bin/ruby

# Create an index file for the unicode text. The file is sorted by the 
# char unicode value (24 bits). Each record consists of the key and
# position(32 bits).
idxFile = File.open("UnicodeData.idx", 'w');
pos=0
File.open('UnicodeData.txt', 'r'){|file|
  file.each_line {|line|
    sCIndex=line.index(';');   # Where is the semicolon?
    ucode=line[0..sCIndex-1]   # Up to the semicolon is
                               #     the unicode value.
    hexValue=ucode.hex         # The integer value of the code
    keyMask = 0xff0000
    bitsToShift = 16;
    while keyMask > 0 do
      idxFile.write ((hexValue & keyMask) >> bitsToShift).chr
      keyMask >>= 8
      bitsToShift -= 8
    end
    posMask = 0xff000000
    bitsToShift = 24
    while posMask > 0 do
      idxFile.write ((pos & posMask) >> bitsToShift).chr
      posMask >>= 8
      bitsToShift -= 8
    end
    pos = file.pos
  }
}
idxFile.close
