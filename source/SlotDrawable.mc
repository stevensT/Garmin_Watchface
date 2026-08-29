import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! One data slot: a muted label with its value underneath.
//!
//! This is a `Drawable` rather than plain drawing code because the on-device
//! editor asks for a `ComplicationDrawableRef` when the user selects a slot, and
//! that needs both a drawable the system can render and a bounding box to pulse
//! around. `locX`/`locY` are the top left corner, which is what the editor expects.
class SlotDrawable extends WatchUi.Drawable {

    //! Shown when a complication has no value, or does not exist on this device
    static const EMPTY = "--";

    private var _label as String = "";
    private var _value as String = EMPTY;
    private var _valueColor as Graphics.ColorType = Graphics.COLOR_WHITE;
    private var _labelColor as Graphics.ColorType = Graphics.COLOR_LT_GRAY;

    //! Constructor
    //! @param options Standard drawable options; locX/locY are the top left corner
    function initialize(options as {
                :identifier as Object,
                :locX as Numeric,
                :locY as Numeric,
                :width as Numeric,
                :height as Numeric
            }) {
        Drawable.initialize(options);
    }

    //! Set the label and value to draw
    //!
    //! Reports whether anything actually moved. A complication can push a value
    //! identical to the one already shown — battery does it constantly — and there
    //! is no reason to repaint the face for that.
    //! @param label The complication's short label, or "" for none
    //! @param value The complication's value, already formatted
    //! @return true if the drawn text changed
    function setContent(label as String, value as String) as Boolean {
        var shown = duplicates(label, value) ? "" : label;

        if (_label.equals(shown) && _value.equals(value)) {
            return false;
        }

        _label = shown;
        _value = value;
        return true;
    }

    //! Whether a label only repeats what the value already says.
    //!
    //! Garmin labels the date complication "AUG" over a value of "Aug 28", and the
    //! weekday one "FRI" over "Fri 28". Drawing both spends a line of the slot on
    //! nothing. The test is a prefix rather than a substring so that a label like
    //! "HR" survives a value of "8HR".
    //! @param label The complication's label
    //! @param value The formatted value
    //! @return true if the label adds nothing
    private function duplicates(label as String, value as String) as Boolean {
        if (label.length() == 0) {
            return false;
        }

        return value.toUpper().find(label.toUpper()) == 0;
    }

    //! Set the drawing colours
    //! @param value Colour of the value, from the editor's data colour
    //! @param label Colour of the label
    function setColors(value as Graphics.ColorType, label as Graphics.ColorType) as Void {
        _valueColor = value;
        _labelColor = label;
    }

    //! Draw the slot
    //! @param dc The drawing context
    function draw(dc as Dc) as Void {
        if (!isVisible) {
            return;
        }

        var centerX = locX + (width / 2);
        var labelHeight = dc.getFontHeight(Graphics.FONT_XTINY);

        dc.setColor(_labelColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, locY, Graphics.FONT_XTINY, _label,
            Graphics.TEXT_JUSTIFY_CENTER);

        var fitted = fit(dc);

        dc.setColor(_valueColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, locY + labelHeight, fitted[1] as Graphics.FontType,
            fitted[0] as String, Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! What to draw for the value, and in what font, so it stays inside the slot.
    //!
    //! Values are not all short. Altitude in feet runs to five digits and a unit,
    //! and "13313ft" is about 180 px at FONT_TINY against a slot barely 100 px
    //! wide. The text is centred, so the overflow runs off both sides, and near
    //! the rim the round screen cuts the end off the number — a clipped "3465ft"
    //! reads as "3465f", which is a wrong number rather than an ugly one.
    //!
    //! Three things are tried in order, each giving up less than the next: a
    //! smaller font, then the unit, then characters. Dropping "ft" from an
    //! altitude costs nothing a reader misses, since the label already says ALT;
    //! dropping a digit changes what the number means, so it comes last.
    //! @param dc The drawing context
    //! @return [text, font]
    private function fit(dc as Dc) as Array {
        if (dc.getTextWidthInPixels(_value, Graphics.FONT_TINY) <= width) {
            return [_value, Graphics.FONT_TINY];
        }

        if (dc.getTextWidthInPixels(_value, Graphics.FONT_XTINY) <= width) {
            return [_value, Graphics.FONT_XTINY];
        }

        var bare = withoutUnit(_value);
        if (dc.getTextWidthInPixels(bare, Graphics.FONT_XTINY) <= width) {
            return [bare, Graphics.FONT_XTINY];
        }

        // Nothing else left to give up.
        while ((bare.length() > 1)
                && (dc.getTextWidthInPixels(bare, Graphics.FONT_XTINY) > width)) {
            bare = bare.substring(0, bare.length() - 1) as String;
        }

        return [bare, Graphics.FONT_XTINY];
    }

    //! A value with its trailing unit letters removed: "13313ft" becomes "13313".
    //! Only letters go — "50%" and "61°" keep their marks, which are doing more
    //! work than a unit name and cost two characters between them.
    //! @param text The value
    //! @return The value without its unit
    private function withoutUnit(text as String) as String {
        var end = text.length();

        while (end > 0) {
            var ch = text.substring(end - 1, end) as String;
            if (!ch.equals(ch.toUpper()) || !ch.equals(ch.toLower())) {
                // The case forms differ, so this is a letter.
                end -= 1;
            } else {
                break;
            }
        }

        return (end > 0) ? text.substring(0, end) as String : text;
    }

    //! The box the editor pulses around this slot
    //! @return The bounding box
    function getBoundingBox() as Graphics.BoundingBox {
        var box = new Graphics.BoundingBox();
        box.addRectangle(locX.toNumber(), locY.toNumber(), width.toNumber(), height.toNumber());
        return box;
    }

    //! Whether a tap landed on this slot
    //! @param x Tap x coordinate
    //! @param y Tap y coordinate
    //! @return true if the point is inside the slot
    function containsPoint(x as Number, y as Number) as Boolean {
        return getBoundingBox().includesPoint(x, y);
    }
}
