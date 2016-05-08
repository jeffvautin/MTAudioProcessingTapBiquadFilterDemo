# MTAudioProcessingTapBiquadFilterDemo
Demo iOS app that uses the MTAudioProcessingTap (audioTapProcessor) property on AVPlayer to filter audio in the iPod Music Library. The demo filter is a lowpass filter, but it's instantiated as a generic biquad and implemented using the Accelerate framework.  

I cribbed liberally from [Chris' Coding Blog][1], [NVDSP][2], and the [*Learning Core Audio* Book][3].

[1]: https://chritto.wordpress.com/2013/01/07/processing-avplayers-audio-with-mtaudioprocessingtap/
[2]: https://github.com/bartolsthoorn/NVDSP
[3]: http://www.amazon.com/Learning-Core-Audio-Hands--Programming/dp/0321636848/ref=as_li_ss_tl?ie=UTF8&qid=1462667002&sr=8-1&keywords=learning+core+audio&linkCode=ll1&tag=todinshanew-20&linkId=21e8ca844fa84c5a2ce2bf878ae64d3a
