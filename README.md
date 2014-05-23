This is an pass phrase generator inspired by http://xkcd.com/936/. It pulls random words out of 
a word list. It lets you tweak the outputs in various ways, and also computes 
password strength.

The goal of this program is not only or primarily to generate strong passphrases through
its default behavior. I'm more interested in a tool that can generate pass phrases
through a range of related procedures, and estimate the strength of these passphrases
against various types of attachs.

The basis of the generator is the xkcd method of picking words at random from a word 
list. Based on a selection of words, various methods can be used to strengthen the
pass phrase, such as inserting digits between or within the words, replacing letters
with special characters, etc.

Two methods are used to estimate the strength of the password. First, as the pass phrase
is generated, I keep count of how many random numbers have been used. Secondly, the finished
pass phrase is analysed for complexity. Each of these two methods imply a different
attack model, the former that of a dictionary-based attack, the latter that of a brute
force cracking.

There are lots of suggestions out there for how to make stronger pass phrases. Each of
these tends to have a particular attack model in mind. This tool may be used to both
generate strong passphrases, and hopefully to also help the discussion of what makes
pass phrases strong against prevalent attack methods.
