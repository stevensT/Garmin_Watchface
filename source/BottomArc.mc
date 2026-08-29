import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

//! The gauge along the bottom rim.
//!
//! A single metric drawn as a filled arc against a dim track, with its value
//! underneath. Unlike a data slot it is not a complication: an arc needs a range
//! to be honest about, and the complication system does not reliably publish one.
//! So the arc reads its own sources, and only offers metrics whose range is not in
//! question — battery is 0 to 100 by definition, and steps have a goal the user set
//! themselves.
//!
//! It occupies the rim below everything else, with its value sitting inside the
//! sweep. That space came free when the branding mark moved to the top of the face.
module BottomArc {

    //! What the arc tracks. Values match the phone setting's list entries.
    enum Metric {
        OFF = 0,
        BATTERY = 1,
        STEPS = 2
    }

    //! Thickness of the arc, and how far its outer edge sits inside the screen
    const PEN = 8;
    const INSET = 4;

    //! The sweep, in degrees, where 0 is 3 o'clock and 270 is 6 o'clock. Kept
    //! shallow on purpose: a wider arc reaches up the sides of the screen into the
    //! bottom row of slots.
    //! At 454x454 these put the arc's ends at y 406, five pixels below the bottom
    //! row of slots, and its body clears the value text sitting inside it. Widen
    //! the sweep and the ends climb into the outer slots.
    //! Gap between the icon and its value
    const ICON_GAP = 6;

    //! The icon currently loaded, and what it is for. The metric only changes when
    //! the user changes it, so this loads once in practice.
    var _icon as WatchUi.BitmapResource?;
    var _iconMetric as Number = OFF;

    //! The readout's face, loaded on first use
    var _font as WatchUi.FontResource?;

    const START = 235;
    const END = 305;

    //! Draw the arc and its value
    //! @param dc The drawing context
    //! @param width Screen width
    //! @param height Screen height
    //! @param metric What to track
    //! @param fill Colour of the filled portion
    //! @param track Colour of the unfilled remainder
    //! @param text Colour of the value
    function draw(dc as Dc, width as Number, height as Number,
                  metric as Number, fill as Graphics.ColorType,
                  track as Graphics.ColorType, text as Graphics.ColorType) as Void {
        if (metric == OFF) {
            return;
        }

        var reading = read(metric);
        if (reading == null) {
            return;
        }

        var centerX = width / 2;
        var centerY = height / 2;
        var radius = (width / 2) - INSET - (PEN / 2);

        dc.setPenWidth(PEN);

        dc.setColor(track, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(centerX, centerY, radius, Graphics.ARC_COUNTER_CLOCKWISE, START, END);

        var filled = START + ((END - START) * (reading[0] as Float));
        if (filled > START) {
            dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(centerX, centerY, radius, Graphics.ARC_COUNTER_CLOCKWISE,
                START, filled.toNumber());
        }

        // Leave the pen as it was found; everything else on the face draws text,
        // which does not care, but a future line would.
        dc.setPenWidth(1);

        drawValue(dc, centerX, (height * Layout.ARC_VALUE_Y).toNumber(),
            metric, reading[1] as String, text);
    }

    //! Draw the arc's icon and value as one centred group.
    //!
    //! The value is smaller than a slot's, and the icon does the naming: a number
    //! on the rim with no label is ambiguous, and "BAT" spelled out next to a
    //! battery would be saying it twice.
    //! @param dc The drawing context
    //! @param centerX Horizontal centre of the face
    //! @param y Vertical centre of the readout
    //! @param metric What the arc tracks, which picks the icon
    //! @param value The text to draw
    //! @param color Colour of the value
    function drawValue(dc as Dc, centerX as Number, y as Number, metric as Number,
                       value as String, color as Graphics.ColorType) as Void {
        var icon = iconFor(metric);
        var font = valueFont();
        var textWidth = dc.getTextWidthInPixels(value, font);
        var iconWidth = (icon == null) ? 0 : icon.getWidth() + ICON_GAP;
        var left = centerX - ((iconWidth + textWidth) / 2);

        if (icon != null) {
            dc.drawBitmap(left, y - (icon.getHeight() / 2), icon);
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + iconWidth, y, font, value,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! The readout's font, loaded once, falling back to the smallest system face
    //! @return The font to draw the value in
    function valueFont() as Graphics.FontType {
        if (_font == null) {
            _font = Application.loadResource(Rez.Fonts.ArcValue) as WatchUi.FontResource;
        }

        var font = _font;
        return (font != null) ? font : Graphics.FONT_XTINY;
    }

    //! The icon for a metric, loaded once and kept
    //! @param metric What the arc tracks
    //! @return The icon, or null if the metric has none
    function iconFor(metric as Number) as WatchUi.BitmapResource? {
        if (metric != _iconMetric) {
            _icon = (metric == BATTERY)
                ? Application.loadResource(Rez.Drawables.IconBattery) as WatchUi.BitmapResource
                : Application.loadResource(Rez.Drawables.IconSteps) as WatchUi.BitmapResource;
            _iconMetric = metric;
        }

        return _icon;
    }

    //! Read the metric
    //! @param metric What to track
    //! @return [fraction filled from 0 to 1, text to draw], or null if unreadable
    function read(metric as Number) as Array? {
        if (metric == BATTERY) {
            var battery = System.getSystemStats().battery;
            return [
                clamp(battery / 100.0),
                Math.round(battery).toNumber().toString() + "%"
            ];
        }

        if (metric == STEPS) {
            var info = ActivityMonitor.getInfo();
            var steps = info.steps;
            if (steps == null) {
                return null;
            }

            // A goal of null or zero means there is nothing to be a fraction of.
            // The count is still worth showing, so the arc just stays empty.
            var goal = info.stepGoal;
            var fraction = 0.0;
            if ((goal != null) && (goal > 0)) {
                fraction = clamp(steps.toFloat() / goal.toFloat());
            }

            return [fraction, steps.toString()];
        }

        return null;
    }

    //! Hold a fraction inside the arc. Steps past the goal are the reason: the day
    //! keeps going but the arc has run out of rim.
    //! @param value The raw fraction
    //! @return The fraction, between 0 and 1
    function clamp(value as Float) as Float {
        if (value < 0.0) {
            return 0.0;
        }
        if (value > 1.0) {
            return 1.0;
        }
        return value;
    }
}
