---
title: Making a Custom Kontakt Instrument
date: 2015-08-25T17:00:00+00:00
categories:
  - Music
---
<p>Inspired by <a href="https://www.youtube.com/watch?v=MFHIBo3d4Rw">Junkie XL’s intriguing video series</a> on his studio and film work (especially on <em>Mad Max: Fury Road</em>), I decided to make some custom instruments using <a href="http://www.native-instruments.com/en/products/komplete/samplers/kontakt-5/">Native Instruments’ excellent industry-standard sampler Kontakt</a> (don’t buy it at full price; it and Komplete go on sale at least once a year) and some drums I had access to; so far, one small bass drum at the nearby university, and one small bass drum at home that I got for free a few years back.</p>
<!--more-->
<p>I’ve used these instruments in a few projects now, and I’m actually quite satisfied with how they turned out given the somewhat-impromptu recording setup and my meager experience with Kontakt. I thought I’d give a brief run-down of my process, and hopefully inspire someone else out there to add some unique, personalized sounds to their own music rather than only using presets and commercial libraries.</p>

<h2 id="recording">Recording</h2>

<p>This was definitely the most amateur-y part of it all. I think I ended up using the source from my Zoom H1, which is not exactly the greatest field recorder out there. Somehow, though, it got a nicer sound than the other mics I tested out. It was also recorded in my apartment bedroom, which does not have a fantastic sound. Still, I’ve been recording in there for about 5 years now and I’ve gotten very accustomed to getting a decent sound out of the less-than-ideal space.</p>

<p>The recording itself was a bit tedious. I set up the mics, grabbed a drum stick, and hit the drum as softly as I could. I waited a few seconds to let the sound decay. I hit it again at a similar volume. I waited. I repeated this over and over, gradually getting louder. Not all the hits were great. It ended after I hit the drum as hard as I could a few times. Then I took another couple of passes at volumes where I didn’t feel like I had enough hits.</p>

<p>In the end, I had one long, boring audio file with a bunch of drum hits.</p>

<h2 id="editing">Editing</h2>

<p><img src="http://jonbash.github.io/blog/assets/images/Reaper-instrument-sample-edit.png" alt="Editing the file in Reaper" /></p>

<p>First, I listened through the long, boring audio file in <a href="http://www.reaper.fm">Reaper (my DAW of choice)</a> and got rid of any hits where I flammed or hit the drum in a weird spot or that otherwise didn’t fit in.</p>

<p>At this point, I normalized the file using <code class="highlighter-rouge">Item properties: Normalize multiple items to common gain</code> (shortcut: Shift-N) (since I had cut out sections of the original file) and then used the action <code class="highlighter-rouge">Item: Dynamic split items...</code> (shortcut: D) to split the items at their transients. I had to do quite a bit of tweaking and adjusting, but it was still faster than splitting everything manually.</p>

<p>Then, I made use of an action in the excellent <a href="http://sws.mj-s.com/">SWS extensions for Reaper</a> referred to under the action list <code class="highlighter-rouge">SWS: Organize items by RMS (entire item) / peak / peak RMS</code> (I can’t remember which of the 3 variations I used, but they all get pretty similar results; it might be worth trying out each of them). This made it so that the individual hits were ordered by volume from soft to loud. I could then listen through again and get rid of a couple of hits in any dynamic range where there were too many hits.</p>

<p>I then applied a bit of processing to the samples on the track; just some subtle compression and EQing to make it sound a bit cleaner. I used the action <code class="highlighter-rouge">Markers: Insert regions for each selection item</code> to create a separate region for each sample, and then rendered out each sample into a separate file named numerically by volume.</p>

<h2 id="making-kontakt-ha">Making Kontakt (Ha)</h2>

<p><img src="http://jonbash.github.io/blog/assets/images/Kontakt-instrument-edit.png" alt="Making the instrument in Kontakt" /></p>

<p>At this point I moved into Kontakt and made a new instrument (<code class="highlighter-rouge">Files-&gt;New Instrument</code>) and dragged the samples into the Mapping Editor. Contrary to how most samples are laid out (but in exactly the same way Junkie XL does it), I arranged the samples by volume across the keyboard. Most sampler instruments put one drum on one key and control volume with velocity, and often have some randomization involved to make it sound more human. But here, instead of the samples increasing in pitch as you move up the keyboard, they increase in volume. This way, I think, gives you a bit more control over the sound once you start using the instrument in a piece of music. I did decide, additionally, to keep velocity control of each sample, partly because it does that by default, but also just to have that extra level of control.</p>

<p>I adjusted the envelope of the drums, giving them a pretty long, natural sounding decay and release, and added a bit of Kontakt’s built-in reverb just to make it sound like it wasn’t recorded in an apartment bedroom. I tested the instrument out, playing each key up and down the keyboard to make sure it still sounded natural and was actually in order of loudness. I had to rearrange a couple of samples, but generally it worked really well.</p>

<p>I saved the new instrument to a folder near my other custom instruments I’ve accumulated (mostly some freebies I’ve found online) and that I’ve put it in Kontakt’s QuickLoad section so I have quick access to them (I really wish I could stick it with the commercial libraries… <strong><em>hint hint nudge nudge</em></strong>, Native Instruments…).</p>

<h2 id="now-i-have-a-machine-drum-ho-ho-ho">Now I have a machine drum. Ho ho ho.</h2>

<p>Now I have a nice, unique, personalized drum that I can use in my music projects. No one else has this instrument, and even though, yes, it’s a drum, and most people don’t notice when commercial drum libraries get re-used… you won’t hear this exact sound anywhere else. It’s subtle, but I think it helps my music stand out just a tad bit more.</p>

<p>You may also ask, why not just record the drum when you need it? For me, that means pulling out my drum, making sure there’s no noise outside my apartment or from neighbors, closing the doors, setting up the mics, and doing several takes of recording the part. Then, if I decide later I don’t like the part, I have to redo all that. This way, I just pull up Kontakt and play some stuff on my keyboard or program the MIDI part and add some humanization if it’s not particularly conducive to keyboard playing. Much quicker, which is vital for projects that are on tight deadlines.</p>

<p>So hopefully you got a little something out of that! As a special treat, I decided to record a little walkthrough/kinda-tutorial about the making of this instrument. Check it out if you’re interested and want a closer look!</p>

<iframe width="100%" height="480" src="https://www.youtube.com/embed/-c6fZ_vaur4" frameborder="0" allowfullscreen=""></iframe>
