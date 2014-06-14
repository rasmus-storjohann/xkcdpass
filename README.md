# xkcdpass

xkcdpass is yet another tool for generating passphrases by the [xkcd-936](http://xkcd.com/936/) 
method. It pulls random words from a word list to generate a passphrase which is then modified 
to make strong passphrases that are hard to guess and possible to remember. And yes, Bruce Schneier
[doesn't like](https://www.schneier.com/blog/archives/2014/03/choosing_secure_1.html) xkcd-936, 
well, it turns out even Bruce Schneier can be wrong.

## TLDR

xkcdpass generates passphrases by picking several words randomly from a word list, modifies 
them using a standard bag of tricks such as change case, introduce digits, substitute symbols 
for letters, etc. It then estimates the strength of the passphrases in terms of how long they 
would stand up against simple brute force attack or a modern dictionary based attack. This 
estimate is done after each type of modification, making clear how much stronger the passphrase 
actually becomes at each stage.

## Dos and don'ts

* DON'T memorize most of your your passphrases.
* DO use a [password manager](http://lifehacker.com/5944969/which-password-manager-is-the-most-secure) 
  to generate and store passphrases. [Keepass](http://sourceforge.net/projects/keepassx/) and 
  [LastPass](https://lastpass.com/) are good alternatives for offline and online storage, respectively.
* DO use different passphrases for each of your accounts.
* DO use long random passphrases such as ```$3Fzli2Bl")'AjZYm0,,Pz%``` all acconts that you 
  don't need to memorize.
* DO use strong passphrases for the few accounts that you do need to memorize, probably your main email
  account, your password manager and not much else.

## Introduction

Many methods have been proposed over the years to generate strong passwords. The shift 
from passwords to passphrases has been encouraged in part by [xkcd](http://xkcd.com/936/). 
There is some controversy as to whether the xkcd-936 method is strong enough to
stand up to modern [hardware based dictionary attacks](http://blog.mailchimp.com/3-billion-passwords-per-second-are-complex-passwords-enough-anymore/). 
Bruce Schneier of significant renown in the computer security field 
[came out against](https://www.schneier.com/blog/archives/2014/03/choosing_secure_1.html) the 
xkcd method, and was [challenged](http://robinmessage.com/2014/03/why-bruce-schneier-is-wrong-about-passwords/).
The debate ensuded on [reddit](http://www.reddit.com/r/YouShouldKnow/comments/232uch) and I'm sure
in many other places.

## Passphrase strenght estimation

xkcdpass can be used to help settle that debate. It has been implemented with the goal of 
generating passphrases and estimate their strenght. In addition to computing the strength in 
bits, which can be hard for non-specialists to really understand, it also represents the 
strength of passphrases in terms of their longevity, i.e. how long it would take to break them, 
assuming a given number of attacks per second. The default rate of attacks is 1 billion passwords 
per second, which seems to be the ballpark figure for one off the shelf GPU hardware these days.

Two methods are currently used to estimate the passphrase strength. First, as the passphrase
is generated, the program keeps count of how many random numbers have been used, and the
range for each. So a random number in the range from 0 to 100 contributes log2(100) bits to the
entropy while a random number in the range from 0 to 5 contributes log2(5) bits. This is the 
entropy of the passphrase. Secondly, the finished passphrase is analysed for brute force or
["haystack" complexity](https://www.grc.com/haystack.htm).

Each of these two complexity measures imply a different attack model. The brute force complexity 
assumes a particular form of brute force attack, where every passphrase of length N is tried 
before any of length N+1. Furthermore, every passphrase containing lower case letters only is tried 
before any with lower+upper case letters, then lower+digits, then lower+symbols, then 
lower+upper+digits, etc. This approach assumes that the attacker knows almost nothing about 
how your passphrases are generated.

The entropy measure reflects the challenge faced by an attacker who knows everything about your 
passphrase generation method, including this program, the options that were passed to it, and the 
word list that was used. The only information not available to this hypothetical attacker is the 
values of random numbers used to generate the passphrase. A real attacker will fall somewhere 
between these extremes. Both measures are in the units of bits of information, and the entropy of a 
passphrase will always be less than its brute force complexity.

I believe neither of these attack models are very realistic, and I'd be interested to figure
out how to model likely attacks better in order to improve estimates of passphrase strengths.

## Passphrase generation

The passphrase generation starts by picking words at random from a word list. This gives a starting 
entropy of N*log2(M) bits, where N is the number of words in the passphrase and M is the number of 
words in the word list. The longer the word list, the more bits you get for each word. However, a 
very large word list will likely contain words that we don't know and therefore can't easily remember. 
Ideally we should use a word list that matches our vocabulary. The sample dictionary included here 
contains just over 1,400 words, giving about 10 bits of entropy per word, while /usr/share/dict/words 
on my linux system contains almost 73,000, giving about bits 16 per word.

The basic passphrase may then be modified in various ways, with the goal of packinng more entropy
into it, while not making it too hard to remember. The possible variations are endless, the following 
methods are currently supported by xkcdpass:

* Insert arbitrary (user suplied, not random) strings between each word.
* Change the case of each word, randomly or deterministically.
* Substitute symbols for characters, the usual 3 for e, @ for a, etc.
* Insert random numbers inside or between words.
* Repeat syllables randomly to intrduce stutter patters that some may find easy to remember.

# Examples

Here's an example of a short passphrase from a small word list, but with heavy modification:

```
$ ./xkcdpass.rb --stutter_count 2 --number_count 1 --numbers inside --substitution lots -substitution_count 3 --case random --verbose verbose --file sample_dict.txt --separator $ --word_count 3
Wordlist contains 1426 words, giving 10.5 bits per word
Assuming 1.0 billion attacks per second when estimating longevity

Stage: Pick words
Phrase: conditions require answer
Dictionary attack:  31.4 bits (longevity: 2.9 seconds)
Brute force attack: 117.5 bits (longevity: forever)

Stage: Add stutter
Phrase: cococonditions rererequire answer
Dictionary attack:  38.6 bits (longevity: 7.0 minutes)
Brute force attack: 155.1 bits (longevity: forever)

Stage: Change case
Phrase: cococonditions Rererequire ANSWER
Dictionary attack:  43.4 bits (longevity: 3.1 hours)
Brute force attack: 310.2 bits (longevity: forever)

Stage: Add digits
Phrase: cococondi21tions Rererequire ANSWER
Dictionary attack:  55.4 bits (longevity: 1.5 years)
Brute force attack: 445.3 bits (longevity: forever)

Stage: Add separator '$'
Phrase: cococondi21tions$Rererequire$ANSWER
Dictionary attack:  55.4 bits (longevity: 1.5 years)
Brute force attack: 617.0 bits (longevity: forever)

cococondi21tions$Rererequire$ANSWER
```

Here's an example of a longer passphrase from a larger word list:

```
$ ./xkcdpass.rb --number_count 1 --numbers between --substitution lots --substitution_count 2 --case random --verbose verbose --separator $ --word_count 4 --stutter_count 1 
Wordlist contains 72786 words, giving 16.2 bits per word
Assuming 1.0 billion attacks per second when estimating longevity

Stage: Pick words
Phrase: dieresis papooses niceties serpent
Dictionary attack:  64.6 bits (longevity: 890.0 years)
Brute force attack: 159.8 bits (longevity: forever)

Stage: Add stutter
Phrase: dieresis papooseses niceties serpent
Dictionary attack:  69.2 bits (longevity: 21.4 millenia)
Brute force attack: 169.2 bits (longevity: forever)

Stage: Change case
Phrase: Dieresis papooseses niceties SERPENT
Dictionary attack:  75.5 bits (longevity: forever)
Brute force attack: 338.4 bits (longevity: forever)

Stage: Change letters
Phrase: Dieresis papoo$e$e$ ni(etie$ SERPENT
Dictionary attack:  88.1 bits (longevity: forever)
Brute force attack: 515.1 bits (longevity: forever)

Stage: Add digits
Phrase: Dieresis 7 papoo$e$e$ ni(etie$ SERPENT
Dictionary attack:  96.8 bits (longevity: forever)
Brute force attack: 669.9 bits (longevity: forever)

Stage: Add separator '$'
Phrase: Dieresis$7$papoo$e$e$$ni(etie$$SERPENT
Dictionary attack:  96.8 bits (longevity: forever)
Brute force attack: 669.9 bits (longevity: forever)

Dieresis$7$papoo$e$e$$ni(etie$$SERPENT
```
