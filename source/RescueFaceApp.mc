import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! RescueFace — a minimal digital watch face for the Fenix 8 AMOLED family.
class RescueFaceApp extends Application.AppBase {

    //! True when the watch face was launched by the on-device settings editor
    //! rather than worn normally. Editor mode takes an input delegate and skips
    //! complication subscriptions.
    private var _editMode as Boolean = false;

    function initialize() {
        AppBase.initialize();
    }

    //! Handle app startup
    //! @param state Startup arguments; carries the editor flag when present
    function onStart(state as Dictionary?) as Void {
        if (state != null) {
            var launchedFromEditor = state[:launchedFromWatchFaceSettingsEditor] as Boolean?;
            if (launchedFromEditor != null) {
                _editMode = launchedFromEditor;
            }
        }
    }

    //! Return the initial view for the app
    //! @return Array containing the watch face view, plus a delegate in editor mode
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new RescueFaceView(_editMode);

        if (_editMode) {
            return [ view, new RescueFaceDelegate(view) ];
        }

        return [ view ];
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
