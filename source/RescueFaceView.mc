import Toybox.Application;
import Toybox.Application.WatchFaceConfig;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! The watch face itself.
//!
//! Everything is drawn in code rather than from a layout resource: the slot grid
//! needs per-slot bounding boxes to hand the on-device editor, and positions are
//! derived from `dc` so one implementation covers 454x454 and 416x416.
class RescueFaceView extends WatchUi.WatchFace {

    //! Gap between the numerals and the AM/PM label, as a fraction of screen width
    private const _MERIDIEM_GAP = 0.015;
    //! How far up from the numerals' bottom edge the AM/PM label sits, as a
    //! fraction of the numeral box height. The FONT_NUMBER_* boxes carry a lot of
    //! descender padding, so sitting flush at the bottom reads as too low.
    private const _MERIDIEM_RISE = 0.22;

    private var _theme as Theme;
    //! True while the device is in low-power (always-on) mode
    private var _lowPower as Boolean = false;
    //! True when running inside the on-device settings editor
    private var _editMode as Boolean = false;

    //! Layout preset from the editor
    private var _style as Styles.Id = Styles.MINIMAL;
    //! One drawable per slot, indexed by slot id - 1
    private var _slots as Array<SlotDrawable> = [];
    //! The complication each slot shows, indexed by slot id - 1
    private var _slotIds as Array<Complications.Id?> = [];

    //! The slot the editor is currently changing, if any
    private var _selectedSlot as Number? = null;
    //! True while the editor is changing a slot, so the face leaves it to the
    //! system to draw and pulse
    private var _editingSlot as Boolean = false;

    //! Minute the slot values were last read, so a per-second redraw in high-power
    //! mode does not re-read six complications every tick
    private var _valuesReadAtMinute as Number = -1;

    //! Screen size and the measured height of a slot's label-over-value stack,
    //! kept from onLayout so slots can be repositioned without a drawing context
    private var _screenWidth as Number = 0;
    private var _screenHeight as Number = 0;
    private var _slotContentHeight as Number = 0;

    //! Constructor
    //! @param editMode Whether the face was launched by the settings editor
    function initialize(editMode as Boolean) {
        WatchFace.initialize();
        _theme = new Theme();
        _editMode = editMode;
    }

    //! Load resources for the watch face
    //! @param dc The drawing context
    function onLayout(dc as Dc) as Void {
        buildSlots(dc);

        var settings = WatchFaceConfig.getSettings(null);
        if (settings == null) {
            // The device has no on-device editor. Everything keeps its default.
            applyDefaultSlots();
            refreshSlotValues();
            return;
        }

        updateConfiguration(settings, null);
    }

    //! Create the six slot drawables and measure what a slot needs vertically
    //! @param dc The drawing context
    private function buildSlots(dc as Dc) as Void {
        _screenWidth = dc.getWidth();
        _screenHeight = dc.getHeight();

        // A slot draws a label with its value underneath. Measure that rather than
        // assume it: a box shorter than the text overflows onto the RESCUE mark.
        _slotContentHeight = dc.getFontHeight(Graphics.FONT_XTINY)
            + dc.getFontHeight(Graphics.FONT_TINY);

        _slots = new Array<SlotDrawable>[Slots.COUNT];
        _slotIds = new Array<Complications.Id?>[Slots.COUNT];

        for (var slot = Slots.ONE; slot <= Slots.COUNT; ++slot) {
            _slots[slot - 1] = new SlotDrawable({ :identifier => slot });
        }

        positionSlots();
    }

    //! Move every slot to where the current style puts it. Called again whenever
    //! the style changes, because the two styles stack the face differently.
    private function positionSlots() as Void {
        for (var slot = Slots.ONE; slot <= Slots.COUNT; ++slot) {
            var rect = Layout.slotRect(slot, _style, _screenWidth, _screenHeight,
                _slotContentHeight);
            var drawable = _slots[slot - 1];
            drawable.locX = rect[0];
            drawable.locY = rect[1];
            drawable.width = rect[2];
            drawable.height = rect[3];
        }
    }

    //! Point every slot at its built-in default complication
    private function applyDefaultSlots() as Void {
        for (var slot = Slots.ONE; slot <= Slots.COUNT; ++slot) {
            _slotIds[slot - 1] = new Complications.Id(Slots.defaultType(slot));
        }
    }

