#!/usr/bin/ruby

require 'optparse'

# Plan: 
# Add option for prepadding (string) and postpadding (string) which add zero entropy but non-zero haystack complexity
# Add option for adding misspellings, remove or duplicate single letters
# http://www.reddit.com/r/YouShouldKnow/comments/232uch/ysk_how_to_properly_choose_a_secure_password_the/cgte7lp

ONE_BILLION = 1000000000
ONE_MILLION_YEARS = 1000 * 1000 * 365 * 24 * 60 * 60

$HELP =<<END

Name: xkcdpass

Description:
    xkcdpass generates passphrases by picking several words randomly from a word list, modifies 
    them using a standard bag of tricks such as change case, introduce digits, substitute symbols 
    for letters, etc. It then estimates the strength of the passphrases in terms of how long they 
    would stand up against simple brute force attack or a modern dictionary based attack. This 
    estimate is done after each type of modification, making clear how much stronger the passphrase 
    actually becomes at each stage. 
END

class Application
    def main
        options = parse_command_line_options
        wordlist = read_dictionary_file(options[:file])
        $output.message("Wordlist contains #{wordlist.size} words, giving #{log2(wordlist.size).round(1)} bits per word\n")
        $output.message("Assuming #{options[:attacks_in_billions_per_second]} billion attacks per second when estimating longevity\n\n")
        options[:phrase_count].times do
            phrase = PassPhrase.new
            phrase.create_pass_phrase(options, wordlist)
        end
    end
    def parse_command_line_options
        options = default_options
        optionParser = OptionParser.new do|opts|
            opts.on('-h', '--help', 'Display this screen' ) do
                puts $HELP
                puts opts
                puts
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
            opts.on('-c', '--case MODE', "One of  'upper', 'lower', 'capitalize', 'alternate' or 'random'") do |mode|
                options[:case_mode] = mode.to_sym
            end
            opts.on('-n', '--numbers NUMBERS_MODE', "One of  'between' or 'inside'") do |mode|
                options[:number_injector] = mode.to_sym
            end
            opts.on('-d', '--number_count NUMBER', 'How many nunbers in the string') do |number|
                options[:number_count] = number.to_i
            end
            opts.on('-u', '--substitution MODE', "L3++er sub$tituti0n mode, one of 'none', 'some', 'lots'") do |mode|
                options[:substitution] = mode.to_sym
            end
            opts.on('-q', '--substitution_count NUMBER', "Number of substitutions") do |number|
                options[:substitution_count] = number.to_i
            end
            opts.on('-o', '--stutter_count NUMBER', 'How many stutters in the string') do |number|
                options[:stutter_count] = number.to_i
            end
            opts.on('-p', '--phrase_count NUMBER', 'Number of pass phrases to generate') do |number|
                options[:phrase_count] = number.to_i
            end
            opts.on('-a', '--attacks BILLIONS', "The estimated power of an attacker, default is 1.0, representing 1 billion attacks per second.") do |mode|
                options[:attacks_in_billions_per_second] = mode.to_f
            end
            opts.on('-v', '--verbose MODE', "One of 'none', 'terse', 'default' and 'verbose'.") do |mode|
                options[:verbose] = mode.to_sym
            end
        end
        optionParser.parse!
        options[:case_mode] = build_case_modifier(options[:case_mode])
        options[:number_injector] = build_number_injector(options[:number_injector], options[:number_count])
        options[:stutter_injector] = build_stutter_injector(options[:stutter_count])
        options[:substitution] = build_letter_substituter(options[:substitution], options[:substitution_count])
        $output = build_logger(options[:verbose], ONE_BILLION * options[:attacks_in_billions_per_second])
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
            :stutter_injector => NullModifier.new,
            :stutter_count => 0,
            :substitution => NullModifier.new,
            :substitution_count => 0,
            :letter_count => 0,
            :phrase_count => 1,
            :attacks_in_billions_per_second => 1.0,
            :verbose => :terse
        }
    end
    def build_logger(verbose, attacks_per_second)
        case verbose
        when :none
            NoneLogger.new(attacks_per_second)
        when :terse
            TerseLogger.new(attacks_per_second)
        when :default
            DefaultLogger.new(attacks_per_second)
        when :verbose
            VerboseLogger.new(attacks_per_second)
        end
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
            when :inside
                NumbersInsideWordsInjector.new(number_count)
            else
                raise Exception.new("Unknown number inject mode #{mode.to_s}")
        end
    end
    def build_stutter_injector(number)
        return number unless number.instance_of? Fixnum
        StutterModifier.new(number)
    end
    def build_letter_substituter(mode, substitution_count)
        return mode unless mode.instance_of? Symbol
        case mode
        when :none
            NullModifier.new
        when :lots
            LetterModifier.new(:lots, substitution_count)
        else
            LetterModifier.new(:some, substitution_count)
        end
    end
    def read_dictionary_file(filename)
        words = []
        File.open(filename, 'r') do |file|
            while (line = file.gets)
                line.strip!
                if line =~ /^[a-zA-Z]+$/
                    words << line
                end
            end
        end
        words.sort.uniq
    end
