require 'pathname'
$LOAD_PATH << Pathname(__FILE__).dirname.realpath
require 'test/unit'
require 'test/unit/assertions.rb'
require 'xkcdpass.rb'

class EntropyMock
    def random(max)
        return (max * $RANDOM).to_i
    end
end

$ENTROPY = EntropyMock.new
$RANDOM = 0

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

        assert modifier.instance_of? RandomCaseModifier
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

        actual = modifier.modify_case('ThiS')

        assert_equal expected, actual
    end
    def test_lower_case_modifier
        modifier = DownCaseModifier.new
        expected = 'this'

        actual = modifier.modify_case('ThiS')

        assert_equal expected, actual
    end
    def test_capitalize_case_modifier
        modifier = CapitalizeCaseModifier.new
        expected = 'This'

        actual = modifier.modify_case('ThiS')

        assert_equal expected, actual
    end
    def test_radom_case_modifier_can_make_uppercase
        modifier = RandomCaseModifier.new
        expected = 'THIS'
        $RANDOM = 0.2

        actual = modifier.modify_case('ThiS')

        assert_equal expected, actual
    end
    def test_radom_case_modifier_can_make_lowercase
        modifier = RandomCaseModifier.new
        expected = 'this'
        $RANDOM = 0.4

        actual = modifier.modify_case('ThiS')

        assert_equal expected, actual
    end
    def test_radom_case_modifier_can_make_capitalize
        modifier = RandomCaseModifier.new
        expected = 'This'
        $RANDOM = 0.8

        actual = modifier.modify_case('ThiS')

        assert_equal expected, actual
    end
    def test_alternating_case_modifier_alternates_between_lowercase_and_uppercase
        modifier = AlternateCaseModifier.new
        first_expected = 'this'
        second_expected = 'THIS'
        third_expected = 'this'

        first_actual = modifier.modify_case('ThiS')
        second_actual = modifier.modify_case('ThiS')
        third_actual = modifier.modify_case('ThiS')

        assert_equal first_expected, first_actual
        assert_equal second_expected, second_actual
        assert_equal third_expected, third_actual
    end
    def test_modify_case
        words = ['this', 'THAT']
        passphrase = PassPhrase.new(words)
        expected = ['This', 'That']
        
        actual = passphrase.modify_case(CapitalizeCaseModifier.new)

        assert_equal expected, actual
    end
    def test_modify_letters_in_words_with_large_random_value
        words = ['This' 'That', 'ThAt']
        passphrase = PassPhrase.new(words)
        letter_map = {'a' => '@'}
        $RANDOM = 0.9
        expected = ['This' 'Th@t', 'Th@t']
        
        actual = passphrase.modify_letters_in_words(letter_map)
        
        assert_equal expected, actual
    end
    def test_modify_letters_in_words_with_small_random_value_the_letter_is_not_altered
        words = ['This' 'That', 'ThAt']
        passphrase = PassPhrase.new(words)
        letter_map = {'a' => '@'}
        $RANDOM = 0.1
        expected = ['This' 'That', 'ThAt']
        
        actual = passphrase.modify_letters_in_words(letter_map)
        
        assert_equal expected, actual
    end
    def test_modify_letters_with_large_random_value
        passphrase = PassPhrase.new([])
        word = 'ThatAt'
        letter_map = {'a' => '@'}
        $RANDOM = 0.9
        expected = 'Th@t@t'

        actual = passphrase.modify_letters(word, letter_map)

        assert_equal expected, actual
    end
    def test_modify_letters_with_small_random_value_the_letter_is_not_altered
        passphrase = PassPhrase.new([])
        word = 'ThatAt'
        letter_map = {'a' => '@'}
        $RANDOM = 0.1
        expected = 'ThatAt'

        actual = passphrase.modify_letters(word, letter_map)

        assert_equal expected, actual
    end
end

class ModifyLetterTests < Test::Unit::TestCase
    def test_modify_letters_with_with_positive_cointoss
        passphrase = PassPhrase.new([])
        expected = 'Th%s %s'
        $RANDOM = 0.9

        actual = passphrase.modify_letters('This Is', {'i'=>'%'})

        assert_equal expected, actual
    end
    def test_modify_letters_with_with_negative_cointoss
        passphrase = PassPhrase.new([])
        expected = 'This Is'
        $RANDOM = 0.1

        actual = passphrase.modify_letters('This Is', {'i'=>'%'})

        assert_equal expected, actual
    end
    def test_modify_one_letter_replaces_matching_letters
        passphrase = PassPhrase.new([])
        expected = '%'

        actual = passphrase.modify_one_letter('i', {'i'=>'%'})

        assert_equal expected, actual
    end
    def test_modify_one_letter_returns_nonmatching_letters_unchanged
        passphrase = PassPhrase.new([])
        expected = 't'

        actual = passphrase.modify_one_letter('t', {'i'=>'%'})

        assert_equal expected, actual
    end
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