    //! Apply a configuration from the on-device editor.
    //!
    //! Every value can arrive null, and on a fresh install every one of them does,
    //! so each falls back to a default rather than being trusted.
    //! @param config The settings to apply
    //! @param editedType What the user just changed, or null when initialising
    function updateConfiguration(config as WatchFaceConfig.Settings,
                                 editedType as WatchFaceConfigType?) as Void {
        var styleId = config.styleId;
        _style = (styleId != null) ? styleId as Styles.Id : Styles.MINIMAL;

        var accentColor = config.accentColor;
        if ((accentColor != null) && (accentColor.color != null)) {
            _theme.accent = accentColor.color as Number;
        } else {
            _theme.accent = Theme.ACCENT_DEFAULT;
        }

        var dataColor = config.complicationColor;
        if ((dataColor != null) && (dataColor.color != null)) {
            _theme.data = dataColor.color as Number;
        } else {
            _theme.data = Theme.DATA_DEFAULT;
        }

        applyDefaultSlots();

        var slotSettings = config.complicationSettings;
        if (slotSettings != null) {
            for (var i = 0; i < slotSettings.size(); ++i) {
                var uniqueIdentifier = slotSettings[i].uniqueIdentifier;
                if (uniqueIdentifier == null) {
                    continue;
                }

                var slot = uniqueIdentifier as Number;
                if ((slot < Slots.ONE) || (slot > Slots.COUNT)) {
                    continue;
                }

                // A null complicationId means the user has never set this slot,
                // which is the state of every slot on a fresh install.
                var complicationId = slotSettings[i].complicationId;
                if (complicationId != null) {
                    _slotIds[slot - 1] = complicationId;
                }
            }
        }

        _editingSlot = (editedType == WatchUi.WATCH_FACE_CONFIG_TYPE_COMPLICATION);

        // The styles stack the face differently, so a style change moves the slots
        positionSlots();

        _valuesReadAtMinute = -1;
        refreshSlotValues();
        WatchUi.requestUpdate();
    }

    //! Read the current value of every slot complication.
    //!
    //! Phase 3 replaces this with `Complications.subscribeToUpdates` plus a change
    //! callback. Until then the values are pulled once a minute, which is the rate
    //! the face redraws in the mode that matters.
    private function refreshSlotValues() as Void {
        for (var slot = Slots.ONE; slot <= Slots.COUNT; ++slot) {
            var drawable = _slots[slot - 1];
            var complicationId = _slotIds[slot - 1];

            if (complicationId == null) {
                drawable.setContent("", SlotDrawable.EMPTY);
                continue;
            }

            var label = "";
            var value = SlotDrawable.EMPTY;

            try {
                var complication = Complications.getComplication(complicationId);

                var shortLabel = complication.shortLabel;
                if (shortLabel == null) {
                    shortLabel = complication.longLabel;
                }
                if (shortLabel != null) {
                    label = shortLabel;
                }

                var currentValue = complication.value;
                if (currentValue != null) {
                    value = formatValue(currentValue, complication.unit);
                }
            } catch (ex) {
                // The complication is unsupported on this device, or has no data.
                // The slot shows "--" rather than taking the face down.
            }

            drawable.setContent(label, value);
        }
    }

    //! Turn a complication's raw value into something that fits a slot.
    //!
    //! Numeric complications arrive unrounded - temperature reads 10.000000 and
    //! altitude 4057.690430 - so they are rounded to whole units. `unit` is a
    //! string for some complications ("%") and an enum code for others (3, 5), so
    //! only the string form is appended. Phase 4 handles the coded units, which
    //! need the metric/statute setting to mean anything.
    //! @param value The complication's value
    //! @param unit The complication's unit, if it has one
    //! @return The text to draw
    private function formatValue(value as Object, unit as Object?) as String {
        var text;

        if ((value instanceof Lang.Float) || (value instanceof Lang.Double)) {
            text = Math.round(value as Double).toNumber().toString();
        } else {
            text = value.toString();
        }

        if (unit instanceof Lang.String) {
            text += unit;
        }

        return text;
    }

    //! Draw the watch face
    //! @param dc The drawing context
    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var clockTime = System.getClockTime();

        // The editor only needs the snapshot taken when a configuration is applied.
        // Worn normally, values are re-read on the minute.
        if (!_editMode && (clockTime.min != _valuesReadAtMinute)) {
            refreshSlotValues();
            _valuesReadAtMinute = clockTime.min;
        }

        dc.setColor(Graphics.COLOR_TRANSPARENT, _theme.background);
        dc.clear();

