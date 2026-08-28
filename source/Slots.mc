import Toybox.Complications;
import Toybox.Lang;

//! The six data slots.
//!
//! Ids match the `<complication id=…>` entries in `resources/configs/watchface.xml`
//! and come back from the editor as `uniqueIdentifier`. They must stay stable:
//! saved editor variants on the watch key on them.
module Slots {

    enum Id {
        ONE = 1,
        TWO,
        THREE,
        FOUR,
        FIVE,
        SIX
    }

    //! How many slots the face declares
    const COUNT = 6;

    //! The complication a slot falls back to when the editor has no choice stored
    //! for it, which is the case on a fresh install and for any slot the user has
    //! never touched. The config resource cannot carry these itself: declaring
    //! `<type default="true">` there would pin the slot to that one type and drop
    //! `allowAny`, costing the user the full complication list.
    //! @param slot The slot id
    //! @return The default complication type for that slot
    function defaultType(slot as Id) as Complications.Type {
        switch (slot) {
            case ONE:
                return Complications.COMPLICATION_TYPE_WEEKDAY_MONTHDAY;
            case TWO:
                return Complications.COMPLICATION_TYPE_BATTERY;
            case THREE:
                return Complications.COMPLICATION_TYPE_HEART_RATE;
            case FOUR:
                return Complications.COMPLICATION_TYPE_STEPS;
            case FIVE:
                return Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE;
            case SIX:
            default:
                return Complications.COMPLICATION_TYPE_ALTITUDE;
        }
    }
}

//! Layout presets, matching the `<style id=…>` entries in the config resource.
module Styles {

    enum Id {
        //! Time, second time, and the RESCUE mark only
        MINIMAL = 1,
        //! Every data slot drawn
        FULL
    }
}
