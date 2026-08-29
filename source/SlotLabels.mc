import Toybox.Complications;
import Toybox.Lang;

//! Short names for the complications Garmin does not give one to.
//!
//! Garmin names its complications two different ways. Most publish a short caps
//! label that fits a slot with room to spare — `BAT`, `HR`, `ALT`, `STEPS` — and
//! those are used as they come. But 21 of the 41 that carry a name at all publish
//! prose instead: `Pulse Oximeter`, `Respiration Rate`, `Half Marathon Race
//! Prediction` at 423 px against a slot barely 100 px wide. Trimming those to fit
//! mechanically gives `Respir` and `Traini`, which is legible and ugly.
//!
//! Two of them are worse than ugly, and no amount of trimming fixes either:
//!
//! - `VO2MAX_RUN` and `VO2MAX_BIKE` publish the **same** label, `VO2 MAX.`, so on
//!   a face showing both there is nothing to tell them apart.
//! - The eight race and pace predictors differ only in a word that trimming cuts
//!   off, so `5k Race Prediction` and `5k Pace Prediction` both land on `5k`.
//!
//! So the distance predictors take a suffix rather than a bare distance: `5K T`
//! for the time a race is predicted to take, `5K P` for the pace it implies.
//! Everything here is uppercase because the label font is an uppercase atlas —
//! see `SlotDrawable` and `resources/fonts/fonts.xml`.
module SlotLabels {

    //! A short name for a complication type, or null to use what Garmin published.
    //!
    //! Only the types whose own label does not fit are listed. Anything absent
    //! falls through to the published label, which keeps this table to the cases
    //! that need it rather than restating Garmin's work.
    //! @param type The complication type
    //! @return The short name, or null
    function forType(type as Number) as String? {
        switch (type) {
            case Complications.COMPLICATION_TYPE_INTENSITY_MINUTES:
                return "INT MIN";
            case Complications.COMPLICATION_TYPE_CURRENT_WEATHER:
                return "WX";
            case Complications.COMPLICATION_TYPE_FORECAST_WEATHER_1DAY:
                return "WX +1";
            case Complications.COMPLICATION_TYPE_FORECAST_WEATHER_2DAY:
                return "WX +2";
            case Complications.COMPLICATION_TYPE_FORECAST_WEATHER_3DAY:
                return "WX +3";
            case Complications.COMPLICATION_TYPE_RECOVERY_TIME:
                return "RECOVERY";
            case Complications.COMPLICATION_TYPE_TRAINING_STATUS:
                return "TRAINING";
            case Complications.COMPLICATION_TYPE_PULSE_OX:
                return "SPO2";
            case Complications.COMPLICATION_TYPE_RESPIRATION_RATE:
                return "RESP";
            case Complications.COMPLICATION_TYPE_HIGH_LOW_TEMPERATURE:
                return "HI/LO";
            case Complications.COMPLICATION_TYPE_LAST_GOLF_ROUND_SCORE:
                return "GOLF";
            case Complications.COMPLICATION_TYPE_VO2MAX_RUN:
                return "VO2 RUN";
            case Complications.COMPLICATION_TYPE_VO2MAX_BIKE:
                return "VO2 BIKE";
            case Complications.COMPLICATION_TYPE_RACE_PREDICTOR_5K:
                return "5K T";
            case Complications.COMPLICATION_TYPE_RACE_PREDICTOR_10K:
                return "10K T";
            case Complications.COMPLICATION_TYPE_RACE_PREDICTOR_HALF_MARATHON:
                return "HALF T";
            case Complications.COMPLICATION_TYPE_RACE_PREDICTOR_MARATHON:
                return "MAR T";
            case Complications.COMPLICATION_TYPE_RACE_PACE_PREDICTOR_5K:
                return "5K P";
            case Complications.COMPLICATION_TYPE_RACE_PACE_PREDICTOR_10K:
                return "10K P";
            case Complications.COMPLICATION_TYPE_RACE_PACE_PREDICTOR_HALF_MARATHON:
                return "HALF P";
            case Complications.COMPLICATION_TYPE_RACE_PACE_PREDICTOR_MARATHON:
                return "MAR P";
            default:
                return null;
        }
    }
}
