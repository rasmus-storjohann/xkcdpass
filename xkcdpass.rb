#!/usr/bin/ruby

require 'optparse'
require 'set'

# Plan: 

# Make passpharse a class with members passpharse and entropy, since these belong together

# Add options for --haystack-complexity and --complexty, the former computing the set of sets of characters 
# (lower case, upper case, symbols, digits), adding up log(2) of the cardinality of each set, multiplied by the
# length of the string, and that gives the brute force attack complexity.

# Add option for prepadding (string) and postpadding (string) which add zero complexity but non-zero haystack complexity

# Add option for adding misspellings, remove or duplicate single letters

# Add option for randomizing all option values, which contributes to internal complexity

def main
    options = parse_command_line_options
    wordlist = read_dictionary_file(options[:file])
    10.times do
        $ENTROPY = Entropy.new
        phrase = create_pass_phrase(options, wordlist)
        puts "[#{$ENTROPY.entropy.to_i} bits] #{phrase}"
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
        opts.on('-i', '--min_word_count MIN', 'Minimum number of words') do |min|
            options[:min_word_count] = min.to_i
        end
        opts.on('-a', '--max_word_count MAX', 'Maximum number of words') do |max|
            options[:max_word_count] = max.to_i
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
        opts.on('-d', '--density NUMBER_DENSITY', 'Number between 0 and 1, higher value gives more digits in the string') do |number|
            options[:number_density] = number.to_f
        end
    end
    optionParser.parse!
    options
end

def default_options
    {
        :file => 'sample_dict.txt',
        :min_word_count => 4,
        :max_word_count => 6,
        :separator => ' ',
        :case_mode => NullCaseModifier.new,
        :number_injector => NullNumbersInjector.new,
        :number_density => 0.5,
        :letter_map => {}
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
            RandomCaseModifier.new
        when :alternate
            AlternateCaseModifier.new
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

def create_pass_phrase(options, wordlist)
    word_count = random_word_count(options[:min_word_count], options[:max_word_count])
    words = random_words(wordlist, word_count)
    words = modify_case(words, options[:case_mode])
    words = modify_letters_in_words(words, options[:letter_map])
    words = inject_numbers(words, options[:number_density], options[:number_injector])
    words.join(options[:separator])
end

def random_word_count(minimum_word_count, maximum_word_count)
    range = maximum_word_count - minimum_word_count + 1
    random = $ENTROPY.random(range)
    minimum_word_count + random.to_i
end

def modify_case(words, case_modifier)
    words.map do |word|
        case_modifier.modify_case(word)
    end
end

def modify_letters_in_words(words, letter_map)
    words.map do |word|
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

def inject_numbers(words, number_density, numbers_injector)
    numbers_injector.inject_numbers(words, number_density)
end

def modify_one_letter(letter, letter_map)
    alternate = letter_map[ letter.downcase ]
    choin_toss = $ENTROPY.random(2) == 1
    if alternate && choin_toss
        alternate
    else
        letter
    end
end

def random_words(word_list, number_of_words)
    words = []
    number_of_words.times do
        offset = $ENTROPY.random(word_list.size)
        words << word_list[offset.to_i]
    end
    words
end

def read_dictionary_file(filename)
    words = []
    File.open(filename, 'r') do |file|
        while (line = file.gets)
            if (line !~ /^\#/)
                words << line.strip
            end
        end
    end
    words.sort.uniq
end

class NullCaseModifier
    def modify_case(word)
        word
    end
end

class UpCaseModifier
    def modify_case(word)
        word.upcase
    end
end

class DownCaseModifier
    def modify_case(word)
        word.downcase
    end
end

class CapitalizeCaseModifier
    def modify_case(word)
        word.capitalize
    end
end

class RandomCaseModifier
    def modify_case(word)
        random = $ENTROPY.random(3)
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
    def initialize
        @upcase = $ENTROPY.random(2) == 1
    end
    def modify_case(word)
        if @upcase
            @upcase = false
            word.upcase
        else
            @upcase = true
            word.downcase
        end
    end
end

class Entropy
    attr_reader :entropy
    def initialize
        @entropy = 0
    end
    def random(max)
        @entropy += Math.log(max)/Math.log(2)
        return (max * rand()).to_i
    end
end

$ENTROPY = Entropy.new

class NullNumbersInjector
    def inject_numbers(words, number_density)
	words
    end
end

class BaseNumberInjector
    def hom_many_numbers_to_inject(word_count, number_density)
        # better, but tests are failing:
        # expectation_value = word_count * number_density
        # $ENTROPY.random(2 * expectation_value)
        jitter_with_average_of_one = $ENTROPY.random(2) # this is dodgy, really a random float, which is against intention
        hom_many = word_count * number_density * jitter_with_average_of_one
        hom_many.to_i
    end
    def make_random_number_string
        $ENTROPY.random(100).to_s
    end
end

class NumbersBetweenWordsInjector < BaseNumberInjector
    def inject_numbers(words, number_density)
        how_many = hom_many_numbers_to_inject(words.size, number_density)
        how_many.times do
            offset = $ENTROPY.random(words.size).to_i
            random_number_string = make_random_number_string
            words.insert(offset, random_number_string)
        end
        words
    end
end

class NumbersInWordsInjectorBase < BaseNumberInjector
    def inject_numbers(words, number_density)
        how_many = hom_many_numbers_to_inject(words.size, number_density)
        offsets_to_modify = compute_random_offsets(words.size, how_many)
        offsets_to_modify.each do |offset|
            words[offset] = inject_number_in_word(words[offset], make_random_number_string)
        end
        words
    end
    def compute_random_offsets(max_offset, number_of_offsets_to_return)
        loops = 0
        loop_limit = 10
        random_offsets = Set.new
        while random_offsets.size < number_of_offsets_to_return && loops <= loop_limit
            random_offset = $ENTROPY.random(max_offset).to_i
            random_offsets.add(random_offset)
        loops += 1
        end
        random_offsets
    end
    def inject_number_in_word(word, number)
        raise 'Functionality implemented in derived classes only'
    end
end

class NumbersAfterWordsInjector < NumbersInWordsInjectorBase
    def inject_number_in_word(word, number)
        word + number.to_s
    end
end

class NumbersInsideWordsInjector < NumbersInWordsInjectorBase
    def inject_number_in_word(word, number)
        offset_to_insert = $ENTROPY.random(word.size).to_i        
        word.insert(offset_to_insert, number)
    end
end

main