class EntropyArrayMock
    def initialize(data)
        @data = data
    end
    def random(max)
        return (max * @data.shift).to_i
    end
end

class NumbersBetweenWordsInjectorTests < Test::Unit::TestCase
    def test_zero_number_density_gives_no_numbers_injected
        injector = NumbersBetweenWordsInjector.new
        expected = ['a','b','c','d','e']
        $ENTROPY = EntropyMock.new
        $RANDOM = 0.9
        number_density = 0

        actual = injector.inject_numbers(['a','b','c','d','e'], number_density)

        assert_equal expected, actual
    end
    def test_low_number_density_gives_few_numbers_injected
        injector = NumbersBetweenWordsInjector.new
        expected = ['a','b','10','c','d','e']
        $ENTROPY = EntropyArrayMock.new([0.9, 0.5, 0.1])
        number_density = 0.2

        actual = injector.inject_numbers(['a','b','c','d','e'], number_density)

        assert_equal expected, actual
    end
    def test_high_number_density_gives_many_numbers_injected
        injector = NumbersBetweenWordsInjector.new
        expected = ['20','40','a','60','b','80','c','d','e']
        $ENTROPY = EntropyArrayMock.new([0.9, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9])
        number_density = 0.8

        actual = injector.inject_numbers(['a','b','c','d','e'], number_density)

        assert_equal expected, actual
    end
    def test_small_random_number_results_in_no_injection
        injector = NumbersBetweenWordsInjector.new
        expected = ['a','b']
        $ENTROPY = EntropyMock.new
        $RANDOM = 0.1
        number_density = 0.5

        actual = injector.inject_numbers(['a','b'], number_density)

        assert_equal expected, actual
    end
    def test_large_random_number_results_in_injection
        injector = NumbersBetweenWordsInjector.new
        expected = ['a', '90', 'b']
        $ENTROPY = EntropyMock.new
        $RANDOM = 0.9
        number_density = 0.5

        actual = injector.inject_numbers(['a','b'], number_density)

        assert_equal expected, actual
    end
    def test_small_second_random_number_results_in_injection_early_in_the_strinng
        injector = NumbersBetweenWordsInjector.new
        expected = ['10', 'a','b','c','d','e']
        $ENTROPY = EntropyArrayMock.new([0.9, 0.1, 0.1])
        number_density = 0.25

        actual = injector.inject_numbers(['a','b','c','d','e'], number_density)

        assert_equal expected, actual
    end
    def test_large_second_random_number_results_in_injection_late_in_the_strinng
        injector = NumbersBetweenWordsInjector.new
        expected = ['a','b','c','d','e','10']
        $ENTROPY = EntropyArrayMock.new([0.9, 1.0, 0.1])
        number_density = 0.25

        actual = injector.inject_numbers(['a','b','c','d','e'], number_density)

        assert_equal expected, actual
    end
    def test_third_random_number_is_injected_in_the_string
        injector = NumbersBetweenWordsInjector.new
        expected = ['a','b','c','d','e','47']
        $ENTROPY = EntropyArrayMock.new([0.9, 1.0, 0.47])
        number_density = 0.25

        actual = injector.inject_numbers(['a','b','c','d','e'], number_density)

        assert_equal expected, actual
    end
end

