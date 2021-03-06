require 'pathname'
$LOAD_PATH << Pathname(__FILE__).dirname.realpath
require 'test/unit'
require 'test/unit/assertions.rb'
require 'xkcdpass.rb'

class RandomSourceMockBase
    def entropy
        1.0
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

class RandomSourceMockReturnsConstantValue < RandomSourceMockBase
    def initialize(mock_random_value)
        raise 'random must be less than one' if mock_random_value > 1
        raise 'random must be greater than zero' if mock_random_value < 0
        @mock_random_value = mock_random_value
    end
    def random(max)
        return (max * @mock_random_value).to_i
    end
end

class RandomSourceMockReturnsValuesFromArray < RandomSourceMockBase
    def initialize(data)
        @data = data
    end
    def random(max)
        return (max * @data.shift).to_i
    end
end

class RandomNumberGeneratorTests < Test::Unit::TestCase
    def pick_zero_random_value_from_range
        max_range = 6
        expected = []

        actual = pick_n_from_m(0, max_range)

        assert_equal expected, actual
    end
    def pick_one_random_value_from_range
        max_range = 6

        actual = pick_n_from_m(1, max_range)

        assert actual.size == 1
        assert actual[0] > -1
        assert actual[0] < max_range
    end
    def pick_two_random_value_from_range
        max_range = 6

        actual = pick_n_from_m(2, max_range)

        assert actual.size == 2
        assert actual[0] > -1
        assert actual[0] < max_range
        assert actual[1] > -1
        assert actual[1] < max_range
        assert actual[0] < actual[1]
    end
    def pick_three_random_value_from_range_of_two_elements
        max_range = 2

        actual = pick_n_from_m(3, max_range)

        assert actual.size == 2
        assert actual[0] > -1
        assert actual[0] < max_range
        assert actual[1] > -1
        assert actual[1] < max_range
        assert actual[0] < actual[1]
    end
end

class BuildCaseModifierTests < Test::Unit::TestCase
    def test_build_uppercase_modifier
        application = Application.new
        modifier = application.build_case_modifier(:upper)

        assert modifier.instance_of? UpCaseModifier
    end
    def test_build_lowercase_modifier
        application = Application.new
        modifier = application.build_case_modifier(:lower)

        assert modifier.instance_of? DownCaseModifier
    end
    def test_build_capitalize_modifier
        application = Application.new
        modifier = application.build_case_modifier(:capitalize)

        assert modifier.instance_of? CapitalizeCaseModifier
    end
    def test_build_random_modifier
        application = Application.new
        modifier = application.build_case_modifier(:random)

        assert modifier.instance_of? RandomWordCaseModifier
    end
    def test_build_alternate_modifier
        application = Application.new
        modifier = application.build_case_modifier(:alternate)

        assert modifier.instance_of? AlternateCaseModifier
    end
    def test_build_undefined_modifier
        application = Application.new
        assert_raise(Exception) do
            modifier = application.build_case_modifier(:foo)
        end
    end
end

