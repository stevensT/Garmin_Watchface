import Toybox.Graphics;
import Toybox.Lang;

//! Colour palette for the watch face.
//!
//! Phase 1 hardcodes the values. Phase 2 feeds `accent` and `data` from the
//! on-device editor (WATCH_FACE_CONFIG_TYPE_ACCENT_COLOR / _COMPLICATION_COLOR)
//! and `background` from phone settings.
class Theme {

    //! Colour of the main time readout
    public var accent as Number = ACCENT_DEFAULT;
    //! Colour of data slot values
    public var data as Number = DATA_DEFAULT;
    //! Screen background
    public var background as Number = BACKGROUND_DEFAULT;
    //! Muted colour for labels and the branding mark
    public var muted as Number = MUTED_DEFAULT;

    public static const ACCENT_DEFAULT = 0xFF4030;
    public static const DATA_DEFAULT = Graphics.COLOR_WHITE;
    public static const BACKGROUND_DEFAULT = Graphics.COLOR_BLACK;
    public static const MUTED_DEFAULT = 0x808080;

    function initialize() {
    }

    //! Dimmed counterpart of a colour, for the always-on render.
    //! Halves each 8-bit channel, which keeps hue while cutting emitted light.
    //! @param color The colour to dim
    //! @return The dimmed colour
    static function dim(color as Number) as Number {
        var r = (color >> 16) & 0xFF;
        var g = (color >> 8) & 0xFF;
        var b = color & 0xFF;
        return (((r / 2) << 16) | ((g / 2) << 8) | (b / 2));
    }
}
