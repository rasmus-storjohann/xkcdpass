require 'pathname'
$LOAD_PATH << Pathname(__FILE__).dirname.realpath
require 'test/unit'
require 'test/unit/assertions.rb'
require 'xkcdpass.rb'

class EntropyMockReturnsConstantValue
    def initialize(mock_random_value)
        raise 'random must be less than one' if mock_random_value > 1
        raise 'random must be greater than zero' if mock_random_value < 0
        @mock_random_value = mock_random_value
    end
    def random(max)
        return (max * @mock_random_value).to_i
    end
end

class EntropyMockReturnsValuesFromArray
    def initialize(data)
        @data = data
    end
    def random(max)
        return (max * @data.shift).to_i
    end
end

class BuildCaseModifierTests < Test::Unit::TestCase
    def test_build_uppercase_modifier
        modifier = build_case_modifier(:upper)

        assert modifier.instance_of? UpCaseModifier
    end
    def test_build_lowercase_modifier
        modifier = build_case_modifier(:lower)

        assert modifier.instance_of? DownCaseModifier
    end
    def test_build_capitalize_modifier
        modifier = build_case_modifier(:capitalize)

        assert modifier.instance_of? CapitalizeCaseModifier
    end
    def test_build_random_modifier
        modifier = build_case_modifier(:random)

        assert modifier.instance_of? RandomWordCaseModifier
    end
    def test_build_alternate_modifier
        modifier = build_case_modifier(:alternate)

        assert modifier.instance_of? AlternateCaseModifier
    end
    def test_build_undefined_modifier
        assert_raise(Exception) do
            modifier = build_case_modifier(:foo)
        end
    end
end

class CaseModifierTests < Test::Unit::TestCase
    def test_upper_case_modifier
        modifier = UpCaseModifier.new
        expected = 'THIS'

        actual = modifier.mutate('ThiS', nil)

        assert_equal expected, actual
    end
    def test_lower_case_modifier
        modifier = DownCaseModifier.new
        expected = 'this'

        actual = modifier.mutate('ThiS', nil)

        assert_equal expected, actual
    end
    def test_capitalize_case_modifier
        modifier = CapitalizeCaseModifier.new
        expected = 'This'

        actual = modifier.mutate('ThiS', nil)

        assert_equal expected, actual
    end
    def test_radom_case_modifier_can_make_uppercase
        modifier = RandomWordCaseModifier.new
        expected = 'THIS'

        actual = modifier.mutate('ThiS', EntropyMockReturnsConstantValue.new(0.2))

        assert_equal expected, actual
    end
    def test_radom_case_modifier_can_make_lowercase
        modifier = RandomWordCaseModifier.new
        expected = 'this'

        actual = modifier.mutate('ThiS', EntropyMockReturnsConstantValue.new(0.4))

        assert_equal expected, actual
    end
    def test_radom_case_modifier_can_make_capitalize
        modifier = RandomWordCaseModifier.new
        expected = 'This'

        actual = modifier.mutate('ThiS', EntropyMockReturnsConstantValue.new(0.8))

        assert_equal expected, actual
    end
    def test_alternating_case_modifier_alternates_between_lowercase_and_uppercase_start_with_lowercase
        modifier = AlternateCaseModifier.new(false)
        first_expected = 'this'
        second_expected = 'THIS'
        third_expected = 'this'

        first_actual = modifier.mutate('ThiS', nil)
        second_actual = modifier.mutate('ThiS', nil)
        third_actual = modifier.mutate('ThiS', nil)

        assert_equal first_expected, first_actual
        assert_equal second_expected, second_actual
        assert_equal third_expected, third_actual
    end
    def test_alternating_case_modifier_alternates_between_lowercase_and_uppercase_start_with_uppercase
        modifier = AlternateCaseModifier.new(true)
        first_expected = 'THIS'
        second_expected = 'this'
        third_expected = 'THIS'

        first_actual = modifier.mutate('ThiS', nil)
        second_actual = modifier.mutate('ThiS', nil)
        third_actual = modifier.mutate('ThiS', nil)

        assert_equal first_expected, first_actual
        assert_equal second_expected, second_actual
        assert_equal third_expected, third_actual
    end
    def test_modify_case
        words = ['this', 'THAT']
        passphrase = PassPhrase.new
        passphrase.words = words
        expected = ['This', 'That']
        
        actual = passphrase.mutate(CapitalizeCaseModifier.new)

        assert_equal expected, actual
    end
    def test_modify_letters_in_words_with_large_random_value
        words = ['This' 'That', 'ThAt']
        passphrase = PassPhrase.new(EntropyMockReturnsConstantValue.new(0.9))
        passphrase.words = words
        letter_map = {'a' => '@'}
        expected = ['This' 'Th@t', 'Th@t']
        
        actual = passphrase.modify_letters_in_words(letter_map)
        
        assert_equal expected, actual
    end
    def test_modify_letters_in_words_with_small_random_value_the_letter_is_not_altered
        words = ['This' 'That', 'ThAt']
        passphrase = PassPhrase.new(EntropyMockReturnsConstantValue.new(0.1))
        passphrase.words = words
        letter_map = {'a' => '@'}
        expected = ['This' 'That', 'ThAt']
        
        actual = passphrase.modify_letters_in_words(letter_map)
        
        assert_equal expected, actual
    end
    def test_modify_letters_with_large_random_value
        passphrase = PassPhrase.new(EntropyMockReturnsConstantValue.new(0.9))
        word = 'ThatAt'
        letter_map = {'a' => '@'}
        expected = 'Th@t@t'

        actual = passphrase.modify_letters(word, letter_map)

        assert_equal expected, actual
    end
    def test_modify_letters_with_small_random_value_the_letter_is_not_altered
        passphrase = PassPhrase.new(EntropyMockReturnsConstantValue.new(0.1))
        word = 'ThatAt'
        letter_map = {'a' => '@'}
        expected = 'ThatAt'

        actual = passphrase.modify_letters(word, letter_map)

        assert_equal expected, actual
    end