class CaseModifierTests < Test::Unit::TestCase
    def test_upper_case_modifier
        modifier = UpCaseModifier.new
        expected = 'THIS'

        actual = modifier.mutate_word('ThiS', nil)

        assert_equal expected, actual
    end
    def test_lower_case_modifier
        modifier = DownCaseModifier.new
        expected = 'this'

        actual = modifier.mutate_word('ThiS', nil)

        assert_equal expected, actual
    end
    def test_capitalize_case_modifier
        modifier = CapitalizeCaseModifier.new
        expected = 'This'

        actual = modifier.mutate_word('ThiS', nil)

        assert_equal expected, actual
    end
    def test_radom_case_modifier_can_make_uppercase
        modifier = RandomWordCaseModifier.new
        expected = 'THIS'

        actual = modifier.mutate_word('ThiS', RandomSourceMockReturnsConstantValue.new(0.2))

        assert_equal expected, actual
    end
    def test_radom_case_modifier_can_make_lowercase
        modifier = RandomWordCaseModifier.new
        expected = 'this'

        actual = modifier.mutate_word('ThiS', RandomSourceMockReturnsConstantValue.new(0.4))

        assert_equal expected, actual
    end
    def test_radom_case_modifier_can_make_capitalize
        modifier = RandomWordCaseModifier.new
        expected = 'This'

        actual = modifier.mutate_word('ThiS', RandomSourceMockReturnsConstantValue.new(0.8))

        assert_equal expected, actual
    end
    def test_alternating_case_modifier_alternates_between_lowercase_and_uppercase_start_with_lowercase
        random_source = RandomSourceMockReturnsConstantValue.new(0.1)
        modifier = AlternateCaseModifier.new
        first_expected = 'this'
        second_expected = 'THIS'
        third_expected = 'this'

        first_actual = modifier.mutate_word('ThiS', random_source)
        second_actual = modifier.mutate_word('ThiS', random_source)
        third_actual = modifier.mutate_word('ThiS', random_source)

        assert_equal first_expected, first_actual
        assert_equal second_expected, second_actual
        assert_equal third_expected, third_actual
    end
    def test_alternating_case_modifier_alternates_between_lowercase_and_uppercase_start_with_uppercase
        random_source = RandomSourceMockReturnsConstantValue.new(0.9)
        modifier = AlternateCaseModifier.new
        first_expected = 'THIS'
        second_expected = 'this'
        third_expected = 'THIS'

        first_actual = modifier.mutate_word('ThiS', random_source)
        second_actual = modifier.mutate_word('ThiS', random_source)
        third_actual = modifier.mutate_word('ThiS', random_source)

        assert_equal first_expected, first_actual
        assert_equal second_expected, second_actual
        assert_equal third_expected, third_actual
    end
    def test_modify_case
        words = ['this', 'THAT']
        modifier = CapitalizeCaseModifier.new
        expected = ['This', 'That']
        
        actual = modifier.mutate(words, nil)

        assert_equal expected, actual
    end
end

class ModifyLetterTests < Test::Unit::TestCase
    def test_modify_one_letter_replaces_matching_letters
        random_source = RandomSourceMockReturnsConstantValue.new(0.9)
        modifier = LetterModifier.new({}, 0)
        expected = '%'

        actual = modifier.modify_one_letter('i', {'i'=>'%'}, random_source)

        assert_equal expected, actual
    end
    def test_modify_one_letter_with_negative_cointoss_does_not_replace_matching_letters
        random_source = RandomSourceMockReturnsConstantValue.new(0.1)
        modifier = LetterModifier.new({}, 0)
        expected = 'i'

        actual = modifier.modify_one_letter('i', {'i'=>'%'}, random_source)

        assert_equal expected, actual
    end
    def test_modify_one_letter_returns_nonmatching_letters_unchanged
        random_source = RandomSourceMockReturnsConstantValue.new(0.9)
        modifier = LetterModifier.new({}, 0)
        expected = 't'

        actual = modifier.modify_one_letter('t', {'i'=>'%'}, random_source)

        assert_equal expected, actual
    end
    def test_modify_letters_with_with_positive_cointoss_replaces_matching_letters
        random_source = RandomSourceMockReturnsConstantValue.new(0.9)
        modifier = LetterModifier.new({}, 0)
        expected = 'Th%s %s'

        actual = modifier.modify_letters('This Is', {'i'=>'%'}, random_source)

        assert_equal expected, actual
    end
    def test_modify_letters_with_with_negative_cointoss_does_not_replace_letters
        random_source = RandomSourceMockReturnsConstantValue.new(0.1)
        modifier = LetterModifier.new({}, 0)
        expected = 'This Is'

        actual = modifier.modify_letters('This Is', {'i'=>'%'}, random_source)

        assert_equal expected, actual
    end
    def test_modify_letters_in_one_word_only
        random_source = RandomSourceMockReturnsConstantValue.new(0.9)
        letter_map = {'a' => '@'}
        number_of_words_to_modify = 1
        modifier = LetterModifier.new(letter_map, number_of_words_to_modify)
        words    = ['This', 'That', 'ThAt']
        expected = ['This', 'That', 'Th@t']
        
        actual = modifier.mutate(words, random_source)
        
        assert_equal expected, actual
    end
    def test_modify_letters_in_all_three_word_only
        random_source = RandomSourceMockReturnsConstantValue.new(0.9)
        letter_map = {'a' => '@'}
        number_of_words_to_modify = 3
        modifier = LetterModifier.new(letter_map, number_of_words_to_modify)
        words    = ['This', 'That', 'ThAt']
        expected = ['This', 'Th@t', 'Th@t']
        
        actual = modifier.mutate(words, random_source)
        
        assert_equal expected, actual
    end
    def test_modify_letters_with_large_random_value
        random_source = RandomSourceMockReturnsConstantValue.new(0.9)
        letter_map = {'a' => '@'}
        modifier = LetterModifier.new(letter_map, 0)
        word = 'ThatAt'
        expected = 'Th@t@t'

        actual = modifier.modify_letters(word, letter_map, random_source)

        assert_equal expected, actual
    end
    def test_modify_letters_with_small_random_value_the_letter_is_not_altered
        random_source = RandomSourceMockReturnsConstantValue.new(0.1)
        letter_map = {'a' => '@'}
        modifier = LetterModifier.new(letter_map, 0)
        word = 'ThatAt'
        expected = 'ThatAt'

        actual = modifier.modify_letters(word, letter_map, random_source)

        assert_equal expected, actual
    end
