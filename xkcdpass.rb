#!/usr/bin/ruby

require 'optparse'
require 'set'

class Entropy
    attr_reader :entropy
    def initialize
        @entropy = 0
    end
    def random(max)
        @entropy += Math.log(max)
        return (max * rand()).to_i
    end
end

$ENTROPY = Entropy.new

def default_options
    {
        :file => 'sample_dict.txt',
        :min_word_count => 4,
        :max_word_count => 6,
        :separator => ' ',
        :case_mode => AlternateCaseModifier.new,
        :numbers_mode => NumbersInsideWordsInjector.new(0.5),
        :letter_map => {
            'a' => '@'
        }
    }
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
        opts.on('-s', '--separator CHARACTER', 'Character used to separate words') do |separator|
            options[:separator] = separator
        end
        opts.on('-c', '--case CASE_MODE', "one of  'upper', 'lower', 'capitalize', 'alternate' or 'random'") do |mode|
            options[:case_mode] = build_case_modifier_terminate_on_exception(mode)
        end
    end
    optionParser.parse!
    options
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
    case mode
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

def modify_letters_and_case(words, letter_map, case_modifier)
    words.map do |word|
        word = modify_letters(word, letter_map)
        case_modifier.modify_case(word)
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
    modified = letter_map[ letter.downcase ]
    modified.nil? ? letter : modified
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
    words
end

def random_words(word_list, number_of_words)
    words = []
    number_of_words.times do
        offset = $ENTROPY.random(word_list.size)
        words << word_list[offset.to_i]
    end
    words
end

def inject_numbers(words, numbers_injector)
    numbers_injector.inject_numbers(words)
end

class BaseNumberInjector
    def initialize(fraction_of_numbers_to_inject)
        @fraction_of_numbers_to_inject = fraction_of_numbers_to_inject
    end
    def hom_many_numbers_to_inject(word_count)
        jitter_with_average_of_one = $ENTROPY.random(2)
        hom_many = word_count * @fraction_of_numbers_to_inject * jitter_with_average_of_one
        hom_many.to_i
    end
    def make_random_number_string
        $ENTROPY.random(100).to_s
    end
end

class NumbersBetweenWordsInjector < BaseNumberInjector
    def inject_numbers(words)
        how_many = hom_many_numbers_to_inject(words.size)
        how_many.times do
            offset = $ENTROPY.random(words.size).to_i
            number = make_random_number_string
            words.insert(offset, number)
        end
        words
    end
end

class NumbersInWordsInjectorBase < BaseNumberInjector
    def inject_numbers(words)
        offsets_to_modify = Set.new
        how_many = hom_many_numbers_to_inject(words.size)
        while offsets_to_modify.size < how_many
            index_of_word_to_modify = $ENTROPY.random(words.size).to_i
            offsets_to_modify.add(index_of_word_to_modify)
        end
        offsets_to_modify.each do |index|
            number = make_random_number_string
            words[index] = inject_number_in_word(words[index], number)
        end
        words
    end
end

class NumbersAfterWordsInjector < NumbersInWordsInjectorBase
    def inject_number_in_word(word, number)
        word + number
    end
end

class NumbersInsideWordsInjector < NumbersInWordsInjectorBase
    def inject_number_in_word(word, number)
        offset_to_insert = $ENTROPY.random(word.size).to_i        
        word.insert(offset_to_insert, number)
    end
end


def main
    options = parse_command_line_options
    wordlist = read_dictionary_file(options[:file])
    2.times do
        puts create_passphrase(options, wordlist)
    end
end

def create_passphrase(options, wordlist)
    word_count = random_word_count(options[:min_word_count], options[:max_word_count])
    words = random_words(wordlist, word_count)
    words = modify_letters_and_case(words, options[:letter_map], options[:case_mode])
    words = inject_numbers(words, options[:numbers_mode])
    words.join(options[:separator])
end

def random_word_count(minimum_word_count, maximum_word_count)
    range = maximum_word_count - minimum_word_count + 1
    random = $ENTROPY.random(range)
    minimum_word_count + random.to_i
end

main()