end

class ModifyLetterTests < Test::Unit::TestCase
    def test_modify_letters_with_with_positive_cointoss
        passphrase = PassPhrase.new(EntropyMockReturnsConstantValue.new(0.9))
        expected = 'Th%s %s'

        actual = passphrase.modify_letters('This Is', {'i'=>'%'})

        assert_equal expected, actual
    end
    def test_modify_letters_with_with_negative_cointoss
        passphrase = PassPhrase.new(EntropyMockReturnsConstantValue.new(0.1))
        expected = 'This Is'

        actual = passphrase.modify_letters('This Is', {'i'=>'%'})

        assert_equal expected, actual
    end
    def test_modify_one_letter_replaces_matching_letters
        passphrase = PassPhrase.new(EntropyMockReturnsConstantValue.new(0.9))
        expected = '%'

        actual = passphrase.modify_one_letter('i', {'i'=>'%'})

        assert_equal expected, actual
    end
    def test_modify_one_letter_returns_nonmatching_letters_unchanged
        passphrase = PassPhrase.new
        expected = 't'

        actual = passphrase.modify_one_letter('t', {'i'=>'%'})

        assert_equal expected, actual
    end
end

class RandomPointInPassphraseTests < Test::Unit::TestCase
end

class BuildNumberInjectorTests < Test::Unit::TestCase
    def test_build_between_number_injector
        injector = build_number_injector(:between)

        assert injector.instance_of? NumbersBetweenWordsInjector
    end
    def test_build_after_number_injector
        injector = build_number_injector(:after)

        assert injector.instance_of? NumbersAfterWordsInjector
    end
    def test_build_inside_number_injector
        injector = build_number_injector(:inside)

        assert injector.instance_of? NumbersInsideWordsInjector
    end
    def test_build_undefined_number_injector
        assert_raise(Exception) do
            build_number_injector(:foo)
        end
    end