end

class BuildNumberInjectorTests < Test::Unit::TestCase
    def test_build_between_number_injector
        application = Application.new
        injector = application.build_number_injector(:between, 1)

        assert injector.instance_of? NumbersBetweenWordsInjector
    end
    def test_build_inside_number_injector
        application = Application.new
        injector = application.build_number_injector(:inside, 1)

        assert injector.instance_of? NumbersInsideWordsInjector
    end
    def test_build_undefined_number_injector
        application = Application.new
        assert_raise(Exception) do
            application.build_number_injector(:foo, 1)
        end
    end
end

class StutterModifierTest < Test::Unit::TestCase
    def test_syllables_empty_string
        modifier = StutterModifier.new(0)
        expected = []

        actual = modifier.split_into_syllables('')

        assert_equal expected, actual
    end
    def test_syllables_one_syllable
        modifier = StutterModifier.new(0)
        expected = ['foo']

        actual = modifier.split_into_syllables('foo')

        assert_equal expected, actual
    end
    def test_syllables_two_syllables
        modifier = StutterModifier.new(0)
        expected = ['foo','bla']

        actual = modifier.split_into_syllables('foobla')

        assert_equal expected, actual
    end
    def test_syllables_leading_vowels
        modifier = StutterModifier.new(0)
        expected = ['ae','foo','bla']

        actual = modifier.split_into_syllables('aefoobla')

        assert_equal expected, actual
    end
end

class NumbersBetweenWordsInjectorTests < Test::Unit::TestCase
    def test_insert_zero_numbers
        number_count = 0
        injector = NumbersBetweenWordsInjector.new(number_count)
        expected = ['a','b','c','d','e']
        random_source = RandomSourceMockReturnsValuesFromArray.new([0.1, 0.1])

        actual = injector.mutate(['a','b','c','d','e'], random_source)

        assert_equal expected, actual
    end
    def test_insert_two_numbers
        number_count = 2
        injector = NumbersBetweenWordsInjector.new(number_count)
        expected = ['20','40','a','b','c','d','e']
        random_source = RandomSourceMockReturnsValuesFromArray.new([0.1, 0.2, 0.3, 0.4])

        actual = injector.mutate(['a','b','c','d','e'], random_source)

        assert_equal expected, actual
    end
    def test_small_first_random_number_results_in_injection_early_in_the_strinng
        number_count = 1
        injector = NumbersBetweenWordsInjector.new(number_count)
        expected = ['10', 'a','b','c','d','e']
        random_source = RandomSourceMockReturnsValuesFromArray.new([0.1, 0.1])

        actual = injector.mutate(['a','b','c','d','e'], random_source)

        assert_equal expected, actual
    end
    def test_large_first_random_number_results_in_injection_late_in_the_strinng
        number_count = 1
        injector = NumbersBetweenWordsInjector.new(number_count)
        expected = ['a','b','c','d','e','10']
        random_source = RandomSourceMockReturnsValuesFromArray.new([1.0, 0.1])

        actual = injector.mutate(['a','b','c','d','e'], random_source)

        assert_equal expected, actual
    end
    def test_second_random_number_is_injected_in_the_string
        number_count = 1
        injector = NumbersBetweenWordsInjector.new(number_count)
        expected = ['a','b','c','d','e','47']
        random_source = RandomSourceMockReturnsValuesFromArray.new([1.0, 0.47])

        actual = injector.mutate(['a','b','c','d','e'], random_source)

        assert_equal expected, actual
    end
