#!/usr/bin/ruby

require 'bidi/weakhashmap'

class Integer
  def to_utf8_char
    raise RangeError "Value #{self} is out of range for UTF8 Char" if self<0 or self > 0x10fffd
    if self >> 7 == 0  # less than 0x80? If so, return an ASCII char
      return self.chr
    end
    prefix = 0x80      # First UTF-8 byte, the initial value of the 
                       # prefix is 110b
    temp = self
    byte_arr=Array.new
    bytes_to_shift=0
    rem_digits = 6
    while true
      rest=temp >> rem_digits
      rem_digits -= 1
      if rest == 0
        byte_arr.push prefix | temp
        break
      else
        byte_arr.push 0x80 | (temp & 0x3f)
        temp >>= 6
        prefix >>= 1
        prefix |= 0x80
      end
    end
    last_pos=byte_arr.length - 1
    ret_value=String.new
    last_pos.downto 0 do |i|
      ret_value << byte_arr[i].chr
    end
    ret_value.force_encoding 'UTF-8'
  end
end

$weakHashMap = WeakHashMap.new
$mirrorMap = WeakHashMap.new

class StringError < Exception
  def initialize byte, afterString
    @byte=byte
    @afterString=afterString
  end
  def message
    'Unexpected byte(s): ' + byte + ' after \'' + afterString + '\''
  end
end

