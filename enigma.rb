# Enigma Process
#      1. Get input letter
#      2. Rotate wheels
#      3. Pass through plugboard
#      4. Pass through right-hand wheel
#      5. Pass through middle wheel
#      6. Pass through left-hand wheel
#      7. Pass through reflector
#      8. Pass through left-hand wheel
#      9. Pass through middle wheel
#     10. Pass through right-hand wheel
#     11. Pass through plugboard
#     12. Put encrypted letter to output

require 'io/console'

class String
  # convert letter to number
  def to_n
    return nil unless self.length == 1
    ('A'..'Z').to_a.index(self.upcase)
  end

  # colorization
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red
    colorize(31)
  end

  def green
    colorize(32)
  end

  def yellow
    colorize(33)
  end
end

class Integer
  # convert number to letter
  def to_l
    return self if self > 25 || self < 0
    ('A'..'Z').to_a[self]
  end
end

class Terminal
  def initialize(type)
    @wiring = Enigma.alphabet.each_with_index.map{ |letter, ind| [letter, parameters[type][ind]] }.to_h
  end
end

class Reflector < Terminal
  def pass(char)
    @wiring[char]
  end

  private

  def parameters
    {
      a: 'EJMZALYXVBWFCRQUONTSPIKHGD',
      b: 'YRUHQSLDPXNGOKMIEBFZCWVJAT',
      c: 'FVPJIAOYEDRZXWGCTKUQSBNMHL'
    }
  end
end

class Stator < Terminal
  def pass_to(direction, char)
    case direction
    when :left
      @wiring[char]
    when :right
      @wiring.key(char)
    end
  end

  private

  def parameters
    {
      army: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
      commercial: 'QWERTZUIOASDFGHJKPYXCVBNML'
    }
  end
end

class Plugboard
  def initialize(replacements)
    @replacements = {}
    replacements.split.each do |pair|
      @replacements[pair[0]] = pair[1]
      @replacements[pair[1]] = pair[0]
    end
  end

  def pass(char)
    @replacements[char] || char
  end
end

class Rotor
  attr_reader :position, :turnover

  def initialize(position, type)
    @position = position
    @turnover = parameters[type][1]
    @wiring = Enigma.alphabet.each_with_index.map{ |letter, ind| [letter, parameters[type][0][ind]] }.to_h
  end

  def rotate
    @position = ((@position.to_n + 1) % 26).to_l
  end

  def pass_to(direction, char)
    ch = ((char.to_n + @position.to_n + 26) % 26).to_l
    crypted_char = case direction
    when :left
      @wiring[ch]
    when :right
      @wiring.key(ch)
    end
    ((crypted_char.to_n - @position.to_n) % 26).to_l
  end

  private

  def parameters
    {
      'I' => ['EKMFLGDQVZNTOWYHXUSPAIBRCJ', 'Q'],
      'II' => ['AJDKSIRUXBLHWTMCQGZNPYFVOE', 'E'],
      'III' => ['BDFHJLCPRTXVZNYEIWGAKMUSQO', 'V'],
      'IV' => ['ESOVPZJAYQUIRHXLNFTGKDCMWB', 'J'],
      'V' => ['VZBRGITYUPSDNHLXAWMJQOFECK', 'Z']
    }
  end
end

class Enigma
  def self.alphabet
    ('A'..'Z').to_a
  end

  def initialize(opts = {})
    @groupping = opts[:groupping] || 4
    @length = opts[:length] || 40

    opts[:rotors] ||= {
      left: { position: 'A', type: 'I' },
      middle: { position: 'A', type: 'II' },
      right: { position: 'A', type: 'III' }
    }

    @plugboard = Plugboard.new(opts[:plugboard] ||= '')
    @stator = Stator.new(opts[:stator] || :army)

    @right = Rotor.new(opts[:rotors][:right][:position], opts[:rotors][:right][:type])
    @middle = Rotor.new(opts[:rotors][:middle][:position], opts[:rotors][:middle][:type])
    @left = Rotor.new(opts[:rotors][:left][:position], opts[:rotors][:left][:type])

    @reflector = Reflector.new(opts[:reflector] || :b)

    @text = []
    @cypher = []
  end

  def run
    loop do
      render_interface

      input = STDIN.getch.upcase
      if input == "\u0018"
        puts nil
        break
      elsif !Enigma.alphabet.include?(input)
        next
      end

      @text << input
      rotate_rotors
      @cypher << encrypt(input)
    end
  end

  private

  def encrypt(input)
    ch = @stator.pass_to(:left, @plugboard.pass(input))

    ch = @right.pass_to(:left, ch)
    ch = @middle.pass_to(:left, ch)
    ch = @left.pass_to(:left, ch)

    ch = @reflector.pass(ch)

    ch = @left.pass_to(:right, ch)
    ch = @middle.pass_to(:right, ch)
    ch = @right.pass_to(:right, ch)

    return @plugboard.pass(@stator.pass_to(:right, ch))
  end

  def rotate_rotors
    if @middle.position == @middle.turnover
      @left.rotate
      @middle.rotate
    end
    if @right.position == @right.turnover
      @middle.rotate
    end
    @right.rotate
  end

  def render_interface
    system(Gem.win_platform? ? 'cls': 'clear')

    puts "+++ ENIGMA M3 +++\nPress Ctrl+X for Exit.\n\n"
    puts "-------------"
    puts "| #{@left.position.red} | #{@middle.position.red} | #{@right.position.red} |"
    puts "-------------"
    render_source
    render_cypher
  end

  def render_source
    puts ('=' * (@length + (@length / @groupping))) + "\n"
    @text.each_with_index do |ch, ind|
      print ch.green
      print ' ' if ((ind + 1) % @groupping).zero?
      puts nil if  ((ind + 1) % @length).zero?
    end
    puts ("\n")
  end

  def render_cypher
    puts ('=' * (@length + (@length / @groupping))) + "\n"
    @cypher.each_with_index do |ch, ind|
      print ch.yellow
      print ' ' if ((ind + 1) % @groupping).zero?
      puts nil if  ((ind + 1) % @length).zero?
    end
    puts "\n" + ('=' * (@length + (@length / @groupping)))
  end
end

machine = Enigma.new({
  rotors: {
    left: { position: 'A', type: 'I' },
    middle: { position: 'A', type: 'II' },
    right: { position: 'A', type: 'III' }
  },
  plugboard: 'EF MN'
})
machine.run