end

class NumbersInsideWordsInjectorTests < Test::Unit::TestCase
    def test_insert_zero_numbers
        number_count = 0
        injector = NumbersInsideWordsInjector.new(number_count)
        random_source = RandomSourceMockReturnsValuesFromArray.new([])
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']

        actual = injector.mutate(input, random_source)

        assert_equal expected, actual
    end
    def test_insert_two_numbers
        number_count = 2
        injector = NumbersInsideWordsInjector.new(number_count)
        random_source = RandomSourceMockReturnsValuesFromArray.new([0.9, 0.8, 0.7, 0.6, 0.5, 0.8])
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddd70dddd','eeeeeee50ee']

        actual = injector.mutate(input, random_source)

        assert_equal expected, actual
    end
    def test_small_first_random_number_results_in_injection_early_in_the_strinng
        number_count = 1
        injector = NumbersInsideWordsInjector.new(number_count)
        random_source = RandomSourceMockReturnsValuesFromArray.new([0.1, 0.1, 0.1, 0.1])
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['10aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']

        actual = injector.mutate(input, random_source)

        assert_equal expected, actual
    end
    def test_large_first_random_number_results_in_injection_late_in_the_strinng
        number_count = 1
        injector = NumbersInsideWordsInjector.new(number_count)
        random_source = RandomSourceMockReturnsValuesFromArray.new([0.9, 0.1, 0.1, 0.1])
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','10eeeeeeeee']

        actual = injector.mutate(input, random_source)

        assert_equal expected, actual
    end
    def test_second_random_number_is_injected
        number_count = 1
        injector = NumbersInsideWordsInjector.new(number_count)
        random_source = RandomSourceMockReturnsValuesFromArray.new([0.5, 0.2, 0.1, 0.1])
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa','bbbbbbbbb','20ccccccccc','ddddddddd','eeeeeeeee']

        actual = injector.mutate(input, random_source)

        assert_equal expected, actual
    end
    def test_small_third_random_number_results_in_injection_early_in_the_word
        number_count = 1
        injector = NumbersInsideWordsInjector.new(number_count)
        random_source = RandomSourceMockReturnsValuesFromArray.new([0.5, 0.1, 0.1])
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa','bbbbbbbbb','10ccccccccc','ddddddddd','eeeeeeeee']

        actual = injector.mutate(input, random_source)

        assert_equal expected, actual
    end
    def test_large_third_random_number_results_in_injection_late_in_the_word
        number_count = 1
        injector = NumbersInsideWordsInjector.new(number_count)
        random_source = RandomSourceMockReturnsValuesFromArray.new([0.5, 0.1, 1.0])
        input    = ['aaaaaaaaa','bbbbbbbbb','ccccccccc','ddddddddd','eeeeeeeee']
        expected = ['aaaaaaaaa','bbbbbbbbb','ccccccccc10','ddddddddd','eeeeeeeee']

        actual = injector.mutate(input, random_source)

        assert_equal expected, actual
    end
end

class ComputedComplexityTests < Test::Unit::TestCase
    def test_zero_length_string
        application = Application.new
        options = application.default_options
        options[:word_count] = 0
        wordlist = []
        expected = 0.0
        
        phrase = PassPhrase.new
        phrase.create_pass_phrase(options, wordlist)
        actual = phrase.dictionary_complexity

        assert_equal expected, actual
    end
    def test_one_word_in_word_list
        application = Application.new
        options = application.default_options
        options[:word_count] = 1
        wordlist = ['a']
        expected = 0.0
        
        phrase = PassPhrase.new
        phrase.create_pass_phrase(options, wordlist)
        actual = phrase.dictionary_complexity

        assert_equal expected, actual
    end
    def test_random_case_modifier
        application = Application.new
        options = application.default_options
        options[:word_count] = 1
        options[:case_mode] = RandomWordCaseModifier.new
        wordlist = ['a']
        expected = log2(3)
        
        phrase = PassPhrase.new
        phrase.create_pass_phrase(options, wordlist)
        actual = phrase.dictionary_complexity

        assert_equal expected, actual
    end
