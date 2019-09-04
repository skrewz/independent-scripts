# Wait, what?

This script takes a photo^W1-second **webcam video at random intervals**.

Yep, you read that right. And to top that off, it also takes a screendump, and lists which processes the system was running.

# But why?

I realised that I have a good backup system at some point. And this being around the time when even three-letter-agency directors recommended putting tape over their webcams, I thought I would rather do something different. If the thought is that somebody could be looking at any time, **why not make that somebody me?**

Many weird pictures have been made over the years. For somebody whose life is largely on the computer, many life memories have been made this way.

# Usage

This is a script that can be installed in a crontab thusly:

```
    * * * * *  path/to/independent-scripts/automatic_webcam_pic/take_video_and_announce.sh  --probability-of-shot 10 --random-delay-up-to 59 --capture-screenshot
```

This would take a snap at expected-case ten minute intervals.

You may also integrate it into your window manager so that you can trigger a shot. **Think personal high-five moments**. To qualitatively distinguish manually-made shots from the automatic ones, the `--manual` switch puts a nice `find`-able infix on the filenames that come from this.

(I'll add that I've had to configure it with `env DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus` in order to get the X output to work; your mileage may vary.)
