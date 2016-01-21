require 'pp'
require './5bit.rb'

@five = FiveBit.new

File.open("pride_and_prejudice.txt") do |file|
  while not file.eof?
    s = file.read(1000)
    # puts s
    @five.encode s
  end
  @five.close
end

puts @five.buffer.size
pp @five.counts.sort_by {|k,v| v }

size = File.size("pride_and_prejudice.txt")
after = @five.encoded.size

puts "Before: #{size}"
puts "After: #{after}"

puts "Size:  #{(after/size.to_f*100).round(1)}%"