end

class PassphraseLongevityTests < Test::Unit::TestCase
    def test_one_hundred_attacks_per_second
        bits = log2(400)
        attacks_per_second = 100
        
        actual = PassphraseLongevity.new(bits, attacks_per_second)
        
        assert_equal '4.0 seconds', actual.to_s
    end
    def test_two_seconds
        bits = 1
        attacks_per_second = 1
        
        actual = PassphraseLongevity.new(bits, attacks_per_second)
        
        assert_equal '2.0 seconds', actual.to_s
    end
    def test_two_minutes
        bits = log2(60*2)
        attacks_per_second = 1
        
        actual = PassphraseLongevity.new(bits, attacks_per_second)
        
        assert_equal '2.0 minutes', actual.to_s
    end
    def test_two_hours
        bits = log2(60*60*2)
        attacks_per_second = 1
        
        actual = PassphraseLongevity.new(bits, attacks_per_second)
        
        assert_equal '2.0 hours', actual.to_s
    end
    def test_two_day2
        bits = log2(24*60*60*2)
        attacks_per_second = 1
        
        actual = PassphraseLongevity.new(bits, attacks_per_second)
        
        assert_equal '2.0 days', actual.to_s
    end
    def test_two_week2
        bits = log2(7*24*60*60*2)
        attacks_per_second = 1
        
        actual = PassphraseLongevity.new(bits, attacks_per_second)
        
        assert_equal '2.0 weeks', actual.to_s
    end
    def test_two_month2
        bits = log2(30*24*60*60*2)
        attacks_per_second = 1
        
        actual = PassphraseLongevity.new(bits, attacks_per_second)
        
        assert_equal '2.0 months', actual.to_s
    end
    def test_two_years
        bits = log2(365*24*60*60*2)
        attacks_per_second = 1
        
        actual = PassphraseLongevity.new(bits, attacks_per_second)
        
        assert_equal '2.0 years', actual.to_s
    end
    def test_two_millenia
        bits = log2(1000*365*24*60*60*2)
        attacks_per_second = 1
        
        actual = PassphraseLongevity.new(bits, attacks_per_second)
        
        assert_equal '2.0 millenia', actual.to_s
    end
end

class BruteForceComplexityTests < Test::Unit::TestCase
    def test_lower_empty_string
        argument = ''
        expected = 0

        actual = compute_brute_force_complexity(argument)

        assert_equal expected, actual
    end
    def test_lower_case_letter
        argument = 'a'
        expected = log2(26)

        actual = compute_brute_force_complexity(argument)

        assert_equal expected, actual
    end
    def test_upper_case_letter
        argument = 'A'
        expected = log2(26)

        actual = compute_brute_force_complexity(argument)

        assert_equal expected, actual
    end
    def test_digit_letter
        argument = '0'
        expected = log2(10)

        actual = compute_brute_force_complexity(argument)

        assert_equal expected, actual
    end
    def test_upper_and_lower_case_letters
        argument = 'ab'
        expected = 2*log2(26)

        actual = compute_brute_force_complexity(argument)

        assert_equal expected, actual
    end
    def test_upper_and_lower_case_letters
        argument = 'aA'
        expected = 4*log2(26)

        actual = compute_brute_force_complexity(argument)

        assert_equal expected, actual
    end
end

