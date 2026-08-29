import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Connection status, in the empty column left of the numerals.
//!
//! Only what is actually on gets drawn. A row of greyed-out icons showing what is
//! *not* connected is noise on a watch face — the useful question is "is my phone
//! there", not "here are four radios, three of them off". So the column is usually
//! one or two icons tall, and it is centred on the time so it stays balanced
//! whatever is showing.
//!
//! There is no satellite icon. A watch face is not in an activity, so GPS is not
//! acquiring, and the icon would read "no fix" essentially always — and reading
//! position at all would need a manifest permission for the privilege.
module StatusIcons {

    //! Gap between stacked icons
    const GAP = 8;

    //! Loaded once and kept. `onUpdate` runs every second in high power, and
    //! loading four resources a second to draw two of them would be silly.
    var _loaded as Boolean = false;
    var _ble as WatchUi.BitmapResource?;
    var _wifi as WatchUi.BitmapResource?;
    var _lte as WatchUi.BitmapResource?;
    var _notify as WatchUi.BitmapResource?;

    //! Draw the column
    //! @param dc The drawing context
    //! @param width Screen width
    //! @param height Screen height
    function draw(dc as Dc, width as Number, height as Number) as Void {
        load();

        var settings = System.getDeviceSettings();
        var showing = [];

        // Bluetooth first: it is the one people actually look for.
        if (phoneConnected(settings)) {
            showing.add(_ble);
        }
        if (connected(settings, :wifi)) {
            showing.add(_wifi);
        }
        if (connected(settings, :lte)) {
            showing.add(_lte);
        }
        if (settings.notificationCount > 0) {
            showing.add(_notify);
        }

        if (showing.size() == 0) {
            return;
        }

        var total = 0;
        for (var i = 0; i < showing.size(); ++i) {
            total += (showing[i] as WatchUi.BitmapResource).getHeight();
        }
        total += GAP * (showing.size() - 1);

        var centerX = (width * Layout.STATUS_X).toNumber();
        var y = (height * Layout.TIME_Y).toNumber() - (total / 2);

        for (var i = 0; i < showing.size(); ++i) {
            var icon = showing[i] as WatchUi.BitmapResource;
            dc.drawBitmap(centerX - (icon.getWidth() / 2), y, icon);
            y += icon.getHeight() + GAP;
        }
    }

    //! Load the icons, once
    function load() as Void {
        if (_loaded) {
            return;
        }

        _ble = Application.loadResource(Rez.Drawables.IconStatusBle) as WatchUi.BitmapResource;
        _wifi = Application.loadResource(Rez.Drawables.IconStatusWifi) as WatchUi.BitmapResource;
        _lte = Application.loadResource(Rez.Drawables.IconStatusLte) as WatchUi.BitmapResource;
        _notify = Application.loadResource(Rez.Drawables.IconStatusNotify) as WatchUi.BitmapResource;
        _loaded = true;
    }

    //! Whether a radio is connected.
    //!
    //! A key missing from `connectionInfo` means the device has no such radio,
    //! which is not the same as having one that is switched off, but draws the
    //! same: nothing.
    //! @param settings The device settings
    //! @param key :wifi or :lte
    //! @return true if that radio is connected
    function connected(settings as System.DeviceSettings, key as Symbol) as Boolean {
        if (!(settings has :connectionInfo)) {
            return false;
        }

        var connection = settings.connectionInfo[key];
        if (connection == null) {
            return false;
        }

        return connection.state == System.CONNECTION_STATE_CONNECTED;
    }

    //! Whether the phone is connected, preferring the radio's own state and
    //! falling back to the older flag.
    //! @param settings The device settings
    //! @return true if the phone is connected
    function phoneConnected(settings as System.DeviceSettings) as Boolean {
        if (connected(settings, :bluetooth)) {
            return true;
        }

        return settings.phoneConnected;
    }
}
