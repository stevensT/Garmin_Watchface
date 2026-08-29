import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;

//! Phone-owned settings, read once and held.
//!
//! The other configuration surface is the on-device editor, which owns style,
//! accent colour, the six slots and the data colour. Everything its fixed schema
//! cannot express is here instead.
//!
//! Values are cached rather than read per draw: `onUpdate` runs every second in
//! high-power mode, and `Properties.getValue` is not free. `reload()` is called at
//! layout and again whenever the Connect app pushes a change.
//!
//! 12/24-hour and units are absent on purpose. Those come from the watch's own
//! settings, so the face never disagrees with the rest of the device.
module Config {

    const BACKGROUND_DEFAULT = Graphics.COLOR_BLACK;
    const SHOW_SECONDS_DEFAULT = false;
    const ARC_METRIC_DEFAULT = BottomArc.BATTERY;
    const SLOT_ICONS_DEFAULT = true;
    const STATUS_ICONS_DEFAULT = true;
    const ALWAYS_ON_DEFAULT = true;
    const SECOND_TIME_OFFSET_DEFAULT = 0;
    const SECOND_TIME_LABEL_DEFAULT = "Z";
    const SHOW_MARK_DEFAULT = true;
    const MARK_TEXT_DEFAULT = "RESCUE";

    //! Wordings the mark can take. Values match the phone setting's list entries.
    enum MarkPreset {
        MARK_RESCUE = 0,
        MARK_MOUNT_UP = 1,
        MARK_CUSTOM = 2
    }

    //! Widest offset either way: UTC-12:00 to UTC+14:00, in minutes
    const OFFSET_MIN = -720;
    const OFFSET_MAX = 840;

    var _background as Number = BACKGROUND_DEFAULT;
    var _showSeconds as Boolean = SHOW_SECONDS_DEFAULT;
    var _arcMetric as Number = ARC_METRIC_DEFAULT;
    var _slotIcons as Boolean = SLOT_ICONS_DEFAULT;
    var _statusIcons as Boolean = STATUS_ICONS_DEFAULT;
    var _alwaysOn as Boolean = ALWAYS_ON_DEFAULT;
    var _secondTimeOffset as Number = SECOND_TIME_OFFSET_DEFAULT;
    var _secondTimeLabel as String = SECOND_TIME_LABEL_DEFAULT;
    var _showMark as Boolean = SHOW_MARK_DEFAULT;
    var _markText as String = MARK_TEXT_DEFAULT;

    //! Re-read every setting. Called from onLayout and onSettingsChanged.
    function reload() as Void {
        _background = numberFor("backgroundColor", BACKGROUND_DEFAULT);
        _showSeconds = booleanFor("showSeconds", SHOW_SECONDS_DEFAULT);

        _slotIcons = booleanFor("slotIcons", SLOT_ICONS_DEFAULT);
        _statusIcons = booleanFor("statusIcons", STATUS_ICONS_DEFAULT);

        var arc = numberFor("arcMetric", ARC_METRIC_DEFAULT);
        _arcMetric = ((arc == BottomArc.OFF) || (arc == BottomArc.BATTERY)
            || (arc == BottomArc.STEPS)) ? arc : ARC_METRIC_DEFAULT;
        _alwaysOn = booleanFor("alwaysOn", ALWAYS_ON_DEFAULT);
        _secondTimeLabel = stringFor("secondTimeLabel", SECOND_TIME_LABEL_DEFAULT);
        _showMark = booleanFor("showMark", SHOW_MARK_DEFAULT);
        _markText = markFor(numberFor("markPreset", MARK_RESCUE));

        // The phone app enforces the range, but a value can also arrive from an
        // older install or a hand-edited property, and a wild offset would put the
        // second time in the wrong day rather than merely the wrong hour.
        var offset = numberFor("secondTimeOffset", SECOND_TIME_OFFSET_DEFAULT);
        if ((offset < OFFSET_MIN) || (offset > OFFSET_MAX)) {
            offset = SECOND_TIME_OFFSET_DEFAULT;
        }
        _secondTimeOffset = offset;
    }

