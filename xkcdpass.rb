#!/usr/bin/ruby

require 'optparse'

# Plan: 
# Add option for prepadding (string) and postpadding (string) which add zero entropy but non-zero haystack complexity
# Add option for adding misspellings, remove or duplicate single letters
# Add option for stutter, find a syllable and repeat it several times
# Add option for randomizing all option values, which contributes to internal complexity

$verbose = false

class Application
    def main
        options = parse_command_line_options
        wordlist = read_dictionary_file(options[:file])
        if $verbose
            puts "wordlist contains #{wordlist.size} words, giving #{log2(wordlist.size)} bits per word"
        end
        options[:phrase_count].times do
            phrase = PassPhrase.new
            phrase.create_pass_phrase(options, wordlist)
            if $verbose
                puts "[#{phrase.entropy}, #{HaystackBruteForceComplexity.new.compute(phrase.to_s)}]: #{phrase}"
            else
                puts phrase
            end
        end
    end
    def parse_command_line_options
        options = default_options
        optionParser = OptionParser.new do|opts|
            opts.on('-h', '--help', 'Display this screen' ) do
                puts opts
                exit
            end
            opts.on('-f', '--file FILE', 'Dictionary file to use') do |file|
                options[:file] = file
            end
            opts.on('-w', '--word_count COUNT', 'Number of words') do |count|
                options[:word_count] = count.to_i
            end
            opts.on('-s', '--separator STRING', 'String used to separate words') do |separator|
                options[:separator] = separator
            end
            opts.on('-c', '--case CASE_MODE', "One of  'upper', 'lower', 'capitalize', 'alternate' or 'random'") do |mode|
                options[:case_mode] = mode.to_sym
            end
            opts.on('-n', '--numbers NUMBERS_MODE', "One of  'between', 'after' or 'inside'") do |mode|
                options[:number_injector] = mode.to_sym
            end
            opts.on('-d', '--number_count NUMBER', 'How many nunbers in the string') do |number|
                options[:number_count] = number.to_i
            end
#            opts.on('-t', '--stutter NUMBER', 'How many repeated syllabled in the string') do |number|
#                options[:stutter_count] = number.to_i
#            end
            opts.on('-p', '--phrase_count COUNT', 'Number of pass phrases to generate') do |d|
                options[:phrase_count] = d.to_i
            end
            opts.on('-v', '--verbose', 'Show complexity of the password, and show more details on errors') do
                $verbose = true
            end
        end
        optionParser.parse!
        options[:case_mode] = build_case_modifier(options[:case_mode])
        options[:number_injector] = build_number_injector(options[:number_injector], options[:number_count])
        options[:letter_map] = LetterModifier.new(options[:letter_map], options[:letter_count])
        options
    end
    def default_options
        {
            :file => '/usr/share/dict/words',
            :word_count => 4,
            :separator => ' ',
            :case_mode => NullModifier.new,
            :number_injector => NullModifier.new,
            :number_count => 0,
            :stutter_injector => StutterModifier.new,
            :stutter_count => 0,
            #:letter_map => {'a' => '@', 'x' => '#', 's' => '$', 'i' => '!', 'c' => '(', 'd' => ')', 't' => '+'},
            :letter_map => NullModifier.new,
            :letter_count => 0,
            :phrase_count => 1,
            :verbose => false
        }
    end
    def build_case_modifier(mode)
        return mode unless mode.instance_of? Symbol
        case mode.to_sym
            when :upper
                UpCaseModifier.new
            when :lower
                DownCaseModifier.new
            when :capitalize
                CapitalizeCaseModifier.new
            when :random
                RandomWordCaseModifier.new
            when :alternate
                AlternateCaseModifier.new
            else
                raise Exception.new("Unknown case mode #{mode.to_s}")
        end
    end
    def build_number_injector(mode, number_count)
        return mode unless mode.instance_of? Symbol
        case mode
            when :between
                NumbersBetweenWordsInjector.new(number_count)
            when :after
                NumbersAfterWordsInjector.new(number_count)
            when :inside
                NumbersInsideWordsInjector.new(number_count)
            else
                raise Exception.new("Unknown number inject mode #{mode.to_s}")
        end
    end
end

class PassPhrase
    attr_reader :words
    def initialize(random_source = nil)
        @random_source = random_source || RandomSource.new
        @words  = []
        @separator = ''
    end
    def entropy
        @random_source.entropy
    end
    def to_s
        @words.join(@separator)
    end
    def create_pass_phrase(options, wordlist)
        @separator = options[:separator]
        random_words(wordlist, options[:word_count])
        inject_stutters(options[:stutter_count], options[:stutter_injector])
        @words = options[:case_mode].mutate(@words, @random_source)
        @words = options[:letter_map].mutate(@words, @random_source)
        @words = options[:number_injector].mutate(@words, @random_source)
    end
    def inject_stutters(stutter_count, stutter_injector)
        stutter_injector.inject_stutters(@words, stutter_count, @random_source)
    end
    def random_words(word_list, number_of_words)
        @words = []
        number_of_words.times do
            offset = @random_source.random(word_list.size)
            @words << word_list[offset.to_i]
        end
    end
end

class RandomSource
    attr_reader :entropy
    def initialize
        @entropy = 0
    end
    def random(max)
        @entropy += log2(max)
        return (max * rand()).to_i
    end
    def pick_n_from_m(n, m)
        source = (0...m).to_a
        target = []
        n.times do
            offset = random(source.size)
            target << source.delete_at(offset)
        end
        target.sort
    end