end

class PassPhrase
    attr_reader :words
    def initialize(random_source = nil)
        @random_source = random_source || RandomSource.new
        @words  = []
        @separator = ' '
    end
    def to_s
        @words.join(@separator)
    end
    def dictionary_complexity
        @random_source.entropy
    end
    def brute_force_complexity
        compute_brute_force_complexity(to_s)
    end
    def report
        PassPhraceReport.new(self).brief
    end
    def create_pass_phrase(options, wordlist)
        @words = random_words(wordlist, options[:word_count])
        $output.log(self, 'Pick words')
        previous_state = to_s
        
        @words = options[:stutter_injector].mutate(@words, @random_source)
        $output.log(self, 'Add stutter') if previous_state != to_s
        previous_state = to_s

        @words = options[:case_mode].mutate(@words, @random_source)
        $output.log(self, 'Change case') if previous_state != to_s
        previous_state = to_s

        @words = options[:substitution].mutate(@words, @random_source)
        $output.log(self, 'Change letters') if previous_state != to_s
        previous_state = to_s

        @words = options[:number_injector].mutate(@words, @random_source)
        $output.log(self, 'Add digits') if previous_state != to_s
        previous_state = to_s

        @separator = options[:separator]
        $output.log(self, "Add separator '#{@separator}'") if previous_state != to_s
        previous_state = to_s

        $output.print_final_result(self)
    end
    def inject_stutters(stutter_count, stutter_injector)
        stutter_injector.inject_stutters(@words, stutter_count, @random_source)
    end
    def random_words(word_list, number_of_words)
        words = []
        number_of_words.times do
            offset = @random_source.random(word_list.size)
            words << word_list[offset.to_i].dup
        end
        words
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
            break if source.empty?
        end
        target.sort
    end
end

class LoggerBase
    def initialize(attacks_per_second)
        @attacks_per_second = attacks_per_second
    end
    def brief(pass_phrase, comment)
        "#{comment}: Dictionary=#{dictionary_complexity(pass_phrase)} BruteForce=#{brute_force_complexity(pass_phrase)} Phrase='#{pass_phrase}'"
    end
    def full(pass_phrase, comment)
        log = []
        log << "Stage: #{comment}"
        log << "Phrase: #{pass_phrase.to_s}"
        log << "Dictionary attack:  #{dictionary_complexity(pass_phrase)} bits (longevity: #{dictionary_longevity(pass_phrase)})"
        log << "Brute force attack: #{brute_force_complexity(pass_phrase)} bits (longevity: #{brute_force_longevity(pass_phrase)})"
        log << ''
        puts log.join("\n")
    end
    def dictionary_complexity(pass_phrase)
       pass_phrase.dictionary_complexity.round(1)
    end
    def brute_force_complexity(pass_phrase)
        pass_phrase.brute_force_complexity.round(1)
    end
    def dictionary_longevity(pass_phrase)
       PassphraseLongevity.new(pass_phrase.dictionary_complexity, @attacks_per_second).to_s
    end
    def brute_force_longevity(pass_phrase)
       PassphraseLongevity.new(pass_phrase.brute_force_complexity, @attacks_per_second).to_s
    end
    def phrase(pass_phrase)
        @pass_phrase.to_s
    end
end

class VerboseLogger < LoggerBase
    def initialize(attacks_per_second)
        super(attacks_per_second)
    end
    def message(string)
        puts string
    end
    def log(pass_phrase, comment)
        puts full(pass_phrase, comment)
    end
    def print_final_result(pass_phrase)
        puts pass_phrase
    end
    def log_error(exception)
        puts exception.message
        puts exception.backtrace.join("\n\t")
    end
end

class DefaultLogger < LoggerBase
    def initialize(attacks_per_second)
        super(attacks_per_second)
    end
    def message(string)
        puts string
    end
    def log(pass_phrase, comment)
        puts brief(pass_phrase, comment)
    end
    def print_final_result(pass_phrase)
        puts pass_phrase
    end
    def log_error(exception)
        puts exception.message
    end
end

class TerseLogger < LoggerBase
    def initialize(attacks_per_second)
        super(attacks_per_second)
    end
    def message(string)
    end
    def log(pass_phrase, comment)
    end
    def print_final_result(pass_phrase)
        puts brief(pass_phrase, 'Final')
    end
    def log_error(exception)
        puts exception.message
    end
end

class NoneLogger < LoggerBase
    def initialize(attacks_per_second)
        super(attacks_per_second)
    end
    def message(string)
    end
    def log(pass_phrase, comment)
    end
    def print_final_result(pass_phrase)
        puts pass_phrase
    end
    def log_error(exception)
        puts exception.message
    end
end