class Bidi
  # constants
  def Bidi.RLE
    0x202b.to_utf8_char
  end

  def Bidi.LRE
    0x202a.to_utf8_char
  end

  def Bidi.RLO
    0x202e.to_utf8_char
  end

  def Bidi.LRO
    0x202d.to_utf8_char
  end

  def Bidi.LRM
    0x200e.to_utf8_char
  end

  def Bidi.RLM
    0x200f.to_utf8_char
  end

  def Bidi.PDF
    0x202c.to_utf8_char
  end

  class ParagraphType < Hash
    def initialize default_direction=nil
      upcase_default_direction = default_direction.upcase if default_direction
      case upcase_default_direction
        when 'R', 'RTL'
          self['level']=1
        when 'L', 'LTR'
          self['level']=0
        else
          self['level']=-1 
      end
      self['characters']=Array.new
    end
  end

  class UtfChar < Hash
    def initialize value, bidiType, mirroredInd
      self['value']=value
      self['bidiType']=bidiType
      self['mirroredInd']=mirroredInd
    end

    def is_neutral
      bidiType = self["bidiType"]
      bidiType == 'B' or bidiType == 'S' or bidiType == 'WS' or bidiType == 'ON'
    end
  end

  CHAR_START=1
  CHAR_END=2
  CHAR_BEFORE_LAST=3
  CHAR_SECOND_OF_FOUR=4

  def initialize
    @@idx_record_len=7
    @dataPath = Gem.loaded_specs["bidi"].full_gem_path + "/lib/data/";
    @idxFile = File.open(@dataPath + "UnicodeData.idx", "r");
    @dataFile = File.open(@dataPath + "UnicodeData.txt", "r");
    @mirrorFile = File.open(@dataPath + "BidiMirroring.dat", "r");
    ObjectSpace.define_finalizer(self, proc {@idxFile.close; @dataFile.close; @mirrorFile.close})
    @num_of_indexes =  @idxFile.stat.size / @@idx_record_len
    @mirror_record_len=6
    @num_of_mirror_chars=@mirrorFile.stat.size / @mirror_record_len
  end # initialize

  def retrieve_rec key
    value = $weakHashMap[key]
    return value if value

    # Binary search of the key
    bottom=0
    top = @num_of_indexes
    while (top >= bottom) do
      middle = (top + bottom) / 2
      addr = middle * @@idx_record_len
      @idxFile.pos=addr
      str=@idxFile.read 3
      intValue=0;
      str.each_byte do |b|
        intValue <<= 8
        intValue |= b
      end # each
      if intValue == key      # Found - read the record
        str=@idxFile.read 4
        dataPos = 0
        str.each_byte do |b|
          dataPos <<= 8
          dataPos |= b
        end # each
        @dataFile.pos=dataPos
        record=@dataFile.readline
        arr=record.split ';', -1
        $weakHashMap[key]=arr
        return arr
      end # if
      if key < intValue
        top = middle - 1
      else
        bottom = middle + 1
      end # if
    end
    nil
  end

  # Run = run of characters of the same level
  def split_into_runs par
    sor=0
    sor_level=par['level']
    run = Hash.new
    run['sor']=sor
    chars=par['characters']
    len=chars.length
    par['runs']=Array.new
    0.upto(len - 1) do |index|
      char=chars[index]
      next unless char['level']
       if char['level'] != sor_level
         run['sor']=sor
         run['sorType']=chars[sor]['level'].odd? ? 'R' : 'L'
         run['eor']=index
         run['eorType']=chars[index]['level'].odd? ? 'R' : 'L'
         sor=index
         par['runs'].push run
         run=Hash.new
         sor_level=char['level']
       end
    end # upto
    run['sor']=sor
    run['sorType']=chars[sor]['level'].odd? ? 'R' : 'L'
    run['eor']=len
    run['eorType']=par['level'].odd? ? 'R' : 'L'
    par['runs'].push run
  end

  # Determine the direction ('L', 'R') of the nonspacing mark
  # and a little bit of European Number handling
  def resolve_nsm par, run
    previous_direction = run['sorType']
    sor=run['sor']
    eor_m1=run['eor'] - 1
    chars=par['characters']
    sor.upto eor_m1 do |ind|
      case chars[ind]['bidiType']
        when 'NSM'
          chars[ind]['bidiType']=previous_direction
          chars[ind]['origType']='NSM'
        when 'L','R', 'AL'
          previous_direction=chars[ind]['bidiType']
        when 'EN'
          chars[ind]['bidiType']='AN' if previous_direction=='AL'
      end
    end
  end

  # Change the AL bidiType to R
  def change_AL_to_R par, run
    sor=run['sor']
    eor_m1=run['eor'] - 1
    chars=par['characters']
    sor.upto eor_m1 do |ind|
      chars[ind]['bidiType']='R' if chars[ind]['bidiType']=='AL'
    end
  end

  # 'ES' between two 'EN's' is change to EN
  # 'CS' between two numbers of the same type is changed to that
  #      type.
  def handle_cs_and_es par, run
    sor=run['sor']
    eor_m1=run['eor'] - 1
    chars=par['characters']
    sor.upto eor_m1 do |ind|
      case chars[ind]['bidiType']
        when 'ES'
          before_sep = ind>sor ? chars[ind-1]['bidiType'] : nil
          after_sep = ind<eor_m1 ? chars[ind+1]['bidiType'] : nil
          if (before_sep == 'EN' and after_sep=='EN')
            chars[ind]['bidiType']='EN'
          else
            chars[ind]['bidiType']='ON'
          end
        when 'CS'
          before_sep = ind>sor ? chars[ind-1]['bidiType'] : nil
          after_sep = ind<eor_m1 ? chars[ind+1]['bidiType'] : nil
          if (before_sep == 'EN' and after_sep=='EN')
            chars[ind]['bidiType']='EN'
          else if (before_sep == 'AN' and after_sep=='AN')
              chars[ind]['bidiType']='AN'
            else
              chars[ind]['bidiType']='ON'
            end
          end # if
      end # case
    end # upto
  end

  def handle_en_et_sequences par, run
    sOTHERS=0
    sET_FOUND=1
    sEN_FOUND=2
    state=sOTHERS
    sor=run['sor']
    eor_m1=run['eor'] - 1
    seq_start=nil
    seq_end=nil
    chars=par['characters']
    sor.upto eor_m1 do |ind|
      case state
        when sOTHERS
          case chars[ind]['bidiType']
            when 'EN'
              state=sEN_FOUND
              seq_start = seq_end = ind
            when 'ET'
              state=sET_FOUND
              seq_start = seq_end = ind
          end
        when sET_FOUND
          case chars[ind]['bidiType']
            when 'EN'
              state=sEN_FOUND
              seq_end = ind
            when 'ET'
              seq_end = ind
            else
              seq_start.upto seq_end do |ind1|
                chars[ind1]['bidiType']='ON'
              end
              seq_start = seq_end = nil
              state=sOTHERS
          end
        when sEN_FOUND
          case chars[ind]['bidiType']
            when 'EN', 'ET'
              seq_end = ind
            else
              seq_start.upto seq_end do |ind1|
                chars[ind1]['bidiType']='EN'
              end
              seq_start = seq_end = nil
              state=sOTHERS
          end
      end
    end
  end

  def resolve_neutral_types par, run
    sNO_N_FOUND=0
    sN_FOUND=1
    start_direction=run['sorType']
    sor=run['sor']
    eor_m1=run['eor']-1
    chars=par['characters']
    seq_start=0
    seq_end=-1
    state=sNO_N_FOUND
    sor.upto eor_m1 do |ind|
      type=chars[ind]['bidiType']
      case type
        when 'R','AN','EN'
          l_or_r='R'
        when 'L'
          l_or_r='L'
        else
          l_or_r=nil
      end #case

      case state
        when sNO_N_FOUND
          if chars[ind].is_neutral
            seq_start=seq_end=ind
            state=sN_FOUND
          else
            start_direction=l_or_r
          end
        when sN_FOUND
          if l_or_r or ind=eor_m1
            end_direction=l_or_r ? l_or_r : run['eorType']
            change_n_to=start_direction==end_direction ? end_direction : nil
            seq_start.upto seq_end  do |ind1|
              if chars[ind1].is_neutral
                if change_n_to
                  chars[ind1]['bidiType']=change_n_to
                else
                  chars[ind1]['bidiType']=chars[ind1]['level'].odd? ? 'R' : 'L'
                end
              end
            end
            state=sNO_N_FOUND
          else
            if chars[ind].is_neutral
              seq_end=ind
            end
          end
      end
    end
  end

  # Change each character's level according to its embedding level
  # and bidiType.
  def resolve_implicit_levels par
    par['characters'].each {|char|
      embedding_level=char['level']
      bidiType=char['bidiType']
      case bidiType
        when 'L'
          char['level']=embedding_level + 1 if embedding_level.odd?
        when 'R'
          char['level']=embedding_level + 1 if embedding_level.even?
        when 'AN','EN'
          char['level']=embedding_level + (embedding_level.odd? ? 1 : 2)
      end
      char['level']=0 if char['value']==0x0A or char['value']==0x0D
    }
  end

  # Reset the embedding level of paragraph and segment separators
  # to the paragraph level. Do the same with spaces preceding them
  def reset_separator_levels par
    paragraph_level=par['level']
    chars=par['characters']
    len=chars.length
    before_sep=true
    (len-1).downto 0 do |ind|
      char=chars[ind]
      if char['bidiType']=='B' or char['bidiType']=='S'
        before_sep=true
        char['level']=paragraph_level
        next
      end
      char['level']=paragraph_level if char['bidiType']=='WS' and before_sep
      before_sep = false if char['bidiType'] != 'WS'
    end
  end


  def resolve_weak_types par
    runs = par['runs']
    runs.each do |run|
      resolve_nsm par, run
      change_AL_to_R par, run
      handle_cs_and_es par, run
      handle_en_et_sequences par, run
      resolve_neutral_types par, run
      par.delete 'runs'
      resolve_implicit_levels par
      reset_separator_levels par
    end #each
  end

  #
  # Reverse odd levels (i.e. levels of characters written right-to-left
  #
  def reverse_rtl_chars par
    min_odd_level = max_level = nil
    levels = Hash.new      # Where I want to store info about the level
    chars=par['characters']
    last=chars.length - 1
    0.upto last do |ind|
      char=chars[ind]
      level=char['level']
      min_odd_level = level if level.odd? && (!min_odd_level or level<min_odd_level)
      max_level=level if !max_level or level>max_level
      if !levels[level] then
        hsh = levels[level] = Hash.new
        hsh['start']=ind
      else
        hsh = levels[level]
      end
      hsh['end']=ind
    end # upto
    return unless min_odd_level

    done=false
    cur_lvl=max_level
    while !done do
      lvl=cur_lvl - 1
      if cur_lvl > min_odd_level then
        while !levels[lvl] do
          lvl -= 1
        end
      end
      hsh_cur=levels[cur_lvl]
      if lvl >= min_odd_level
        hsh_low=levels[lvl]
        hsh_low['start'] = hsh_cur['start'] if hsh_cur['start'] < hsh_low['start']
        hsh_low['end'] = hsh_cur['end'] if hsh_cur['end'] > hsh_low['end']
      end
      if (cur_lvl==min_odd_level) or (lvl.odd? != cur_lvl.odd?)
         rearrange_level par, cur_lvl, hsh_cur
      end

      done=true if cur_lvl == min_odd_level
      cur_lvl=lvl
    end
  end


  def handle_paragraph par
    par['level']=0 if par['level']==-1 
    embedding_level = par['level']
    override_status=nil
    level_stack=Array.new
    invalid_level_changes=0
    par['characters'].each do |char|
      bidi_type=char['bidiType']
      case bidi_type
        #--------------------#
        # Explicit Embedding #
        #--------------------#
        when 'RLE'
          next_odd = embedding_level + (embedding_level.odd? ? 2 : 1) 
          if (next_odd <= 61)
            hsh=Hash.new
            hsh['level']=embedding_level
            hsh['override_status']=override_status
            embedding_level = next_odd
            override_status=nil
            level_stack.push hsh
          else
            invalid_level_changes += 1
          end
        when 'LRE'
          next_even = embedding_level + (embedding_level.even? ? 2 : 1) 
          if (next_even <= 61)
            hsh=Hash.new
            hsh['level']=embedding_level
            hsh['override_status']=override_status
            embedding_level = next_even
            override_status=nil
            level_stack.push hsh
          else
            invalid_level_changes += 1
          end
        #-------------------#
        # Explicit Override #
        #-------------------#
        when 'RLO'
          next_odd = embedding_level + (embedding_level.odd? ? 2 : 1) 
          if (next_odd <= 61)
            hsh=Hash.new
            hsh['level']=embedding_level
            hsh['override_status']=override_status
            embedding_level = next_odd
            override_status='R'
            level_stack.push hsh
          else
            invalid_level_changes += 1
          end
        when 'LRO'
          next_even = embedding_level + (embedding_level.even? ? 2 : 1) 
          if (next_even <= 61)
            hsh=Hash.new
            hsh['level']=embedding_level
            hsh['override_status']=override_status
            embedding_level = next_even
            override_status='L'
            level_stack.push hsh
          else
            invalid_level_changes += 1
          end
        # PDF - End of embedding/override
        when 'PDF'
          if invalid_level_changes == 0
            hsh = level_stack.pop
            embedding_level=hsh['level']
            override_status = hsh['override_status']
          else
            invalid_level_changes -= 1
          end
        else # of 'case'
          if bidi_type != 'BN'
            char['level']=embedding_level
            char['bidiType']=override_status if override_status
          end
      end # case
    end # each
    par['characters'].delete_if {|char|
      char['bidiType']=='RLE' or
      char['bidiType']=='LRE' or
      char['bidiType']=='RLO' or
      char['bidiType']=='LRO' or
      char['bidiType']=='PDF' or
      char['bidiType']=='BN'
    }
    split_into_runs par
    resolve_weak_types par
    reverse_rtl_chars par
  end # function


  def to_paragraphs default_direction=nil
    ret_value = Array.new
    first_utf8_char=true
    new_par=true
    par=nil
    @valueArray.each do |value|
      if first_utf8_char
        first_utf8_char=false
        new_par=true
        par=ParagraphType.new default_direction
        ret_value.push par
      end
      if value==0x0A or value==0x0D
        # Add new lines to the current paragaph
        par['characters'].push UtfChar.new value, nil, 'N'
        new_par=false
      else
        unless new_par 
          new_par=true
          par=ParagraphType.new default_direction
          ret_value.push par
        end
        rec=retrieve_rec value
        bidiType=rec ? rec[4] : nil
        mirroredInd = rec ? rec[9] : nil
        
        par['characters'].push UtfChar.new value, bidiType, mirroredInd
        if par['level']==-1
          if bidiType=='R' or bidiType=='AL'
            par['level']=1
          else
            par['level']=0 if bidiType=='L'
          end
        end
      end
    end
    ret_value
  end

  def search_mirrored_value key
    bottom=0
    top=@num_of_mirror_chars
    while top>=bottom
      middle=(top + bottom) / 2
      addr=middle * @mirror_record_len
      @mirrorFile.pos=addr
      str=@mirrorFile.read 3
      intValue = 0
      str.each_byte do |byte|
        intValue <<= 8
        intValue |= byte
      end
      if key == intValue
        str=@mirrorFile.read 3
        retValue=0
        str.each_byte do |byte|
          retValue <<= 8
          retValue |= byte
        end
        $mirrorMap[key]=[retValue]
        return retValue
      end
      if key < intValue
        top=middle - 1
      else
        bottom=middle + 1
      end
    end
    key 
  end

  def get_mirrored_value char
    key=char['value']
    ret_value=$mirrorMap[key]
    return ret_value[0] if ret_value
    search_mirrored_value key
  end

  #
  # to_visual - the function that converts a UTF-8 string
  # to visual. 
  #
  # i_string - the input string.
  # default_direction - each paragraph's default direction.
  #   values:
  #      'R', 'RTL' - right to left text.
  #      'L', 'LTR' - left to right text.
  #      Not set, other values - default behaviour.
  #
  def to_visual i_string, default_direction=nil
    @valueArray = Array.new  # Array of values
    state=CHAR_START
    charVal=0;
    handledString=''
    charForError=''
    byteList='q'
    i_string.each_byte do |byte|
      charForError += byte.chr;
      case state
        when CHAR_START
          byteList=byte.to_s
          charVal=byte
          if byte & 0x80 == 0      # regular ASCII
            @valueArray.push byte
            handledString=handledString + charForError
            charForError=''
            next
          end
          if byte & 0xE0 == 0xC0   # Begins with 110b - two bytes
            charVal = byte & 0x1F
            state = CHAR_END
            next
          end
          if byte & 0xF0 == 0xE0   # Begins with 1110b - three bytes
            charVal = byte & 0x0F
            state = CHAR_BEFORE_LAST
            next
          end
          if byte & 0xF8 == 0xF0   # Begins with 11110b - four bytes
            charVal = byte & 0x07
            state = CHAR_SECOND_OF_FOUR
            next
          end
          raise StringError.new byteList, handledstring
        when CHAR_END
          byteList += ', ' + byte.to_s
          if byte & 0xC0 != 0x80   # The byte should begin with 10b
            raise StringError.new byteList, handledstring
          end
          charVal <<= 6
          charVal |= (byte & 0x3F)
          @valueArray. push charVal
          state = CHAR_START
          handledString=handledString + charForError
          charForError=''
        when CHAR_BEFORE_LAST
          byteList += ', ' + byte.to_s
          if byte & 0xC0 != 0x80   # The byte should begin with 10b
            raise StringError.new byteList, handledstring
          end
          charVal <<= 6
          charVal |= (byte & 0x3F)
          state = CHAR_END
        when CHAR_SECOND_OF_FOUR
          byteList += ', ' + byte.to_s
          if byte & 0xC0 != 0x80   # The byte should begin with 10b
            raise StringError.new byteList, handledstring
          end
          charVal <<= 6
          charVal |= (byte & 0x3F)
          state = CHAR_BEFORE_LAST
      end
    end
    # First step - split the text into paragraphs
    paragraphs = to_paragraphs default_direction
    paragraphs.each do |par|
      handle_paragraph par 
    end

    # Now, make a string
    ret_value=''
    paragraphs.each do |par|
      chars=par['characters']
      nsm_stack=Array.new
      chars.each do |char|
        char['value']=get_mirrored_value char if char['mirroredInd']=='Y' and char['level'].odd?
        
        if char['origType']=='NSM' and char['bidiType']=='R'
          nsm_stack.push char['value']
        else
          ret_value += char['value'].to_utf8_char if char['bidiType']=='R'
          ret_value += (nsm_stack.pop).to_utf8_char while not nsm_stack.empty?
          ret_value += char['value'].to_utf8_char if char['bidiType']!='R'
        end
      end
      ret_value += (nsm_stack.pop).to_utf8_char while not nsm_stack.empty?
    end
    
    ret_value
  end


  def rearrange_level par, lvl, hsh_cur
    start=hsh_cur['start']
    end_p1=hsh_cur['end'] + 1
    run_started=false
    forward_index=nil
    start.upto end_p1 do |ind| 
      chars=par['characters']
      char=chars[ind]
      if !run_started and char and char['level']>=lvl
        forward_index=ind
      end
      run_started=true if char and char['level']>=lvl
      if run_started and (ind==end_p1 or char['level']<lvl) then
        backward_index=ind - 1
        interval_length = backward_index - forward_index
        halfway = interval_length / 2
        halfway -= 1 if interval_length.even?
        0.upto halfway do
          temp = chars[forward_index]
          chars[forward_index]=chars[backward_index]
          chars[backward_index] = temp
          forward_index += 1
          backward_index -= 1
        end
        run_started=false
        next 
      end

      
    end
  end
end