    //! Screen background colour
    //! @return The colour to clear to
    function backgroundColor() as Number {
        return _background;
    }

    //! Whether to draw seconds beside the main readout
    //! @return true if seconds are wanted
    function showSeconds() as Boolean {
        return _showSeconds;
    }

    //! Whether the connection status column is drawn
    //! @return true if status icons are wanted
    function statusIcons() as Boolean {
        return _statusIcons;
    }

    //! Whether slots show an icon in place of their name
    //! @return true if icons are wanted
    function slotIcons() as Boolean {
        return _slotIcons;
    }

    //! What the bottom rim gauge tracks
    //! @return A BottomArc metric
    function arcMetric() as Number {
        return _arcMetric;
    }

    //! Whether the face draws a dimmed always-on render at all
    //! @return true if always-on is wanted
    function alwaysOn() as Boolean {
        return _alwaysOn;
    }

    //! Offset of the second-time readout from UTC
    //! @return The offset in seconds, ready for a Time.Duration
    function secondTimeOffset() as Number {
        return _secondTimeOffset * 60;
    }

    //! Label trailing the second-time digits
    //! @return The zone label
    function secondTimeLabel() as String {
        return _secondTimeLabel;
    }

    //! Whether to draw the branding mark
    //! @return true if the mark is wanted
    function showMark() as Boolean {
        return _showMark;
    }

    //! Text of the branding mark
    //! @return The mark text
    function markText() as String {
        return _markText;
    }

    //! The mark's wording for a preset.
    //!
    //! The built-in wordings come from string resources rather than literals so
    //! they stay in one place: the phone app's picker lists the same resources.
    //! The custom field is left alone unless it is the one selected, so switching
    //! to a preset and back does not lose what the user typed.
    //! @param preset The selected preset
    //! @return The text to draw
    function markFor(preset as Number) as String {
        if (preset == MARK_MOUNT_UP) {
            return Application.loadResource(Rez.Strings.MarkMountUp) as String;
        }

        if (preset == MARK_CUSTOM) {
            return stringFor("markText", MARK_TEXT_DEFAULT);
        }

        return Application.loadResource(Rez.Strings.MarkRescue) as String;
    }

    //! Read a numeric property.
    //!
    //! A property can be missing on a device that installed an older version, and
    //! the phone can push a null when the user clears a field, so the stored value
    //! is only trusted once its type is confirmed.
    //! @param key The property key
    //! @param fallback The value to use when the property is missing or wrong
    //! @return The property value
    function numberFor(key as String, fallback as Number) as Number {
        var value = valueFor(key);
        return (value instanceof Lang.Number) ? value : fallback;
    }

    //! Read a boolean property
    //! @param key The property key
    //! @param fallback The value to use when the property is missing or wrong
    //! @return The property value
    function booleanFor(key as String, fallback as Boolean) as Boolean {
        var value = valueFor(key);
        return (value instanceof Lang.Boolean) ? value : fallback;
    }

    //! Read a string property. An empty string counts as unset: the phone app lets
    //! the user clear a text field, and a blank mark should fall back rather than
    //! draw nothing.
    //! @param key The property key
    //! @param fallback The value to use when the property is missing or empty
    //! @return The property value
    function stringFor(key as String, fallback as String) as String {
        var value = valueFor(key);
        if (!(value instanceof Lang.String) || (value as String).length() == 0) {
            return fallback;
        }
        return value;
    }

    //! Read one raw property value
    //! @param key The property key
    //! @return The stored value, or null if there is none
    function valueFor(key as String) as Object? {
        try {
            return Application.Properties.getValue(key);
        } catch (ex) {
            // No such property on this install.
            return null;
        }
    }
}