class NumbersAfterWordsInjectorTests < Test::Unit::TestCase
    def test_zero_number_density_gives_no_numbers_injected
        injector = NumbersAfterWordsInjector.new
        expected = ['a','b','c','d','e']
        number_density = 0

        actual = injector.inject_numbers(['a','b','c','d','e'], number_density)

        assert_equal expected, actual
    end
    def test_low_number_density_gives_few_numbers_injected
        injector = NumbersAfterWordsInjector.new
        number_density = 0.2
        $ENTROPY = EntropyMock.new
        $RANDOM = 0.9
        expected = ['a','b','c','d','e90']

        actual = injector.inject_numbers(['a','b','c','d','e'], number_density)

        assert_equal expected, actual
    end
    def test_high_number_density_gives_many_numbers_injected
        injector = NumbersAfterWordsInjector.new
        number_density = 1.0
        random_number_density_scale = 1.0
        random_number_locations = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0, 0, 0]
        random_number_values = [0.13, 0.14, 0.15, 0.16, 0.17]
        random_numbers = [random_number_density_scale, random_number_locations, random_number_values].flatten
        $ENTROPY = EntropyArrayMock.new(random_numbers)
        expected = ['a13','b14','c15','d16','e17']

        actual = injector.inject_numbers(['a','b','c','d','e'], number_density)

        assert_equal expected, actual
    end
    def test_small_random_number_results_in_no_injection
        injector = NumbersAfterWordsInjector.new
        number_density = 0.5
        $ENTROPY = EntropyMock.new
        $RANDOM = 0.1
        expected = ['a','b','c','d','e']

        actual = injector.inject_numbers(['a','b','c','d','e'], number_density)

        assert_equal expected, actual
    end
    def test_large_random_number_results_in_injection
        injector = NumbersAfterWordsInjector.new
        number_density = 1.0
        $ENTROPY = EntropyMock.new
        $RANDOM = 0.9
        expected = ['a','b','c','d','e90']

        actual = injector.inject_numbers(['a','b','c','d','e'], number_density)

        assert_equal expected, actual
    end
    def test_small_second_random_number_results_in_injection_early_in_the_strinng
        injector = NumbersAfterWordsInjector.new
        $ENTROPY = EntropyArrayMock.new([0.9, 0.1, 0.1, 0.1])
        number_density = 0.25
        expected = ['a10','b','c','d','e']

        actual = injector.inject_numbers(['a','b','c','d','e'], number_density)

        assert_equal expected, actual
    end
    def test_large_second_random_number_results_in_injection_late_in_the_strinng
        injector = NumbersAfterWordsInjector.new
        number_density = 0.25
        random_number_density_scale = 0.5
        random_number_locations = 0.9
        random_number_values = 0.13
        random_numbers = [random_number_density_scale, random_number_locations, random_number_values].flatten
        $ENTROPY = EntropyArrayMock.new(random_numbers)
        expected = ['a','b','c','d','e13']

        actual = injector.inject_numbers(['a','b','c','d','e'], number_density)

        assert_equal expected, actual
    end
    def test_third_random_number_is_injected_in_the_strinng
        injector = NumbersAfterWordsInjector.new
        expected = ['a','b','c12','d','e']
        $ENTROPY = EntropyArrayMock.new([0.9, 0.5, 0.12, 0.13]) # why is the 13 needed
        number_density = 0.25

        actual = injector.inject_numbers(['a','b','c','d','e'], number_density)

        assert_equal expected, actual
    end
end

class NumbersInsideWordsInjectorTests < Test::Unit::TestCase
    def test_zero_number_density_gives_no_numbers_injected
        injector = NumbersInsideWordsInjector.new
        number_density = 0
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']

        actual = injector.inject_numbers(input, number_density)

        assert_equal expected, actual
    end
    def test_low_number_density_gives_few_numbers_injected
        injector = NumbersInsideWordsInjector.new
        number_density = 0.2
        $ENTROPY = EntropyMock.new
        $RANDOM = 0.9
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeee90e']

        actual = injector.inject_numbers(input, number_density)

        assert_equal expected, actual
    end
    def test_high_number_density_gives_many_numbers_injected
        injector = NumbersInsideWordsInjector.new
        number_density = 1.0
        random_numbers = [0.9, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.21, 0.31, 0.41, 0.51, 0.61, 0.71, 0.81, 0.91, 0.22, 0.32, 0.42]
        $ENTROPY = EntropyArrayMock.new(random_numbers)

        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa', 'bbbbb51bbbb', 'ccccccc71cc', 'd91dddddddd', 'eee32eeeeee']

        actual = injector.inject_numbers(input, number_density)

        assert_equal expected, actual
    end
    def test_small_random_number_results_in_no_injection
        injector = NumbersInsideWordsInjector.new
        number_density = 1.0
        random_numbers = [0.0, 0.2]
        $ENTROPY = EntropyArrayMock.new(random_numbers)

        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']

        actual = injector.inject_numbers(input, number_density)

        assert_equal expected, actual
    end
    def test_large_random_number_results_in_injection
        injector = NumbersInsideWordsInjector.new
        number_density = 1.0
        $ENTROPY = EntropyMock.new
        $RANDOM = 0.9

        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeee90e']

        actual = injector.inject_numbers(input, number_density)

        assert_equal expected, actual
    end
    def test_small_second_random_number_results_in_injection_early_in_the_strinng
        injector = NumbersInsideWordsInjector.new
        $ENTROPY = EntropyArrayMock.new([0.9, 0.1, 0.1, 0.1, 0.1])
        number_density = 0.25
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['10aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']

        actual = injector.inject_numbers(input, number_density)

        assert_equal expected, actual
    end
    def test_large_second_random_number_results_in_injection_late_in_the_strinng
        injector = NumbersInsideWordsInjector.new
        $ENTROPY = EntropyArrayMock.new([0.9, 0.9, 0.1, 0.1, 0.1])
        number_density = 0.25
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','10eeeeeeeee']

        actual = injector.inject_numbers(input, number_density)

        assert_equal expected, actual
    end
    def test_third_random_number_is_injected
        injector = NumbersInsideWordsInjector.new
        $ENTROPY = EntropyArrayMock.new([0.9, 0.5, 0.2, 0.1, 0.1])
        number_density = 0.25
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa','bbbbbbbbb','20ccccccccc','ddddddddd','eeeeeeeee']

        actual = injector.inject_numbers(input, number_density)

        assert_equal expected, actual
    end
    def test_small_fourth_random_number_results_in_injection_early_in_the_word
        injector = NumbersInsideWordsInjector.new
        $ENTROPY = EntropyArrayMock.new([0.9, 0.5, 0.1, 0.1])
        number_density = 0.25
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa','bbbbbbbbb','10ccccccccc','ddddddddd','eeeeeeeee']

        actual = injector.inject_numbers(input, number_density)

        assert_equal expected, actual
    end
    def test_large_fourth_random_number_results_in_injection_late_in_the_word
        injector = NumbersInsideWordsInjector.new
        $ENTROPY = EntropyArrayMock.new([0.9, 0.5, 0.1, 1.0])
        number_density = 0.25
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa','bbbbbbbbb','ccccccccc10','ddddddddd','eeeeeeeee']

        actual = injector.inject_numbers(input, number_density)

        assert_equal expected, actual
    end