end

class NumbersBetweenWordsInjectorTests < Test::Unit::TestCase
    def test_insert_zero_numbers
        injector = NumbersBetweenWordsInjector.new
        expected = ['a','b','c','d','e']
        entropy = EntropyMockReturnsValuesFromArray.new([0.1, 0.1])
        number_count = 0

        actual = injector.inject_numbers(['a','b','c','d','e'], number_count, entropy)

        assert_equal expected, actual
    end
    def test_insert_two_numbers
        injector = NumbersBetweenWordsInjector.new
        expected = ['20','40','a','b','c','d','e']
        entropy = EntropyMockReturnsValuesFromArray.new([0.1, 0.2, 0.3, 0.4])
        number_count = 2

        actual = injector.inject_numbers(['a','b','c','d','e'], number_count, entropy)

        assert_equal expected, actual
    end
    def test_small_first_random_number_results_in_injection_early_in_the_strinng
        injector = NumbersBetweenWordsInjector.new
        expected = ['10', 'a','b','c','d','e']
        entropy = EntropyMockReturnsValuesFromArray.new([0.1, 0.1])
        number_count = 1

        actual = injector.inject_numbers(['a','b','c','d','e'], number_count, entropy)

        assert_equal expected, actual
    end
    def test_large_first_random_number_results_in_injection_late_in_the_strinng
        injector = NumbersBetweenWordsInjector.new
        expected = ['a','b','c','d','e','10']
        entropy = EntropyMockReturnsValuesFromArray.new([1.0, 0.1])
        number_count = 1

        actual = injector.inject_numbers(['a','b','c','d','e'], number_count, entropy)

        assert_equal expected, actual
    end
    def test_second_random_number_is_injected_in_the_string
        injector = NumbersBetweenWordsInjector.new
        expected = ['a','b','c','d','e','47']
        entropy = EntropyMockReturnsValuesFromArray.new([1.0, 0.47])
        number_count = 1

        actual = injector.inject_numbers(['a','b','c','d','e'], number_count, entropy)

        assert_equal expected, actual
    end
end

class NumbersAfterWordsInjectorTests < Test::Unit::TestCase
    def test_insert_zero_numbers
        injector = NumbersAfterWordsInjector.new
        entropy = EntropyMockReturnsValuesFromArray.new([])
        number_count = 0
        expected = ['a','b','c','d','e']

        actual = injector.inject_numbers(['a','b','c','d','e'], number_count, entropy)

        assert_equal expected, actual
    end
    def test_insert_two_numbers
        injector = NumbersAfterWordsInjector.new
        entropy = EntropyMockReturnsValuesFromArray.new([0.1, 0.2, 0.3, 0.4])
        number_count = 2
        expected = ['a30','b40','c','d','e']

        actual = injector.inject_numbers(['a','b','c','d','e'], number_count, entropy)

        assert_equal expected, actual
    end
    def test_small_first_random_number_results_in_injection_early_in_the_string
        injector = NumbersAfterWordsInjector.new
        entropy = EntropyMockReturnsValuesFromArray.new([0.1, 0.1, 0.1])
        number_count = 1
        expected = ['a10','b','c','d','e']

        actual = injector.inject_numbers(['a','b','c','d','e'], number_count, entropy)

        assert_equal expected, actual
    end
    def test_large_first_random_number_results_in_injection_late_in_the_string
        injector = NumbersAfterWordsInjector.new
        number_count = 1
        random_number_locations = 0.9
        random_number_values = 0.13
        random_numbers = [random_number_locations, random_number_values].flatten
        entropy = EntropyMockReturnsValuesFromArray.new(random_numbers)
        expected = ['a','b','c','d','e13']

        actual = injector.inject_numbers(['a','b','c','d','e'], number_count, entropy)

        assert_equal expected, actual
    end
    def test_second_random_number_is_injected_in_the_strinng
        injector = NumbersAfterWordsInjector.new
        expected = ['a','b','c12','d','e']
        entropy = EntropyMockReturnsValuesFromArray.new([0.5, 0.12])
        number_count = 1

        actual = injector.inject_numbers(['a','b','c','d','e'], number_count, entropy)

        assert_equal expected, actual
    end
