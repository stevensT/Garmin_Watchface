import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

//! The second-time readout — UTC/ZULU by default.
//!
//! Not one of the six data slots: there is no second-timezone complication, so the
//! on-device editor cannot offer this at all. It is drawn by the face itself, in a
//! place of its own, and configured from phone settings instead.
//!
//! Always 24-hour. A zone offset written as a four-digit group is only readable one
//! way, and the 12/24h setting is about the main readout.
module SecondTime {

    //! Seconds to add to UTC. Zero is ZULU, which is the point of the face.
    //! Phase 4 reads this from phone settings.
    const DEFAULT_OFFSET = 0;

    //! Trails the digits to name the zone. One or two characters: anything longer
    //! competes with the time itself.
    const DEFAULT_LABEL = "Z";

    //! The readout text: four digits and the zone label, as in `0349Z`.
    //! @param offsetSeconds Seconds to add to UTC
    //! @param label The zone label to trail the digits with
    //! @return The text to draw
    function text(offsetSeconds as Number, label as String) as String {
        var moment = Time.now();
        if (offsetSeconds != 0) {
            moment = moment.add(new Time.Duration(offsetSeconds));
        }

        var info = Gregorian.utcInfo(moment, Time.FORMAT_SHORT);
        return Lang.format("$1$$2$$3$",
            [info.hour.format("%02d"), info.min.format("%02d"), label]);
    }

    //! Draw the readout centred at its fixed place for the current style
    //! @param dc The drawing context
    //! @param width Screen width
    //! @param height Screen height
    //! @param style The layout style, which sets the vertical position
    //! @param color Colour to draw in
    //! @param offsetSeconds Seconds to add to UTC
    //! @param label The zone label
    function draw(dc as Dc, width as Number, height as Number, style as Styles.Id,
                  color as Graphics.ColorType, offsetSeconds as Number,
                  label as String) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, (height * Layout.zuluY(style)).toNumber(),
            Layout.SECOND_TIME_FONT, text(offsetSeconds, label),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
