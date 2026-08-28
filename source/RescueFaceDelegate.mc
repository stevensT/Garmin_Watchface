import Toybox.Application.WatchFaceConfig;
import Toybox.Lang;
import Toybox.WatchUi;

//! Input and configuration callbacks, used only in editor mode.
//!
//! The normal watch face takes no delegate: it is passive. The editor needs one to
//! push configuration changes in and to ask which slot a tap landed on.
class RescueFaceDelegate extends WatchUi.WatchFaceDelegate {

    private var _view as RescueFaceView;

    //! Constructor
    //! @param view The view this delegate drives
    function initialize(view as RescueFaceView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    //! The user changed something in the editor
    //! @param options The edited configuration
    function onWatchFaceConfigEdited(options as {
                :configId as WatchFaceConfig.Id,
                :type as WatchFaceConfigType?,
                :committed as Boolean
            }) as Void {
        var id = options[:configId] as WatchFaceConfig.Id?;
        if (id == null) {
            return;
        }

        var settings = WatchFaceConfig.getSettings(id);
        if (settings != null) {
            _view.updateConfiguration(settings, options[:type] as WatchFaceConfigType?);
        }
    }

    //! Hand the system the drawable for the slot it is editing
    //! @param complication The slot the editor wants to highlight
    //! @return The drawable reference, or null if the slot is unknown
    function getComplicationDrawable(complication as ComplicationRef) as Drawable or ComplicationDrawableRef or Null {
        return _view.getComplication(complication);
    }

    //! Tell the system which slot was tapped, so it can open the picker for it
    //! @param clickEvent The tap
    //! @return true if the tap selected a slot
    function onTap(clickEvent as ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        var slot = _view.getTappedSlot(coords[0], coords[1]);

        if (slot != null) {
            setSelectedComplication(slot);
            return true;
        }

        return false;
    }
}
