import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! The watch face itself.
//!
//! Everything is drawn in code rather than from a layout resource: the slot grid
//! (Phase 3) needs per-slot bounding boxes to hand the on-device editor, and
//! positions are derived from `dc` so one implementation covers 454x454 and 416x416.
class RescueFaceView extends WatchUi.WatchFace {

    //! Vertical centres, as a fraction of screen height
    private const _TIME_Y = 0.44;
    private const _ZULU_Y = 0.64;
    private const _MARK_Y = 0.82;

    //! Gap between the numerals and the AM/PM label, as a fraction of screen width
    private const _MERIDIEM_GAP = 0.015;
    //! How far up from the numerals' bottom edge the AM/PM label sits, as a
    //! fraction of the numeral box height. The FONT_NUMBER_* boxes carry a lot of
    //! descender padding, so sitting flush at the bottom reads as too low.
    private const _MERIDIEM_RISE = 0.22;

    private var _theme as Theme;
    //! True while the device is in low-power (always-on) mode
    private var _lowPower as Boolean = false;

    function initialize() {
        WatchFace.initialize();
        _theme = new Theme();
    }

    //! Load resources for the watch face
    //! @param dc The drawing context
    function onLayout(dc as Dc) as Void {
    }

    //! Draw the watch face
    //! @param dc The drawing context
    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(Graphics.COLOR_TRANSPARENT, _theme.background);
        dc.clear();

        drawTime(dc, width, height);
        drawSecondTime(dc, width, height);
        drawRescueMark(dc, width, height);
    }

    //! Draw the main HH:MM readout
    //! @param dc The drawing context
    //! @param width Screen width
    //! @param height Screen height
    private function drawTime(dc as Dc, width as Number, height as Number) as Void {
        var clockTime = System.getClockTime();
        var hours = clockTime.hour;
        var is24Hour = System.getDeviceSettings().is24Hour;
        var hourText;
        var meridiem = null;

        if (is24Hour) {
            // 24-hour reads as a fixed-width pair: 08:49, 20:49
            hourText = hours.format("%02d");
        } else {
            // 12-hour drops the leading zero and carries an AM/PM label: 8:49 PM
            meridiem = (hours >= 12) ? "PM" : "AM";
            hours = hours % 12;
            if (hours == 0) {
                hours = 12;
            }
            hourText = hours.format("%d");
        }

        var text = Lang.format("$1$:$2$", [hourText, clockTime.min.format("%02d")]);
        var centerY = (height * _TIME_Y).toNumber();

        dc.setColor(_theme.accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, centerY, Graphics.FONT_NUMBER_THAI_HOT, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (meridiem != null) {
            drawMeridiem(dc, width, centerY, text, meridiem);
        }
    }

    //! Draw the AM/PM label hanging off the right of the numerals.
    //!
    //! The numerals stay centred on the screen and this label sits outside them, so
    //! switching between 12- and 24-hour never moves the main time readout.
    //! @param dc The drawing context
    //! @param width Screen width
    //! @param centerY Vertical centre of the numerals
    //! @param timeText The already-formatted time, needed to measure its width
    //! @param meridiem "AM" or "PM"
    private function drawMeridiem(dc as Dc, width as Number, centerY as Number,
                                  timeText as String, meridiem as String) as Void {
        var timeDims = dc.getTextDimensions(timeText, Graphics.FONT_NUMBER_THAI_HOT);
        var x = (width / 2) + (timeDims[0] / 2) + (width * _MERIDIEM_GAP);
        var y = centerY + (timeDims[1] / 2) - (timeDims[1] * _MERIDIEM_RISE);

        dc.setColor(_theme.muted, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, meridiem,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Draw the second-time readout. Phase 1 is fixed to UTC/ZULU; Phase 3 turns this
    //! into an assignable slot with a configurable offset and label.
    //! @param dc The drawing context
    //! @param width Screen width
    //! @param height Screen height
    private function drawSecondTime(dc as Dc, width as Number, height as Number) as Void {
        var utc = Gregorian.utcInfo(Time.now(), Time.FORMAT_SHORT);
        var text = Lang.format("$1$$2$Z", [utc.hour.format("%02d"), utc.min.format("%02d")]);

        dc.setColor(_theme.data, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, (height * _ZULU_Y).toNumber(), Graphics.FONT_MEDIUM, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Draw the small branding mark
    //! @param dc The drawing context
    //! @param width Screen width
    //! @param height Screen height
    private function drawRescueMark(dc as Dc, width as Number, height as Number) as Void {
        var text = Application.loadResource(Rez.Strings.RescueMark) as String;

        dc.setColor(_theme.muted, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, (height * _MARK_Y).toNumber(), Graphics.FONT_XTINY, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! The device is entering low-power (always-on) mode
    function onEnterSleep() as Void {
        _lowPower = true;
        WatchUi.requestUpdate();
    }

    //! The device is leaving low-power mode
    function onExitSleep() as Void {
        _lowPower = false;
        WatchUi.requestUpdate();
    }
}
