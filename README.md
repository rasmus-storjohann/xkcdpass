This is yet another tool for generating passphrases by the xkcd method. It pulls random words
from a word list to generate a passphrase which is then modified to make strong passphrases 
that are hard to guess and possible to remember.

First a piece of general advice: You should not memorize most of your passwords. Use a 
password manager to store long arbitrary passphrases (e.g. $3Fzli2Bl")'AjZYm0,,Pz%) for 
almost all your accounts, and memorize only the passphrase protecting your password manager, 
your email and perhaps one or two other things. Use different passwords for each account.
Keepass http://sourceforge.net/projects/keepassx/  and LastPass https://lastpass.com/ are 
good alternatives for offline and online storage, respectively. These tools also generate 
random passwords. However, some passwords you do need to remember, and that will not likely 
change any timem soon.

Many methods have been proposed over the years to generate strong passwords. The shift 
from passwords to passphrases has been encouraged in part by http://xkcd.com/936/. 
However, as password attacks become more powerful and specifically designed to work against 
dictionary based passphrases, the simple xkcd method has become insufficient, see e.g. 
https://www.schneier.com/blog/archives/2012/09/recent_developm_1.html and 
http://www.reddit.com/r/YouShouldKnow/comments/232uch. 

This tool uses the xkcd method as a starting point and adds several additional sources of 
randomness that should help the resulting passphrases stand up better against attacks. 

* Change the case of each word
* Insert a separator string between the words
* Insert random numbers between or within the words
* Add "stutter" by repeating syllables
* TODO Add spelling mistakes by repeating or omitting letters

The tool estimates the strength of these passphrases against different types of attacks, 
including how  much of the randomness in the resulting passphrases are due to each of these 
modifications. This should  help us to think rationally about what tricks are more effective 
than others at making passphrases that are both strong and memorable.

Two methods are currently used to estimate the passphrase strength. First, as the passphrase
is generated, the program keeps count of how many random numbers have been used, and the
range for each. So a random number in the range from 0 to 100 contributes log2(100) bits to the
entropy while a random number in the range from 0 to 5 contributes log2(5) bits. This is the 
entropy of the passphrase. Secondly, the finished passphrase is analysed for "haystack" complexity 
as outlined here https://www.grc.com/haystack.htm. 

Each of these two complexity measures imply a different attack model. The haystack complexity 
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
passphrase will always be less than its haystack complexity.

I believe neither of these attack models are very realistic, and I'd be interested to figure
out how to model likely attacks better in order to improve estimates of passphrase strengths.

The entropy of the passphrase is computed as follows:

* The word list file: The more words in the word list, the higher the complexity of
  the passphrase. Each word in the passphrase contributes log2(N) bits of complexity, where
  N is the number of words in the word list. Ideally you should use a word list that
  matches your vocabulary, since you want it to be as large as possible but not so 
  large that you need to memorize new words when memorizing your passphrase. The
  sample dictionary included here contains just over 1400 words, while /usr/share/dict/words 
  on my linux system contains almost 73,000.

* The length of the passphrase, i.e. the number of words, is the most important factor.
  The contribution for an N-word phrase is N*log2(M) where M is the number of words in the
  word list.

* Separator character is inserted between the words. As this is a deterministic process,
  it does not contribute to the entropy of the passphrase, but it is a nice way
  to introduce special characters in the passphrase, which increases the haystack complexity.
  You can also use a longer string here to increase the overall length of the password.

* The case won't affect complexity very much. Most of the case modes are deterministic so 
  they do nothing for the entropy but they do increase the haystack complexity
  insofar as they ensure that the passphrase contains both upper and lower case letters.
  The "random" mode randomly picks one of three possible capitalization modes for each 
  word, giving about 1.5 bit of entropy per word. It would be possible to randomly
  capitalize each letter, but I think that would be too hard to remember so I haven't
  implemented it.

* Inserting numbers in the passphrase has potential to increase the complexity, since any 
  number less than 100 will add log2(100) or about 6.5 bits just for the value, plus any 
  contribution from the random placement of the number. Numbers can be placed between words, 
  at the end of the word (which amounts to pretty much the same thing, obviously) and within 
  words. Placing the number between words contributes log2(N) where N is the number of words, 
  whereas placing the number withing words contributes log2(M) where M is the number of letters, 
  so its quite a bit more.
  
* Stutter modifications is the repetition of a randomly selected syllable in the passphrase.
  This adds entropy for the selection of the syllable and the number of repetitions.

* If you believe that a likely attack will involve trying shorter passphrase before longer
  ones, then even very simple ways to make your passphrase longer will make it stronger, such
  as padding at the beginning and/or end with a simple repeated character, such as *****. 
  This idea is outlined in more detail here https://www.grc.com/haystack.htm. However, much 
  like the separator character, padding does not contribute to the entropy of the passphrase.
