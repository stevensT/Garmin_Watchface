import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

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

        dc.setColor(text, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (height * Layout.ARC_VALUE_Y).toNumber(),
            Graphics.FONT_XTINY, reading[1] as String,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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
