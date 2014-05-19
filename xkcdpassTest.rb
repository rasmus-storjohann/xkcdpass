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

class NullCaseModifier
    def modify_case(word)
        word
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
    def test_modify_letters_and_case
        substitutes = {'a'=>'@', 's'=>'$'}
        modifier = NullCaseModifier.new
        words = ['ThaS', 'ThAt']
        expected = ['Th@$', 'Th@t']

        actual = modify_letters_and_case(words, substitutes, modifier)

        assert_equal expected, actual
    end
    def test_modify_letters
        expected = 'Th%s %s'

        actual = modify_letters('This Is', {'i'=>'%'})

        assert_equal expected, actual
    end
    def test_modify_one_letter_replaces_matching_letters
        expected = '%'

        actual = modify_one_letter('i', {'i'=>'%'})

        assert_equal expected, actual
    end
    def test_modify_one_letter_returns_nonmatching_letters_unchanged
        expected = 't'

        actual = modify_one_letter('t', {'i'=>'%'})

        assert_equal expected, actual
    end
end

