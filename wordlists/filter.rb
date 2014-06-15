#!/usr/bin/ruby

words = []

while (line = $stdin.gets)
    begin
        line.strip!
        if line =~ /^[a-zA-Z]+$/
            words << line
        end
    rescue
    end
end

words = words.sort.uniq

puts "# #{words.size} words filtered for xkcdpass"

words.each do |line|
    puts line
end
