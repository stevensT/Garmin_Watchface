import Toybox.Application;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.WatchUi;

//! Which complications have an icon, and how to get it.
//!
//! A slot can hold any of the 44 complication types, and drawing an icon for each
//! would mean shipping 44 pieces of art for the sake of the handful anyone puts on
//! a watch face. So this covers the common ones and returns null for the rest,
//! which keeps their text label — a slot always says what it is, one way or the
//! other.
module SlotIcons {

    //! The icon for a complication type
    //! @param type The complication type
    //! @return The loaded bitmap, or null if this type has no icon
    function forType(type as Number) as WatchUi.BitmapResource? {
        var id = resourceFor(type);
        if (id == null) {
            return null;
        }

        return Application.loadResource(id as ResourceId) as WatchUi.BitmapResource;
    }

    //! The icon resource for a complication type
    //! @param type The complication type
    //! @return The resource id, or null if this type has no icon
    function resourceFor(type as Number) as ResourceId? {
        if (type == Complications.COMPLICATION_TYPE_HEART_RATE) {
            return Rez.Drawables.IconHeartRate;
        }
        if ((type == Complications.COMPLICATION_TYPE_STEPS)
                || (type == Complications.COMPLICATION_TYPE_WHEELCHAIR_PUSHES)) {
            // Wheelchair mode swaps one for the other, and the icon follows.
            return Rez.Drawables.IconSteps;
        }
        if (type == Complications.COMPLICATION_TYPE_BATTERY) {
            return Rez.Drawables.IconBattery;
        }
        if (type == Complications.COMPLICATION_TYPE_BODY_BATTERY) {
            return Rez.Drawables.IconBodyBattery;
        }
        if (type == Complications.COMPLICATION_TYPE_CALORIES) {
            return Rez.Drawables.IconCalories;
        }
        if (type == Complications.COMPLICATION_TYPE_FLOORS_CLIMBED) {
            return Rez.Drawables.IconFloors;
        }
        if ((type == Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE)
                || (type == Complications.COMPLICATION_TYPE_HIGH_LOW_TEMPERATURE)) {
            return Rez.Drawables.IconTemperature;
        }
        if (type == Complications.COMPLICATION_TYPE_ALTITUDE) {
            return Rez.Drawables.IconAltitude;
        }
        if (type == Complications.COMPLICATION_TYPE_SUNRISE) {
            return Rez.Drawables.IconSunrise;
        }
        if (type == Complications.COMPLICATION_TYPE_SUNSET) {
            return Rez.Drawables.IconSunset;
        }
        if (type == Complications.COMPLICATION_TYPE_NOTIFICATION_COUNT) {
            return Rez.Drawables.IconNotifications;
        }
        if (type == Complications.COMPLICATION_TYPE_SLEEP_SCORE) {
            return Rez.Drawables.IconSleep;
        }
        if (type == Complications.COMPLICATION_TYPE_PULSE_OX) {
            return Rez.Drawables.IconPulseOx;
        }
        if (type == Complications.COMPLICATION_TYPE_RESPIRATION_RATE) {
            return Rez.Drawables.IconRespiration;
        }
        if (type == Complications.COMPLICATION_TYPE_INTENSITY_MINUTES) {
            return Rez.Drawables.IconIntensity;
        }
        if ((type == Complications.COMPLICATION_TYPE_DATE)
                || (type == Complications.COMPLICATION_TYPE_WEEKDAY_MONTHDAY)) {
            return Rez.Drawables.IconDate;
        }

        return null;
    }
}