        drawTime(dc, width, height, clockTime);
        drawSecondTime(dc, width, height);
        drawSlots(dc);
        drawRescueMark(dc, width, height);
    }

    //! Draw the slots the current style shows
    //! @param dc The drawing context
    private function drawSlots(dc as Dc) as Void {
        var visible = Layout.visibleSlots(_style);

        for (var i = 0; i < visible.size(); ++i) {
            var slot = visible[i];

            // While the editor is changing a slot, the system draws and pulses it.
            // Drawing it here as well would double it up.
            if (_editingSlot && (_selectedSlot == slot)) {
                continue;
            }

            var drawable = _slots[slot - 1];
            drawable.setColors(_theme.data, _theme.muted);
            drawable.draw(dc);
        }
    }

    //! Draw the main HH:MM readout
    //! @param dc The drawing context
    //! @param width Screen width
    //! @param height Screen height
    //! @param clockTime The current time
    private function drawTime(dc as Dc, width as Number, height as Number,
                              clockTime as System.ClockTime) as Void {
        var hours = clockTime.hour;
        var is24Hour = System.getDeviceSettings().is24Hour;
        var hourText;
        var meridiem = null;

        if (is24Hour) {
            // 24-hour reads as a fixed-width pair: 08:49, 20:49
            hourText = hours.format("%02d");
        } else {
            // 12-hour drops the leading zero and carries an AM/PM label: 8:49 PM
            meridiem = (hours >= 12) ? "PM" : "AM";
            hours = hours % 12;
            if (hours == 0) {
                hours = 12;
            }
            hourText = hours.format("%d");
        }

        var text = Lang.format("$1$:$2$", [hourText, clockTime.min.format("%02d")]);
        var centerY = (height * Layout.TIME_Y).toNumber();

        dc.setColor(_theme.accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, centerY, Graphics.FONT_NUMBER_THAI_HOT, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (meridiem != null) {
            drawMeridiem(dc, width, centerY, text, meridiem);
        }
    }

    //! Draw the AM/PM label hanging off the right of the numerals.
    //!
    //! The numerals stay centred on the screen and this label sits outside them, so
    //! switching between 12- and 24-hour never moves the main time readout.
    //! @param dc The drawing context
    //! @param width Screen width
    //! @param centerY Vertical centre of the numerals
    //! @param timeText The already-formatted time, needed to measure its width
    //! @param meridiem "AM" or "PM"
    private function drawMeridiem(dc as Dc, width as Number, centerY as Number,
                                  timeText as String, meridiem as String) as Void {
        var timeDims = dc.getTextDimensions(timeText, Graphics.FONT_NUMBER_THAI_HOT);
        var x = (width / 2) + (timeDims[0] / 2) + (width * _MERIDIEM_GAP);
        var y = centerY + (timeDims[1] / 2) - (timeDims[1] * _MERIDIEM_RISE);

        dc.setColor(_theme.muted, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, meridiem,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Draw the second-time readout. Fixed to UTC/ZULU until Phase 4 wires the
    //! offset and label to phone settings. Its position on the face is fixed: it
    //! is not one of the six slots.
    //! @param dc The drawing context
    //! @param width Screen width
    //! @param height Screen height
    private function drawSecondTime(dc as Dc, width as Number, height as Number) as Void {
        var utc = Gregorian.utcInfo(Time.now(), Time.FORMAT_SHORT);
        var text = Lang.format("$1$$2$Z", [utc.hour.format("%02d"), utc.min.format("%02d")]);

        dc.setColor(_theme.data, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, (height * Layout.zuluY(_style)).toNumber(), Graphics.FONT_MEDIUM, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Draw the small branding mark
    //! @param dc The drawing context
    //! @param width Screen width
    //! @param height Screen height
    private function drawRescueMark(dc as Dc, width as Number, height as Number) as Void {
        var text = Application.loadResource(Rez.Strings.RescueMark) as String;

        dc.setColor(_theme.muted, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, (height * Layout.markY(_style)).toNumber(), Graphics.FONT_XTINY, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Hand the editor the drawable for the slot it is highlighting
    //! @param complication The slot the editor asked about
    //! @return The drawable and its bounding box, or null for an unknown slot
    function getComplication(complication as ComplicationRef) as ComplicationDrawableRef or Null {
        var uniqueIdentifier = complication.uniqueIdentifier;
        if (uniqueIdentifier == null) {
            return null;
        }

        var slot = uniqueIdentifier as Number;
        if ((slot < Slots.ONE) || (slot > Slots.COUNT)) {
            return null;
        }

        _editingSlot = true;
        _selectedSlot = slot;

        var drawable = _slots[slot - 1];
        WatchUi.requestUpdate();

        return new WatchUi.ComplicationDrawableRef({
            :drawable => drawable,
            :boundingBox => drawable.getBoundingBox()
        });
    }

    //! Which slot a tap landed on
    //! @param x Tap x coordinate
    //! @param y Tap y coordinate
    //! @return The slot id, or null if the tap missed every visible slot
    function getTappedSlot(x as Number, y as Number) as Number? {
        var visible = Layout.visibleSlots(_style);

        for (var i = 0; i < visible.size(); ++i) {
            var slot = visible[i];
            if (_slots[slot - 1].containsPoint(x, y)) {
                return slot;
            }
        }

        return null;
    }

    //! The device is entering low-power (always-on) mode
    function onEnterSleep() as Void {
        _lowPower = true;
        WatchUi.requestUpdate();
    }

    //! The device is leaving low-power mode
    function onExitSleep() as Void {
        _lowPower = false;
        WatchUi.requestUpdate();
    }
}