end

class NumbersInsideWordsInjectorTests < Test::Unit::TestCase
    def test_insert_zero_numbers
        injector = NumbersInsideWordsInjector.new
        entropy = EntropyMockReturnsValuesFromArray.new([])
        number_count = 0
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']

        actual = injector.inject_numbers(input, number_count, entropy)

        assert_equal expected, actual
    end
    def test_insert_two_numbers
        injector = NumbersInsideWordsInjector.new
        entropy = EntropyMockReturnsValuesFromArray.new([0.9, 0.8, 0.7, 0.6, 0.5, 0.8])
        number_count = 2
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddd50dd','eeeee70eeee']

        actual = injector.inject_numbers(input, number_count, entropy)

        assert_equal expected, actual
    end
    def test_small_first_random_number_results_in_injection_early_in_the_strinng
        injector = NumbersInsideWordsInjector.new
        entropy = EntropyMockReturnsValuesFromArray.new([0.1, 0.1, 0.1, 0.1])
        number_count = 1
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['10aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']

        actual = injector.inject_numbers(input, number_count, entropy)

        assert_equal expected, actual
    end
    def test_large_first_random_number_results_in_injection_late_in_the_strinng
        injector = NumbersInsideWordsInjector.new
        entropy = EntropyMockReturnsValuesFromArray.new([0.9, 0.1, 0.1, 0.1])
        number_count = 1
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','10eeeeeeeee']

        actual = injector.inject_numbers(input, number_count, entropy)

        assert_equal expected, actual
    end
    def test_second_random_number_is_injected
        injector = NumbersInsideWordsInjector.new
        entropy = EntropyMockReturnsValuesFromArray.new([0.5, 0.2, 0.1, 0.1])
        number_count = 1
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa','bbbbbbbbb','20ccccccccc','ddddddddd','eeeeeeeee']

        actual = injector.inject_numbers(input, number_count, entropy)

        assert_equal expected, actual
    end
    def test_small_third_random_number_results_in_injection_early_in_the_word
        injector = NumbersInsideWordsInjector.new
        entropy = EntropyMockReturnsValuesFromArray.new([0.5, 0.1, 0.1])
        number_count = 1
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa','bbbbbbbbb','10ccccccccc','ddddddddd','eeeeeeeee']

        actual = injector.inject_numbers(input, number_count, entropy)

        assert_equal expected, actual
    end
    def test_large_third_random_number_results_in_injection_late_in_the_word
        injector = NumbersInsideWordsInjector.new
        entropy = EntropyMockReturnsValuesFromArray.new([0.5, 0.1, 1.0])
        number_count = 1
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa','bbbbbbbbb','ccccccccc10','ddddddddd','eeeeeeeee']

        actual = injector.inject_numbers(input, number_count, entropy)

        assert_equal expected, actual
    end
end

class ComputedComplexityTests < Test::Unit::TestCase
    def test_zero_length_string
        options = default_options
        options[:word_count] = 0
        wordlist = []
        expected = 0.0
        
        phrase = PassPhrase.new
        phrase.create_pass_phrase(options, wordlist)
        actual = phrase.complexity

        assert_equal expected, actual
    end
    def test_one_word_in_word_list
        options = default_options
        options[:word_count] = 1
        wordlist = ['a']
        expected = 0.0
        
        phrase = PassPhrase.new
        phrase.create_pass_phrase(options, wordlist)
        actual = phrase.complexity

        assert_equal expected, actual
    end
    def test_random_case_modifier
        options = default_options
        options[:word_count] = 1
        options[:case_mode] = RandomWordCaseModifier.new
        wordlist = ['a']
        expected = log2(3)
        
        phrase = PassPhrase.new
        phrase.create_pass_phrase(options, wordlist)
        actual = phrase.complexity

        assert_equal expected, actual
    end