$output = DefaultLogger.new(ONE_BILLION)

$SYMBOLS = '!@#$%^&*()-_=+{[}]:;"\'|\<,>.?/'

def compute_brute_force_complexity(string)
    logs = 0
    logs += log2(('a'..'z').count) if string =~ /[a-z]/
    logs += log2(('A'..'Z').count) if string =~ /[A-Z]/
    logs += log2(('0'..'9').count) if string =~ /[0-9]/
    logs += log2($SYMBOLS.size) if string =~ /[^a-zA-Z0-9 ]/
    logs * string.length
end

class PassphraseLongevity
    def initialize(bits, attacks_per_second)
        attacks = Math.exp(Math.log(2) * bits)
        seconds = attacks / attacks_per_second
        @forever = seconds > ONE_MILLION_YEARS
        unless @forever
            compute_longevity(seconds)
        end
    end
    def compute_longevity(seconds)
        @unit = ''
        @value = 0
        results = []
        [   { :unit => :milliseconds, :factor =>                 0.001 },
            { :unit => :seconds, :factor =>                          1 },
            { :unit => :minutes, :factor =>                         60 },
            { :unit => :hours, :factor =>                      60 * 60 },
            { :unit => :days, :factor =>                  24 * 60 * 60 },
            { :unit => :weeks, :factor =>             7 * 24 * 60 * 60 },
            { :unit => :months, :factor =>           30 * 24 * 60 * 60 },
            { :unit => :years, :factor =>           365 * 24 * 60 * 60 },
            { :unit => :millenia, :factor => 1000 * 365 * 24 * 60 * 60 }
        ].each do |conversion|
            time = seconds / conversion[:factor]
            if time >= 1
                @unit = conversion[:unit]
                @value = time
            end
        end
    end
    def to_s
        @forever ? 'forever' : "#{@value.round(1)} #{@unit}"
    end
end

def log2(value)
    Math.log(value) / Math.log(2)
end

class NullModifier
    def mutate(words, random_source)
        words
    end
end

class WordWiseModifier
    def mutate(words, random_source)
        words.map do |word|
            mutate_word(word, random_source)
        end
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
    def initialize(mode = :some, count)
        @count = count
        case mode
        when Hash
            @map = mode
        when :some
            @map = {'a' => '@', 's' => '$'}
        when :lots
            @map = {'a' => '@', 'x' => '#', 's' => '$', 'i' => '!', 'c' => '(', 'd' => ')', 't' => '+'}
        else
            raise 'Unexpected argument to LetterModifier#initialize'
        end
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

class StutterModifier < WordWiseModifier
    def initialize(stutter_count)
        @stutter_count = stutter_count
        @MAX_REPEAT_COUNT = 2
    end
    def mutate(words, random_source)
        indeces = random_source.pick_n_from_m(@stutter_count, words.size)
        indeces.each do |index|
            words[index] = mutate_word(words[index], random_source)
        end
        words
    end
    def mutate_word(word, random_source)
        syllables = split_into_syllables(word)
        index = random_source.random(syllables.size-1)
        repeat_count = 1 + random_source.random(@MAX_REPEAT_COUNT)
        syllables.insert(index, syllables[index] * repeat_count)
        syllables.join('')
    end
    def split_into_syllables(word)
        result = []
        while word.length > 0
            syllable, word = split_off_first_syllable(word)
            result << syllable
        end
        result
    end
    def split_off_first_syllable(word)
        case word
        when /[^A-Za-z]/
            raise "#{word}: Invalid argument, must contain letters only"
        when /^([AEIOUaeiou]+)(.*)/
            return [$1, $2]
        when /^([^AEIOUaeiou]+[AEIOUaeiou]+)(.*)/
            return [$1, $2]
        else
            return [word, '']
        end
    end
end

class NumbersBetweenWordsInjector
    def initialize(number_count)
        @number_count = number_count
        @MAX_RANDOM_NUMBER = 100
    end
    def mutate(words, random_source)
        @number_count.times do
            offset = random_source.random(words.size).to_i
            random_number_string = random_source.random(@MAX_RANDOM_NUMBER).to_s
            words.insert(offset, random_number_string)
        end
        words
    end
end

class NumbersInsideWordsInjector
    def initialize(number_count)
        @number_count = number_count
        @MAX_RANDOM_NUMBER = 100
    end
    def mutate(words, random_source)
        offsets = random_source.pick_n_from_m(@number_count, words.size)
        offsets.each do |offset|
            random_number_string = random_source.random(@MAX_RANDOM_NUMBER).to_s
            words[offset] = inject_number_in_word(words[offset], random_number_string, random_source)
        end
        words
    end
    def inject_number_in_word(word, number, random_source)
        where_to_insert = random_source.random(word.size)
        word.insert(where_to_insert, number.to_s)
    end
end

begin
    Application.new.main
rescue SystemExit
    # ignore
rescue Exception => exception
    $output.log_error(exception)
end