end

$SYMBOLS = '!@#$%^&*()-_=+{[}]:;"\'|\<,>.?/'

class NaiveBruteForceComplexity
    def compute(string)
        domain = ('a'..'z').count + ('A'..'Z').count + ('0'..'9').count + $SYMBOLS.count
        log2(domain) * string.length
    end
end

class HaystackBruteForceComplexity
    def compute(string)
        logs = 0
        logs += log2(('a'..'z').count) if string =~ /[a-z]/
        logs += log2(('A'..'Z').count) if string =~ /[A-Z]/
        logs += log2(('0'..'9').count) if string =~ /[0-9]/
        logs += log2($SYMBOLS.count) if string =~ /#{$SYMBOLS}/
        logs * string.length
    end
end

def log2(value)
    Math.log(value)/Math.log(2)
end

def read_dictionary_file(filename)
    words = []
    File.open(filename, 'r') do |file|
        while (line = file.gets)
            is_comment = line =~ /^\#/
            contains_apostrophe = line =~ /\'/
            if (!is_comment && !contains_apostrophe)
                words << line.strip
            end
        end
    end
    words.sort.uniq
end

class WordWiseModifier
    def mutate(words, random_source)
        words.map do |word|
            mutate_word(word, random_source)
        end
    end
end

class NullModifier
    def mutate(words, random_source)
        words
    end
end

class UpCaseModifier < WordWiseModifier
    def mutate_word(word, random_source)
        word.upcase
    end
end

class DownCaseModifier < WordWiseModifier
    def mutate_word(word, random_source)
        word.downcase
    end
end

class CapitalizeCaseModifier < WordWiseModifier
    def mutate_word(word, random_source)
        word.capitalize
    end
end

class RandomWordCaseModifier < WordWiseModifier
    def mutate_word(word, random_source)
        random = random_source.random(3)
        case random
            when 0
                word.upcase
            when 1
                word.downcase
            when 2
                word.capitalize
        end
    end
end

class AlternateCaseModifier < WordWiseModifier
    def initialize
        @upcase = nil
    end
    def mutate_word(word, random_source)
        if @upcase.nil?
            @upcase = random_source.random(2) == 1
        end
        if @upcase
            @upcase = false
            word.upcase
        else
            @upcase = true
            word.downcase
        end
    end
end

class LetterModifier
    def initialize(map, count)
        @map = map || {'a' => '@', 'x' => '#', 's' => '$', 'i' => '!', 'c' => '(', 'd' => ')', 't' => '+'}
        @count = count
    end
    def mutate(words, random_source)
        offsets = random_source.pick_n_from_m(@count, words.length)
        offsets.each do |offset|
            words[offset] = modify_letters(words[offset], @map, random_source)
        end
        words
    end
    def modify_letters(word, letter_map, random_source)
        letters = word.split('')
        letters.map! do |letter|
            modify_one_letter(letter, letter_map, random_source)
        end
        letters.join('')
    end
    def modify_one_letter(letter, letter_map, random_source)
        alternate = letter_map[letter.downcase]
        choin_toss = alternate && (random_source.random(2) == 1)
        choin_toss ? alternate : letter
    end
end

class StutterModifier
    def inject_stutters(words, stutter_count, random_source)
    end
    def split_into_syllables(word)
        result = []
        while word.length > 0
            first_syllable, word = split_off_first_syllable(word)
            result << first_syllable
        end
        result
    end
    def split_off_first_syllable(word)
        case word
        when /[^A-Za-z]/
            raise "#{word}: Invalid argument, letters only please"
        when /^([AEIOUaeiou]+)(.*)/
            return [$1, $2]
        when /^([^AEIOUaeiou]+[AEIOUaeiou]+)(.*)/
            return [$1, $2]
        end
    end
end

class BaseNumberInjector
    def initialize(number_count)
        @number_count = number_count
    end
    def make_random_number_string(random_source)
        random_source.random(100).to_s
    end
end

class NumbersBetweenWordsInjector < BaseNumberInjector
    def initialize(number_count)
        super(number_count)
    end
    def mutate(words, random_source)
        @number_count.times do
            offset = random_source.random(words.size).to_i
            random_number_string = make_random_number_string(random_source)
            words.insert(offset, random_number_string)
        end
        words
    end
end

class NumbersInWordsInjectorBase < BaseNumberInjector
    def initialize(number_count)
        super(number_count)
    end
    def mutate(words, random_source)
        offsets = random_source.pick_n_from_m(@number_count, words.size)
        offsets.each do |offset|
            random_number_string = make_random_number_string(random_source)
            words[offset] = inject_number_in_word(words[offset], random_number_string, random_source)
        end
        words
    end
    def inject_number_in_word(word, number, random_source)
        raise 'Functionality implemented in derived classes only'
    end
end

class NumbersAfterWordsInjector < NumbersInWordsInjectorBase
    def initialize(number_count)
        super(number_count)
    end
    def inject_number_in_word(word, number, random_source)
        word + number.to_s
    end
end

class NumbersInsideWordsInjector < NumbersInWordsInjectorBase
    def initialize(number_count)
        super(number_count)
    end
    def inject_number_in_word(word, number, random_source)
        where_to_insert = random_source.random(word.size)
        word.insert(where_to_insert, number.to_s)
    end
end


begin
    Application.new.main
rescue Exception => exception
    if $verbose
        puts exception.backtrace.join("\n\t")
    else
        puts exception.message
    end
end