end

class BruteForceComplexityTests < Test::Unit::TestCase
    def test_lower_empty_string
        argument = ''
        expected = 0
        complexity = HaystackBruteForceComplexity.new

        actual = complexity.compute(argument)

        assert_equal expected, actual
    end
    def test_lower_case_letter
        argument = 'a'
        expected = log2(26)
        complexity = HaystackBruteForceComplexity.new

        actual = complexity.compute(argument)

        assert_equal expected, actual
    end
    def test_upper_case_letter
        argument = 'A'
        expected = log2(26)
        complexity = HaystackBruteForceComplexity.new

        actual = complexity.compute(argument)

        assert_equal expected, actual
    end
    def test_digit_letter
        argument = '0'
        expected = log2(10)
        complexity = HaystackBruteForceComplexity.new

        actual = complexity.compute(argument)

        assert_equal expected, actual
    end
    def test_upper_and_lower_case_letters
        argument = 'ab'
        expected = 2*log2(26)
        complexity = HaystackBruteForceComplexity.new

        actual = complexity.compute(argument)

        assert_equal expected, actual
    end
    def test_upper_and_lower_case_letters
        argument = 'aA'
        expected = 4*log2(26)
        complexity = HaystackBruteForceComplexity.new

        actual = complexity.compute(argument)

        assert_equal expected, actual
    end
end

class CreatePassPhraseTests < Test::Unit::TestCase
    def test_default_options
        passphrase = PassPhrase.new(EntropyMockReturnsConstantValue.new(0.9))
        options = default_options
        word_list = ['aa', 'bb', 'cc', 'dd']
        expected = 'dd dd dd dd'
        
        passphrase.create_pass_phrase(options, word_list)
        actual = passphrase.to_s

        assert_equal expected, actual        
    end
    def test_non_default_sepatator_character
        passphrase = PassPhrase.new(EntropyMockReturnsConstantValue.new(0.9))
        options = default_options
        options[:separator] = '-'
        word_list = ['aa', 'bb', 'cc', 'dd']
        expected = 'dd-dd-dd-dd'

        passphrase.create_pass_phrase(options, word_list)
        actual = passphrase.to_s

        assert_equal expected, actual        
    end
    def test_inject_numbers_between_words
        passphrase = PassPhrase.new(EntropyMockReturnsConstantValue.new(0.9))
        options = default_options
        options[:number_injector] = NumbersBetweenWordsInjector.new
        options[:number_count] = 1
        word_list = ['aa', 'bb', 'cc', 'dd']
        expected = 'dd dd dd 90 dd'

        passphrase.create_pass_phrase(options, word_list)
        actual = passphrase.to_s

        assert_equal expected, actual        
    end
    def test_inject_numbers_after_words
        passphrase = PassPhrase.new(EntropyMockReturnsConstantValue.new(0.5))
        options = default_options
        options[:number_injector] = NumbersAfterWordsInjector.new
        options[:number_count] = 1
        word_list = ['aaaaaaaaa', 'bbbbbbbbb', 'ccccccccc', 'ddddddddd']
        expected = 'ccccccccc ccccccccc ccccccccc50 ccccccccc'

        passphrase.create_pass_phrase(options, word_list)
        actual = passphrase.to_s

        assert_equal expected, actual        
    end
    def test_inject_numbers_inside_words
        passphrase = PassPhrase.new(EntropyMockReturnsConstantValue.new(0.5))
        options = default_options
        options[:number_injector] = NumbersInsideWordsInjector.new
        options[:number_count] = 1
        word_list = ['aaaaaaaaa', 'bbbbbbbbb', 'ccccccccc', 'ddddddddd']
        expected = 'ccccccccc ccccccccc cccc50ccccc ccccccccc'

        passphrase.create_pass_phrase(options, word_list)
        actual = passphrase.to_s

        assert_equal expected, actual        
    end
