class Character

  attr_reader :char

  def initialize(char)
    @char = char
  end

  def letter?
    @char =~ /[A-Za-z]/
  end

  def lowercase?
    @char =~ /[a-z]/
  end

  def uppercase?
    @char =~ /[A-Z]/
  end

  def space?
    @char == " "
  end

  def cr?
    @char == "\n"
  end

  def period?
    @char == "."
  end

  def symbol?
    !space? && !period? && !cr? && !letter?
  end

  def shift_status
    return nil unless letter?

    lowercase? ? :lowercase : :uppercase
  end

  FIGURES = {
    # ascii - 32
    "!" => 1,
    "\"" => 2,
    "#" => 3,
    "$" => 4,
    "%" => 5,
    "&" => 6,
    "'" => 7,
    "(" => 8,
    ")" => 9,
    "*" => 10,
    "+" => 11,
    "," => 12,
    "-" => 13,
    # ? ascii 63, the one exception char since . is in letters
    "?" => 14, 
    # ascii - 32
    "/" => 15,
  }.merge((0..9).inject({}) {|h, k| h[k.to_s] = k+16; h }).merge(
  {
    ":" => 26,
    ";" => 27,
    # SPACE = 28
    # CR = 29
    # TOGGLE_EXTENDED_MODE = 30
    # TOGGLE_MAIN_MODE = 31
  })

  EXTENDED = {}

  # note this is only the raw value and does not include
  # mode switching, etc.
  def encoded_value
    FIGURES[@char]
  end

  def encodable_symbol?
    FIGURES.keys.include?(@char) ||
      EXTENDED.keys.include?(@char)
  end

end

ALPHABET_OFFSET = 64 # A starts at 65

# letter encoding

NULL = 0
# A-Z 1-26
PERIOD = 27
SPACE = 28
CR = 29
SHIFT = 30
TOGGLE_EXTENDED_MODE = 30
TOGGLE_MAIN_MODE = 31

class Compressor

  def initialize()
    @buffer = ""
    @offset = 0
    @current = 0
  end

  def compress(s)
    s.length.times do |index|
      add(s[index])
    end
    self
  end

  def output
    close
    @buffer
  end

  def close
    return if @offset == 0

    @offset = 0
    @buffer << @current.chr
  end

  def add(s)
    char = s.ord
    shifted_left = char << 3
    if @offset < 3
      # drop in the bits and move our offset
      @current ||= shifted_left >> @offset
      @offset += 5
    elsif @offset == 3
      @current ||= char # no shifting, pop original right into the lower bits
      @buffer << @current.chr
      @offset = 0
    elsif @offset > 3
      back = shifted_left >> @offset
      forw = (shifted_left << (8 - @offset)) && 0xFF
      @current ||= back
      @buffer << @current.chr

      # offset overflows
      @offset = (@offset+5) % 8
      # remainder of our 5 bits ends up in new current
      @current = forw
    end
  end
end

class FiveBit

  MODES = [:letters, :figures, :extended]
  SHIFT_MODE = [:once, :locked, :off]
  SHIFT_STATUSES = [:uppercase, :lowercase] 

  attr_reader :counts

  def initialize()
    @data = ""
    @mode = :letters
    @shift_mode = :off
    @shift_status = :lowercase

    @counts = Hash.new(0)
  end

  def encoded
    Compressor.new.compress(@data).output
  end

  def buffer
    @data
  end

  def encode(s)
    s.length.times do |index|
      encode_character s[index], context: s[index+1..index+2]
    end
  end

  def encode_character(s, context: nil)
    char = Character.new(s)
    if char.space?
      @data << SPACE
    # letter mode character
    elsif char.cr? || char.period? || char.letter? 
      toggle_mode! if @mode != :letters
      case 
      when char.cr? 
        @data << CR
      when char.period?
        @counts["."] += 1
        @data << PERIOD
      when char.letter?
        @counts[char.char.upcase] += 1
        encode_letter(char, context: context)
      end
    else 
      encode_symbol(char)
    end
  end

  def encode_symbol(char)
    return if char.char == "\r" # skip line feeds
    return if char.char == "_" # skip underline mods

    @counts[char.char] += 1

    unless char.encodable_symbol?
      puts "unencodable: #{char.char} (#{char.char.ord})"
      return 
    end

    # we need to be in figures mode
    toggle_mode! if @mode == :letters
    # only a single table for not
    @data << char.encoded_value
  end

  def encode_letter(char, context: nil)
    if char.shift_status != @shift_status
      @data << SHIFT 
      @counts[:shift] += 1
    end
    @data << char.char.upcase.ord - ALPHABET_OFFSET
    # shift status reverts in v0.1 so no need to even track it,
    # all we have so far is momentary on shift
  end

  def toggle_mode!
    @data << TOGGLE_MAIN_MODE
    if @mode == :letters
      @mode = :figures
    else # figures or extended returns to letter
      @mode = :letters
    end
  end

  def close
    @data << "\0"
  end

end