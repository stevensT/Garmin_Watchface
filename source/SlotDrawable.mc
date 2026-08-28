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
    //! @param label The complication's short label, or "" for none
    //! @param value The complication's value, already formatted
    function setContent(label as String, value as String) as Void {
        _label = label;
        _value = value;
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

        dc.setColor(_valueColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, locY + labelHeight, Graphics.FONT_TINY, _value,
            Graphics.TEXT_JUSTIFY_CENTER);
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