end

class IntegrationTests < Test::Unit::TestCase
    def test_default_behaviour
        expected = /^([a-zA-Z]+ ){4}$/

        actual = `./xkcdpass.rb -f sample_dict.txt`.strip + ' '

        assert_match expected, actual
    end
    def test_word_count_short_option
        expected = /^([a-zA-Z]+ ){6}$/

        actual = `./xkcdpass.rb -f sample_dict.txt -w 6`.strip + ' '

        assert_match expected, actual
    end
    def test_word_count_long_option
        expected = /^([a-zA-Z]+ ){6}$/

        actual = `./xkcdpass.rb -f sample_dict.txt --word_count 6`.strip + ' '

        assert_match expected, actual
    end
    def test_word_count_long_option_truncated
        expected = /^([a-zA-Z]+ ){6}$/

        actual = `./xkcdpass.rb -f sample_dict.txt --word 6`.strip + ' '

        assert_match expected, actual
    end
    def test_separator_string_short_option
        expected = /^([a-zA-Z]+X){4}$/

        actual = `./xkcdpass.rb -f sample_dict.txt -s X`.strip + 'X'

        assert_match expected, actual
    end
    def test_separator_string_long_option
        expected = /^([a-zA-Z]+yy){4}$/

        actual = `./xkcdpass.rb -f sample_dict.txt --separator yy`.strip + 'yy'

        assert_match expected, actual
    end
    def test_case_upper_short_option
        expected = /^([A-Z]+ ){4}$/

        actual = `./xkcdpass.rb -f sample_dict.txt -c upper`.strip + ' '

        assert_match expected, actual
    end
    def test_case_upper_long_option
        expected = /^([A-Z]+ ){4}$/

        actual = `./xkcdpass.rb -f sample_dict.txt --case upper`.strip + ' '

        assert_match expected, actual
    end
    def test_case_lower
        expected = /^([a-z]+ ){4}$/

        actual = `./xkcdpass.rb -f sample_dict.txt -c lower`.strip + ' '

        assert_match expected, actual
    end
    def test_case_capitalize
        expected = /^([A-Z][a-z]+ ){4}$/

        actual = `./xkcdpass.rb -f sample_dict.txt -c capitalize`.strip + ' '

        assert_match expected, actual
    end
    def test_case_alternate
        expected_lower_case_first = /([a-z]+ [A-Z]+ ){2}$/
        expected_upper_case_first = /([A-Z]+ [a-z]+ ){2}$/

        actual = `./xkcdpass.rb -f sample_dict.txt -c alternate`.strip + ' '

        assert (actual =~ expected_upper_case_first) || (actual =~ expected_lower_case_first)
    end
    def test_case_random
        expected = /^([A-Za-z]+ ){4}$/

        actual = `./xkcdpass.rb -f sample_dict.txt -c random`.strip + ' '

        assert_match expected, actual
    end
    def test_numbers_between
        expected = /^(([A-Za-z]+ )|([0-9]+ ))+$/

        actual = `./xkcdpass.rb -f sample_dict.txt -n between -d 2`.strip + ' '

        assert_match expected, actual
    end
    def test_numbers_after
        expected = /^([A-Za-z]+[0-9]* ){4}$/

        actual = `./xkcdpass.rb -f sample_dict.txt -n after -d 2`.strip + ' '

        assert_match expected, actual
    end
    def test_numbers_inside
        expected = /^([A-Za-z0-9]+ ){4}$/

        actual = `./xkcdpass.rb -f sample_dict.txt -n inside -d 2`.strip + ' '

        assert_match expected, actual
    end
end
