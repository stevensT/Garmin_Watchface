import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! RescueFace — a minimal digital watch face for the Fenix 8 AMOLED family.
class RescueFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    //! Return the initial view for the app
    //! @return Array containing the watch face view
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new RescueFaceView() ];
    }

    //! New settings arrived from the Garmin Connect app, so repaint
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}

//! Get the app instance
//! @return the app as a RescueFaceApp
function getApp() as RescueFaceApp {
    return Application.getApp() as RescueFaceApp;
}
