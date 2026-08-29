import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

//! The always-on render: what the face shows while the watch is idle.
//!
//! This is a different drawing, not a dimmed copy of the normal one. An AMOLED
//! always-on face has to keep roughly a tenth of its pixels lit, and the full face
//! measures 14 % on the 454 with Minimal at 11.7 %, so dimming the palette alone
//! cannot get there — elements have to go.
//!
//! What stays is the time and the second time: the two readouts the face exists
//! for. The slots, the arc, the status icons, the rules and the mark are all
//! high-power. A slot's value would be stale within the minute anyway, since
//! complications stop pushing while the watch sleeps.
module LowPowerRenderer {

    //! How far the render may wander from centre, as a fraction of screen width.
    //!
    //! Burn-in protection is not decoration: an OLED that draws the same colon in
    //! the same pixels for a year keeps it there. The whole group shifts together
    //! so the layout stays coherent, and the shift has to be large enough that a
    //! glyph does not sit on its own previous position — a couple of pixels would
    //! just blur the ghost rather than avoid it.
    const SHIFT = 0.026;

    //! Draw the idle face.
    //! @param dc The drawing context
    //! @param width Screen width
    //! @param height Screen height
    //! @param theme The palette, dimmed here rather than by the caller
    //! @param timeFont The numerals' face
    //! @param style The layout style, which sets where the second time sits
    //! @param clockTime The current time
    function draw(dc as Dc, width as Number, height as Number, theme as Theme,
                  timeFont as Graphics.FontType, style as Styles.Id,
                  clockTime as System.ClockTime) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Config.backgroundColor());
        dc.clear();

        // The user's own switch, separate from the system's. Off means they asked
        // for a dark wrist, so the face draws nothing but its background — the
        // cheapest thing an OLED can show.
        if (!Config.alwaysOn()) {
            return;
        }

        var offset = burnInOffset(width, clockTime);
        var dx = offset[0];
        var dy = offset[1];

        drawTime(dc, width, height, theme, timeFont, clockTime, dx, dy);

        // The data colour dimmed, not the muted colour dimmed. The normal render
        // draws this line in the data colour, and muted is already a mid grey, so
        // halving it again lands at 25 % — legible in a screenshot and not on a
        // wrist in daylight.
        dc.setColor(Theme.dim(theme.data), Graphics.COLOR_TRANSPARENT);
        dc.drawText((width / 2) + dx,
            (height * Layout.zuluY(style)).toNumber() + dy,
            Layout.SECOND_TIME_FONT,
            SecondTime.text(Config.secondTimeOffset(), Config.secondTimeLabel()),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! The numerals, dimmed.
    function drawTime(dc as Dc, width as Number, height as Number,
                              theme as Theme, timeFont as Graphics.FontType,
                              clockTime as System.ClockTime,
                              dx as Number, dy as Number) as Void {
        var hours = clockTime.hour;
        var text;

        if (System.getDeviceSettings().is24Hour) {
            text = Lang.format("$1$:$2$",
                [hours.format("%02d"), clockTime.min.format("%02d")]);
        } else {
            hours = hours % 12;
            if (hours == 0) { hours = 12; }
            text = Lang.format("$1$:$2$",
                [hours.format("%d"), clockTime.min.format("%02d")]);
        }

        // No AM/PM here. It is a muted label beside the numerals in the normal
        // render, and in a readout this size the hour is not ambiguous to someone
        // glancing at their own wrist.
        dc.setColor(Theme.dim(theme.accent), Graphics.COLOR_TRANSPARENT);
        dc.drawText((width / 2) + dx,
            (height * Layout.TIME_Y).toNumber() + dy,
            timeFont, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Where to shift the render this minute, so no pixel is lit indefinitely.
    //!
    //! Two moduli that share no factor, so the pattern takes 35 minutes to repeat
    //! rather than cycling through the same handful of positions every few. The
    //! face only redraws once a minute in this mode, so the position is a function
    //! of the minute rather than of a counter that would reset on every wake.
    //!
    //! Returns [0, 0] on a device that does not ask for burn-in protection, since
    //! a wandering readout is a cost with no benefit there.
    //! @param width Screen width
    //! @param clockTime The current time
    //! @return [dx, dy] in pixels
    function burnInOffset(width as Number,
                          clockTime as System.ClockTime) as Array<Number> {
        if (!System.getDeviceSettings().requiresBurnInProtection) {
            return [0, 0];
        }

        var reach = (width * SHIFT).toNumber();
        var minute = clockTime.min;

        return [
            (((minute % 7) - 3) * reach) / 3,
            (((minute % 5) - 2) * reach) / 2
        ];
    }
}
