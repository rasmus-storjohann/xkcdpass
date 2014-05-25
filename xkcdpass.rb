#!/usr/bin/ruby

require 'optparse'
require 'set'

# Plan: 
 
# Add option for prepadding (string) and postpadding (string) which add zero complexity but non-zero haystack complexity,
# source is https://www.grc.com/haystack.htm

# Add option for adding misspellings, remove or duplicate single letters

# Add option for stutter, find a syllable and repeat it several times

# Add option for randomizing all option values, which contributes to internal complexity

# https://github.com/beala/xkcd-password
# https://github.com/redacted/XKCD-password-generator
# https://github.com/thialfihar/xkcd-password-generator


def main
    options = parse_command_line_options
    wordlist = read_dictionary_file(options[:file])
    options[:phrase_count].times do
        phrase = PassPhrase.new
        phrase.create_pass_phrase(options, wordlist)
        if options[:verbose]
            puts "[#{phrase.complexity.to_i}, #{HaystackBruteForceComplexity.new.compute(phrase.to_s)}]: #{phrase}"
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
            options[:case_mode] = build_case_modifier_terminate_on_exception(mode)
        end
        opts.on('-n', '--numbers NUMBERS_MODE', "One of  'between', 'after' or 'inside'") do |mode|
            options[:number_injector] = build_number_injector_terminate_on_exception(mode)
        end
        opts.on('-d', '--number_count NUMBER', 'How many nunbers in the string') do |number|
            options[:number_count] = number.to_i
        end
        opts.on('-p', '--phrase_count COUNT', 'Number of pass phrases to generate') do |d|
            options[:phrase_count] = d.to_i
        end
        opts.on('-v', '--verbose', 'Show complexity of the password') do
            options[:verbose] = true
        end
    end
    optionParser.parse!
    options
end

def default_options
    {
        :file => '/usr/share/dict/words',
        :word_count => 4,
        :separator => ' ',
        :case_mode => NullModifier.new,
        :number_injector => NumbersBetweenWordsInjector.new,
        :number_count => 0,
        #:letter_map => {'a' => '@', 'x' => '#', 's' => '$', 'i' => '!', 'c' => '(', 'd' => ')', 't' => '+'},
        :letter_map => {},
        :phrase_count => 1,
        :verbose => false
    }
end

def build_case_modifier_terminate_on_exception(mode)
    begin
        build_case_modifier(mode.to_sym)
    rescue Exception => exception
        puts exception.message
        exit
    end
end

def build_case_modifier(mode)
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
            AlternateCaseModifier.new(true) # TODO fix this
        else
            raise Exception.new("Unknown case mode #{mode.to_s}")
    end
end

def build_number_injector_terminate_on_exception(mode)
    begin
        build_number_injector(mode.to_sym)
    rescue Exception => exception
        puts exception.message
        exit
    end
end

def build_number_injector(mode)
    case mode.to_sym
        when :between
            NumbersBetweenWordsInjector.new
        when :after
            NumbersAfterWordsInjector.new
        when :inside
            NumbersInsideWordsInjector.new
        else
            raise Exception.new("Unknown number inject mode #{mode.to_s}")
    end
end

