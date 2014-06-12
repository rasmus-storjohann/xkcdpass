#!/usr/bin/ruby

require 'optparse'

# Plan: 
# Add option for prepadding (string) and postpadding (string) which add zero entropy but non-zero haystack complexity
# Add option for adding misspellings, remove or duplicate single letters
# Add option for stutter, find a syllable and repeat it several times
# Add option for randomizing all option values, which contributes to internal complexity
# http://www.reddit.com/r/YouShouldKnow/comments/232uch/ysk_how_to_properly_choose_a_secure_password_the/cgte7lp
# http://robinmessage.com/2014/03/why-bruce-schneier-is-wrong-about-passwords/

class Application
    def main
        options = parse_command_line_options
        wordlist = read_dictionary_file(options[:file])
        if $verbose == :full
            puts "wordlist contains #{wordlist.size} words, giving #{log2(wordlist.size)} bits per word"
        end
        options[:phrase_count].times do
            phrase = PassPhrase.new
            phrase.create_pass_phrase(options, wordlist)
            if $verbose == :some
                puts phrase.report
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
            opts.on('-v', '--verbose MODE', "One of 'none', 'some' and 'full'.") do |mode|
                $verbose = mode.to_sym
            end
        end
        optionParser.parse!
        options[:case_mode] = build_case_modifier(options[:case_mode])
        options[:number_injector] = build_number_injector(options[:number_injector], options[:number_count])
        options[:stutter_injector] = build_stutter_injector(options[:stutter_count])
        options[:substitution] = build_letter_substituter(options[:substitution], options[:substitution_count])
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

class PassPhraceReport
    def initialize(pass_phrase)
        @pass_phrase = pass_phrase
    end
    def dictionary_complexity
       @pass_phrase.dictionary_complexity.round(1)
    end
    def brute_force_complexity
        @pass_phrase.brute_force_complexity.round(1)
    end
    def phrase
        @pass_phrase.to_s
    end
    def brief
        "Dictionary=#{dictionary_complexity} BruteForce=#{brute_force_complexity} Phrase='#{phrase}'"
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
    def verbosity(step)
        before = to_s
        yield
        after = to_s
        if $verbose == :full && before != after
            puts "#{step} #{report}" 
        end
    end
    def create_pass_phrase(options, wordlist)
        verbosity('Pick words:    ') { @words = random_words(wordlist, options[:word_count]) }
        verbosity('Add separator: ') { @separator = options[:separator] }
        verbosity('Add stutter:   ') { @words = options[:stutter_injector].mutate(@words, @random_source) }
        verbosity('Change case:   ') { @words = options[:case_mode].mutate(@words, @random_source) }
        verbosity('Change letters:') { @words = options[:substitution].mutate(@words, @random_source) }
        verbosity('Add digits:    ') { @words = options[:number_injector].mutate(@words, @random_source) }
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

# TODO this string has too many elements
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
    attr_reader :unit, :value
    def initialize(bits, attacks_per_second)
        @unit = :second
        @value = 0
        # TODO avoid this and do all the work in log space
        attacks = Math.exp(Math.log(2)*bits)
        seconds = attacks/attacks_per_second
        results = []
        [   { :unit => :seconds, :factor =>                    1 },
            { :unit => :minutes, :factor =>                   60 },
            { :unit => :hours, :factor =>                  60*60 },
            { :unit => :days, :factor =>                24*60*60 },
            { :unit => :weeks, :factor =>             7*24*60*60 },
            { :unit => :months, :factor =>           30*24*60*60 },
            { :unit => :years, :factor =>           365*24*60*60 },
            { :unit => :millenia, :factor =>   1000*365*24*60*60 }
        ].each do |conversion|
            time = seconds / conversion[:factor]
            if time >= 1
                @unit = conversion[:unit]
                @value = time
            end
        end
    end
    def to_s
        "#{@value.round(1)} #{@unit}"
    end
end

def log2(value)
    Math.log(value)/Math.log(2)
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
    if $verbose == :none
        puts exception.message
    else
        puts exception.message
        puts exception.backtrace.join("\n\t")
    end
end