end

class CreatePassPhraseTests < Test::Unit::TestCase
    def test_default_options
        passphrase = PassPhrase.new([])
        options = default_options
        word_list = ['aa', 'bb', 'cc', 'dd']
        $RANDOM = 0.9
        expected = 'dd dd dd dd dd dd'
        
        actual = passphrase.create_pass_phrase(options, word_list)
        
        assert_equal expected, actual        
    end
    def test_min_word_count_with_small_random_number_value
        passphrase = PassPhrase.new([])
        options = default_options
        options[:min_word_count] = 6
        options[:max_word_count] = 8
        word_list = ['aa', 'bb', 'cc', 'dd']
        $RANDOM = 0.1
        expected = 'aa aa aa aa aa aa'
        
        actual = passphrase.create_pass_phrase(options, word_list)
        
        assert_equal expected, actual        
    end
    def test_max_word_count_with_large_random_number_value
        passphrase = PassPhrase.new([])
        options = default_options
        options[:min_word_count] = 6
        options[:max_word_count] = 8
        word_list = ['aa', 'bb', 'cc', 'dd']
        $RANDOM = 0.9
        expected = 'dd dd dd dd dd dd dd dd'

        actual = passphrase.create_pass_phrase(options, word_list)

        assert_equal expected, actual        
    end
    def test_non_default_sepatator_character
        passphrase = PassPhrase.new([])
        options = default_options
        options[:separator] = '-'
        word_list = ['aa', 'bb', 'cc', 'dd']
        $RANDOM = 0.9
        expected = 'dd-dd-dd-dd-dd-dd'

        actual = passphrase.create_pass_phrase(options, word_list)

        assert_equal expected, actual        
    end
    def test_inject_numbers_between_words
        passphrase = PassPhrase.new([])
        options = default_options
        options[:number_injector] = NumbersBetweenWordsInjector.new
        word_list = ['aa', 'bb', 'cc', 'dd']
        $RANDOM = 0.9
        expected = 'dd dd dd dd dd 90 90 90 dd'

        actual = passphrase.create_pass_phrase(options, word_list)

        assert_equal expected, actual        
    end
    def test_inject_numbers_after_words
        passphrase = PassPhrase.new([])
        options = default_options
        options[:number_injector] = NumbersAfterWordsInjector.new
        word_list = ['aaaaaaaaa', 'bbbbbbbbb', 'ccccccccc', 'ddddddddd']
        $RANDOM = 0.5
        expected = 'ccccccccc ccccccccc ccccccccc50 ccccccccc ccccccccc'

        actual = passphrase.create_pass_phrase(options, word_list)

        assert_equal expected, actual        
    end
    def test_inject_numbers_inside_words
        passphrase = PassPhrase.new([])
        options = default_options
        options[:number_injector] = NumbersInsideWordsInjector.new
        word_list = ['aaaaaaaaa', 'bbbbbbbbb', 'ccccccccc', 'ddddddddd']
        $RANDOM = 0.5
        expected = 'ccccccccc ccccccccc cccc50ccccc ccccccccc ccccccccc'

        actual = passphrase.create_pass_phrase(options, word_list)

        assert_equal expected, actual        
    end
end