class PassPhrase
    attr_accessor :words
    def initialize(entropy = nil)
        @entropy = entropy || Entropy.new
        @words  = []
        @separator = ''
    end
    def complexity
        @entropy.complexity
    end
    def haystack_entropy
        haystack(to_s)
    end
    def to_s
        @words.join(@separator)
    end
    def create_pass_phrase(options, wordlist)
        @separator = options[:separator]
        random_words(wordlist, options[:word_count])
        mutate(options[:case_mode])
        modify_letters_in_words(options[:letter_map])
        inject_numbers(options[:number_count], options[:number_injector])
    end
    def mutate(case_modifier)
        @words.map! do |word|
            case_modifier.mutate(word, @entropy)
        end
    end
    def modify_letters_in_words(letter_map)
        @words.map! do |word|
            modify_letters(word, letter_map)
        end
    end
    def modify_letters(word, letter_map)
        letters = word.split('')
        letters.map! do |letter|
            modify_one_letter(letter, letter_map)
        end
        letters.join('')
    end
    def modify_one_letter(letter, letter_map)
        alternate = letter_map[letter.downcase]
        choin_toss = alternate && (@entropy.random(2) == 1)
        choin_toss ? alternate : letter
    end
    def pick_random_point_in_strinng
    end
    def inject_numbers(number_count, numbers_injector)
        numbers_injector.inject_numbers(@words, number_count, @entropy)
    end
    def random_words(word_list, number_of_words)
        @words = []
        number_of_words.times do
            offset = @entropy.random(word_list.size)
            @words << word_list[offset.to_i]
        end
    end
end

class Entropy
    attr_reader :complexity
    def initialize
        @complexity = 0
    end
    def random(max)
        @complexity += log2(max)
        return (max * rand()).to_i
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
            if (line !~ /^\#/ && line !~ /\'/)
                words << line.strip
            end
        end
    end
    words.sort.uniq
end

class NullModifier
    def mutate(word, entropy)
        word
    end
end

class UpCaseModifier
    def mutate(word, entropy)
        word.upcase
    end
end

class DownCaseModifier
    def mutate(word, entropy)
        word.downcase
    end
end

class CapitalizeCaseModifier
    def mutate(word, entropy)
        word.capitalize
    end
end

class RandomWordCaseModifier
    def mutate(word, entropy)
        random = entropy.random(3)
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

class AlternateCaseModifier
    def initialize(start_with_upcase)
        @upcase = start_with_upcase
    end
    def mutate(word, entropy)
        if @upcase
            @upcase = false
            word.upcase
        else
            @upcase = true
            word.downcase
        end
    end
end

class NullNumbersInjector
    def inject_numbers(words, number_count, entropy)
        words
    end
end

class BaseNumberInjector
    def hom_many_numbers_to_inject(word_count, number_count, entropy)
        # expectation_value = word_count * number_count
        # entropy.random(2 * expectation_value)
        jitter_with_average_of_one = entropy.random(2) # TODO this is dodgy, really a random float, which is against intention
        hom_many = word_count * number_count * jitter_with_average_of_one
        hom_many.to_i
    end
    def make_random_number_string(entropy)
        entropy.random(100).to_s
    end
end

class NumbersBetweenWordsInjector < BaseNumberInjector
    def inject_numbers(words, number_count, entropy)
        number_count.times do
            offset = entropy.random(words.size).to_i
            random_number_string = make_random_number_string(entropy)
            words.insert(offset, random_number_string)
        end
        words
    end
end

class NumbersInWordsInjectorBase < BaseNumberInjector
    def inject_numbers(words, number_count, entropy)
        offsets_to_modify = compute_random_offsets(words.size, number_count, entropy)
        offsets_to_modify.each do |offset|
            words[offset] = inject_number_in_word(words[offset], make_random_number_string(entropy), entropy)
        end
        words
    end
    def compute_random_offsets(max_offset, number_of_offsets_to_return, entropy)
        random_offsets = []
        offsets = (0...max_offset).map{|x|x}
        for i in 0...number_of_offsets_to_return
            random = entropy.random(offsets.size)
            offset = offsets.delete_at(random)
            random_offsets << offset
            break if offsets.empty?
        end
        random_offsets
    end
    def inject_number_in_word(word, number, entropy)
        raise 'Functionality implemented in derived classes only'
    end
end

class NumbersAfterWordsInjector < NumbersInWordsInjectorBase
    def inject_number_in_word(word, number, entropy)
        word + number.to_s
    end
end

class NumbersInsideWordsInjector < NumbersInWordsInjectorBase
    def inject_number_in_word(word, number, entropy)
        offset_to_insert = entropy.random(word.size)
        word.insert(offset_to_insert, number)
    end
end

main
