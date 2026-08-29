import Toybox.Complications;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

//! Turning a complication's raw value into text a slot can hold.
//!
//! Complications publish coded units in metric no matter what the user has the
//! watch set to — distances and elevations in metres, temperature in Celsius,
//! speed in metres per second, weight in grams — and the SDK makes converting the
//! subscriber's job. That conversion follows the watch's own unit settings rather
//! than a setting of ours, so the face reads the same way as the rest of the
//! device.
//!
//! Some complications report `unit` as a plain string instead ("%"), which is
//! already display-ready and is appended untouched.
module Units {

    const FEET_PER_METRE = 3.28084;
    const MILES_PER_METRE = 0.000621371;
    const KM_PER_METRE = 0.001;
    const KMH_PER_MS = 3.6;
    const MPH_PER_MS = 2.23694;
    const POUNDS_PER_GRAM = 0.00220462;
    const KG_PER_GRAM = 0.001;

    //! Above this many metres a distance reads better in kilometres than metres
    const METRES_PER_KM = 1000;

    //! Format a complication value for display in a slot
    //! @param value The complication's value
    //! @param unit The complication's unit: a coded UNIT_*, a string, or null
    //! @return The text to draw
    function format(value as Object, unit as Object?) as String {
        if (unit instanceof Lang.Number) {
            return formatCoded(value, unit as Number);
        }

        var text = whole(value);

        // A string unit is whatever the publisher wants shown, so it is appended
        // as given rather than interpreted.
        if (unit instanceof Lang.String) {
            text += unit;
        }

        return text;
    }

    //! Convert a metric value to the watch's units and label it
    //! @param value The complication's value, in the SDK's published unit
    //! @param unit The coded unit
    //! @return The text to draw
    function formatCoded(value as Object, unit as Number) as String {
        if (!(value instanceof Lang.Number) && !(value instanceof Lang.Float)
                && !(value instanceof Lang.Long) && !(value instanceof Lang.Double)) {
            // A coded unit on a non-numeric value is a publisher's mistake. Show
            // the value and leave the unit off rather than guess at a conversion.
            return value.toString();
        }

        var metres = value.toDouble();
        var settings = System.getDeviceSettings();

        if (unit == Complications.UNIT_TEMPERATURE) {
            if (settings.temperatureUnits == System.UNIT_STATUTE) {
                return round((metres * 9.0 / 5.0) + 32.0) + "°";
            }
            return round(metres) + "°";
        }

        if (unit == Complications.UNIT_ELEVATION) {
            if (settings.elevationUnits == System.UNIT_STATUTE) {
                return round(metres * FEET_PER_METRE) + "ft";
            }
            return round(metres) + "m";
        }

        // Altitude reports itself as a height rather than an elevation, and no
        // complication publishes a body height, so this follows the elevation
        // setting. `heightUnits` is about how tall the user is.
        if (unit == Complications.UNIT_HEIGHT) {
            if (settings.elevationUnits == System.UNIT_STATUTE) {
                return round(metres * FEET_PER_METRE) + "ft";
            }
            return round(metres) + "m";
        }

        if (unit == Complications.UNIT_DISTANCE) {
            if (settings.distanceUnits == System.UNIT_STATUTE) {
                return oneDecimal(metres * MILES_PER_METRE) + "mi";
            }
            // Weekly totals run to tens of kilometres and a walk to the shop does
            // not, so the scale of the number picks the unit.
            if (metres >= METRES_PER_KM) {
                return oneDecimal(metres * KM_PER_METRE) + "km";
            }
            return round(metres) + "m";
        }

        if (unit == Complications.UNIT_SPEED) {
            if (settings.paceUnits == System.UNIT_STATUTE) {
                return round(metres * MPH_PER_MS) + "mph";
            }
            return round(metres * KMH_PER_MS) + "kph";
        }

        if (unit == Complications.UNIT_WEIGHT) {
            if (settings.weightUnits == System.UNIT_STATUTE) {
                return round(metres * POUNDS_PER_GRAM) + "lb";
            }
            return round(metres * KG_PER_GRAM) + "kg";
        }

        // UNIT_INVALID, or a unit added after this was written.
        return whole(value);
    }

    //! A numeric value as whole units, or a non-numeric one as its own text.
    //! Complications hand back unrounded floats — altitude arrives as
    //! 4057.690430 — and a slot has no room for the tail.
    //! @param value The value to render
    //! @return The text
    function whole(value as Object) as String {
        if ((value instanceof Lang.Float) || (value instanceof Lang.Double)) {
            return round(value.toDouble());
        }
        return value.toString();
    }

    //! Round to a whole number
    //! @param value The value to round
    //! @return The text
    function round(value as Double) as String {
        return Math.round(value).toNumber().toString();
    }

    //! Round to one decimal place, for values where whole units are too coarse
    //! @param value The value to round
    //! @return The text
    function oneDecimal(value as Double) as String {
        return value.format("%.1f");
    }
}
