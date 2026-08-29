import Toybox.Graphics;
import Toybox.Lang;

//! Colours the on-device editor owns.
//!
//! `accent` and `data` come from the editor
//! (WATCH_FACE_CONFIG_TYPE_ACCENT_COLOR / _COMPLICATION_COLOR) and `muted` is
//! derived. The background is not here: it belongs to the other configuration
//! surface, and lives in `Config`.
class Theme {

    //! Colour of the main time readout
    public var accent as Number = ACCENT_DEFAULT;
    //! Colour of data slot values
    public var data as Number = DATA_DEFAULT;
    //! Muted colour for slot labels, the branding mark, and the small labels
    //! beside the time
    public var muted as Number = MUTED_DEFAULT;

    //! Matches the accent list's default entry in the config resource, so a device
    //! with no on-device editor wears the same colour as one with it.
    public static const ACCENT_DEFAULT = 0x00E676;
    public static const DATA_DEFAULT = Graphics.COLOR_WHITE;
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