class CreatePassPhraseTests < Test::Unit::TestCase
    def test_default_options
        application = Application.new
        passphrase = PassPhrase.new(RandomSourceMockReturnsConstantValue.new(0.9))
        options = application.default_options
        word_list = ['aa', 'bb', 'cc', 'dd']
        expected = 'dd dd dd dd'
        
        passphrase.create_pass_phrase(options, word_list)
        actual = passphrase.to_s

        assert_equal expected, actual        
    end
    def test_non_default_sepatator_character
        application = Application.new
        passphrase = PassPhrase.new(RandomSourceMockReturnsConstantValue.new(0.9))
        options = application.default_options
        options[:separator] = '-'
        word_list = ['aa', 'bb', 'cc', 'dd']
        expected = 'dd-dd-dd-dd'

        passphrase.create_pass_phrase(options, word_list)
        actual = passphrase.to_s

        assert_equal expected, actual        
    end
    def test_inject_numbers_between_words
        application = Application.new
        passphrase = PassPhrase.new(RandomSourceMockReturnsConstantValue.new(0.9))
        options = application.default_options
        number_count = 1
        options[:number_injector] = NumbersBetweenWordsInjector.new(number_count)
        word_list = ['aa', 'bb', 'cc', 'dd']
        expected = 'dd dd dd 90 dd'

        passphrase.create_pass_phrase(options, word_list)
        actual = passphrase.to_s

        assert_equal expected, actual        
    end
    def test_inject_numbers_inside_words
        application = Application.new
        passphrase = PassPhrase.new(RandomSourceMockReturnsConstantValue.new(0.5))
        options = application.default_options
        number_count = 1
        options[:number_injector] = NumbersInsideWordsInjector.new(number_count)
        word_list = ['aaaaaaaaa', 'bbbbbbbbb', 'ccccccccc', 'ddddddddd']
        expected = 'ccccccccc ccccccccc cccc50ccccc ccccccccc'

        passphrase.create_pass_phrase(options, word_list)
        actual = passphrase.to_s

        assert_equal expected, actual        
    end
end

class MockPassPhrase
    attr_reader :dictionary_complexity, :brute_force_complexity
    def initialize(dictionary_complexity, brute_force_complexity, passphrase)
        @dictionary_complexity = dictionary_complexity
        @brute_force_complexity = brute_force_complexity
        @passphrase = passphrase
    end
    def to_s
        @passphrase
    end
end

class LoggerBaseTests < Test::Unit::TestCase
    def test_dictionary_complexity
        attacks_per_second = 1
        dictionary_complexity = 2
        brute_force_complexity = 4
        logger = LoggerBase.new(attacks_per_second)
        pass_phrase = MockPassPhrase.new(dictionary_complexity, brute_force_complexity, '')
        expected = 2.0
        
        actual = logger.dictionary_complexity(pass_phrase)
        
        assert_equal expected, actual        
    end
    def test_brute_force_complexity
        attacks_per_second = 1
        dictionary_complexity = 2
        brute_force_complexity = 4
        logger = LoggerBase.new(attacks_per_second)
        pass_phrase = MockPassPhrase.new(dictionary_complexity, brute_force_complexity, '')
        expected = 4.0
        
        actual = logger.brute_force_complexity(pass_phrase)
        
        assert_equal expected, actual        
    end
    def test_dictionary_longevity
        attacks_per_second = 1
        dictionary_complexity = 2
        brute_force_complexity = 4
        logger = LoggerBase.new(attacks_per_second)
        pass_phrase = MockPassPhrase.new(dictionary_complexity, brute_force_complexity, '')
        expected = "4.0 seconds"
        
        actual = logger.dictionary_longevity(pass_phrase)
        
        assert_equal expected, actual        
    end
    def test_brute_force_longevity
        attacks_per_second = 1
        dictionary_complexity = 2
        brute_force_complexity = 4
        logger = LoggerBase.new(attacks_per_second)
        pass_phrase = MockPassPhrase.new(dictionary_complexity, brute_force_complexity, '')
        expected = "16.0 seconds"
        
        actual = logger.brute_force_longevity(pass_phrase)
        
        assert_equal expected, actual        
    end
    def test_brief_output
        logger = LoggerBase.new(1)
        comment = 'Comment'
        pass_phrase = MockPassPhrase.new(2, 4, 'passphrase')
        expected = "Comment: Dictionary=2.0 BruteForce=4.0 Phrase='passphrase'"
        
        actual = logger.brief(pass_phrase, comment)
        
        assert_equal expected, actual        
    end
    def test_full_output
        logger = LoggerBase.new(1)
        comment = 'Comment'
        pass_phrase = MockPassPhrase.new(2, 4, 'passphrase')
        expected =<<END
Stage: Comment
Phrase: passphrase
Dictionary attack:  2.0 bits (longevity: 4.0 seconds)
Brute force attack: 4.0 bits (longevity: 16.0 seconds)
END
        
        actual = logger.full(pass_phrase, comment)
        
        assert_equal expected, actual        
    end
end

class IntegrationTests < Test::Unit::TestCase
    def test_default_behaviour
        expected = /^([a-zA-Z]+ ){4}$/

        actual = `./xkcdpass.rb -f wordlists/american-10.txt -v silent`.strip + ' '

        assert_match expected, actual
    end
    def test_word_count_short_option
        expected = /^([a-zA-Z]+ ){6}$/

        actual = `./xkcdpass.rb -f wordlists/american-10.txt -w 6 -v silent`.strip + ' '

        assert_match expected, actual
    end
    def test_word_count_long_option
        expected = /^([a-zA-Z]+ ){6}$/

        actual = `./xkcdpass.rb -f wordlists/american-10.txt --word_count 6 -v silent`.strip + ' '

        assert_match expected, actual
    end
    def test_word_count_long_option_truncated
        expected = /^([a-zA-Z]+ ){6}$/

        actual = `./xkcdpass.rb -f wordlists/american-10.txt --word 6 -v silent`.strip + ' '

        assert_match expected, actual
    end
    def test_separator_string_short_option
        expected = /^([a-zA-Z]+X){4}$/

        actual = `./xkcdpass.rb -f wordlists/american-10.txt -s X -v silent`.strip + 'X'

        assert_match expected, actual
    end
    def test_separator_string_long_option
        expected = /^([a-zA-Z]+yy){4}$/

        actual = `./xkcdpass.rb -f wordlists/american-10.txt --separator yy -v silent`.strip + 'yy'

        assert_match expected, actual
    end
    def test_case_upper_short_option
        expected = /^([A-Z]+ ){4}$/

        actual = `./xkcdpass.rb -f wordlists/american-10.txt -c upper -v silent`.strip + ' '

        assert_match expected, actual
    end
    def test_case_upper_long_option
        expected = /^([A-Z]+ ){4}$/

        actual = `./xkcdpass.rb -f wordlists/american-10.txt --case upper -v silent`.strip + ' '

        assert_match expected, actual
    end
    def test_case_lower
        expected = /^([a-z]+ ){4}$/

        actual = `./xkcdpass.rb -f wordlists/american-10.txt -c lower -v silent`.strip + ' '

        assert_match expected, actual
    end
    def test_case_capitalize
        expected = /^([A-Z][a-z]* ){4}$/

        actual = `./xkcdpass.rb -f wordlists/american-10.txt -c capitalize -v silent`.strip + ' '

        assert_match expected, actual
    end
    def test_case_alternate
        expected_lower_case_first = /([a-z]+ [A-Z]+ ){2}$/
        expected_upper_case_first = /([A-Z]+ [a-z]+ ){2}$/

        actual = `./xkcdpass.rb -f wordlists/american-10.txt -c alternate -v silent`.strip + ' '

        assert (actual =~ expected_upper_case_first) || (actual =~ expected_lower_case_first)
    end
    def test_case_random
        expected = /^([A-Za-z]+ ){4}$/

        actual = `./xkcdpass.rb -f wordlists/american-10.txt -c random -v silent`.strip + ' '

        assert_match expected, actual
    end
    def test_numbers_between
        expected = /^(([A-Za-z]+ )|([0-9]+ ))+$/

        actual = `./xkcdpass.rb -f wordlists/american-10.txt -n between -d 2 -v silent`.strip + ' '

        assert_match expected, actual
    end
    def test_numbers_inside
        expected = /^([A-Za-z0-9]+ ){4}$/

        actual = `./xkcdpass.rb -f wordlists/american-10.txt -n inside -d 2 -v silent`.strip + ' '

        assert_match expected, actual
    end
end
