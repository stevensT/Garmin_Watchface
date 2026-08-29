import Toybox.Application;
import Toybox.Application.WatchFaceConfig;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
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
    //! The numerals' face, a bundled bitmap font. Loaded once at layout: a font
    //! resource is a real allocation, not a constant.
    private var _timeFont as WatchUi.FontResource?;
    //! One drawable per slot, indexed by slot id - 1
    private var _slots as Array<SlotDrawable> = [];
    //! The complication each slot shows, indexed by slot id - 1
    private var _slotIds as Array<Complications.Id?> = [];

    //! The slot the editor is currently changing, if any
    private var _selectedSlot as Number? = null;
    //! True while the editor is changing a slot, so the face leaves it to the
    //! system to draw and pulse
    private var _editingSlot as Boolean = false;

    //! True once the complication change callback is registered. Subscriptions do
    //! not survive the app shutting down, so this is per-run state.
    private var _subscribed as Boolean = false;

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
        Config.reload();
        _timeFont = Application.loadResource(Rez.Fonts.TimeNumbers) as WatchUi.FontResource;
        buildSlots(dc);

        var settings = WatchFaceConfig.getSettings(null);
        if (settings == null) {
            // The device has no on-device editor. Everything keeps its default.
            applyDefaultSlots();
            refreshSlotValues();
            subscribeSlots();
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

        refreshSlotValues();
        subscribeSlots();
        WatchUi.requestUpdate();
    }

    //! Subscribe to every slot's complication so the system pushes changes.
    //!
    //! Called again after each configuration change, because the user may have
    //! pointed a slot at a different complication. Two slots are allowed to show
    //! the same complication, so the whole set is torn down and rebuilt rather
    //! than unsubscribing slot by slot: dropping one slot's subscription would
    //! silence the other one.
    //!
    //! Editor mode subscribes to nothing. The snapshot taken when a slot is
    //! selected is all the editor shows.
    private function subscribeSlots() as Void {
        if (_editMode) {
            return;
        }

        if (!_subscribed) {
            // Register before subscribing, or the first push has nowhere to land.
            Complications.registerComplicationChangeCallback(method(:onComplicationChange));
            _subscribed = true;
        } else {
            Complications.unsubscribeFromAllUpdates();
        }

        for (var slot = Slots.ONE; slot <= Slots.COUNT; ++slot) {
            var complicationId = _slotIds[slot - 1];
            if (complicationId == null) {
                continue;
            }

            try {
                Complications.subscribeToUpdates(complicationId);
            } catch (ex) {
                // Either the complication does not exist on this device or the
                // system is out of subscription slots. Either way the slot falls
                // back to whatever a direct read gives it, which is usually "--".
            }
        }
    }

    //! The system pushed a new value for a complication
    //! @param id The complication that changed
    function onComplicationChange(id as Complications.Id) as Void {
        var changed = false;

        // A complication can occupy more than one slot, so every slot is checked.
        for (var slot = Slots.ONE; slot <= Slots.COUNT; ++slot) {
            var complicationId = _slotIds[slot - 1];
            if ((complicationId != null) && id.equals(complicationId)) {
                changed = refreshSlot(slot) || changed;
            }
        }

        if (changed) {
            WatchUi.requestUpdate();
        }
    }

    //! Read the current value of every slot complication
    private function refreshSlotValues() as Void {
        for (var slot = Slots.ONE; slot <= Slots.COUNT; ++slot) {
            refreshSlot(slot);
        }
    }

    //! Read one slot's complication and cache what it draws.
    //!
    //! The value is held on the drawable rather than re-read at draw time: the
    //! system pushes changes when they happen, and `onUpdate` runs far more often
    //! than the data underneath it moves.
    //! @param slot The slot to refresh
    //! @return true if what the slot draws changed
    private function refreshSlot(slot as Slots.Id) as Boolean {
        var drawable = _slots[slot - 1];
        var complicationId = _slotIds[slot - 1];

        if (complicationId == null) {
            return drawable.setContent("", SlotDrawable.EMPTY);
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
                value = Units.format(currentValue, complication.unit);
            }
        } catch (ex) {
            // The complication is unsupported on this device, has no data, or its
            // publishing app was uninstalled — the system sends a change for that
            // too. The slot shows "--" rather than taking the face down.
        }

        return drawable.setContent(label, value);
    }

    //! Draw the watch face
    //! @param dc The drawing context
    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var clockTime = System.getClockTime();

        dc.setColor(Graphics.COLOR_TRANSPARENT, Config.backgroundColor());
        dc.clear();

        drawRules(dc, width, height);
        drawTime(dc, width, height, clockTime);
        SecondTime.draw(dc, width, height, _style, _theme.data,
            Config.secondTimeOffset(), Config.secondTimeLabel());
        drawSlots(dc);

        BottomArc.draw(dc, width, height, Config.arcMetric(), _theme.accent,
            Theme.dim(_theme.muted), _theme.data);

        if (Config.showMark()) {
            drawMark(dc, width, height);
        }
    }

    //! The numerals' font, falling back to a system face if the resource failed to
    //! load. A watch face that cannot tell the time is worse than one drawn wrong.
    //! @return The font to draw the numerals in
    private function timeFont() as Graphics.FontType {
        var font = _timeFont;
        return (font != null) ? font : Graphics.FONT_NUMBER_HOT;
    }

    //! Draw the pair of rules bracketing the time block.
    //!
    //! Dim rather than muted: these are for grouping, and a divider that competes
    //! with the data it divides has failed at its job.
    //! @param dc The drawing context
    //! @param width Screen width
    //! @param height Screen height
    private function drawRules(dc as Dc, width as Number, height as Number) as Void {
        var half = (width * Layout.RULE_WIDTH) / 2;
        var left = (width / 2) - half;
        var right = (width / 2) + half;

        dc.setColor(Theme.dim(_theme.muted), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);

        var upper = (height * Layout.RULE_UPPER_Y).toNumber();
        dc.drawLine(left, upper, right, upper);

        var lower = (height * Layout.ruleLowerY(_style)).toNumber();
        dc.drawLine(left, lower, right, lower);
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

        // Seconds are a high-power luxury. Phase 5 decides what, if anything, the
        // dimmed render can afford.
        var seconds = null;
        if (Config.showSeconds() && !_lowPower) {
            seconds = clockTime.sec.format("%02d");
        }

        dc.setColor(_theme.accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, centerY, timeFont(), text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        drawTrailing(dc, width, centerY, text, meridiem, seconds);
    }

    //! Draw the small labels hanging off the right of the numerals.
    //!
    //! The numerals stay centred on the screen and these sit outside them, so
    //! nothing about the main readout moves when the 12/24-hour setting or the
    //! seconds toggle changes.
    //!
    //! Both labels want the same corner. Seconds take the lower line, level with
    //! the numerals' baseline, and AM/PM stacks above them; with only one of the
    //! two in play it takes the lower line on its own.
    //! @param dc The drawing context
    //! @param width Screen width
    //! @param centerY Vertical centre of the numerals
    //! @param timeText The already-formatted time, needed to measure its width
    //! @param meridiem "AM", "PM", or null in 24-hour mode
    //! @param seconds The seconds, or null when they are off
    private function drawTrailing(dc as Dc, width as Number, centerY as Number,
                                  timeText as String, meridiem as String?,
                                  seconds as String?) as Void {
        if ((meridiem == null) && (seconds == null)) {
            return;
        }

        var timeDims = dc.getTextDimensions(timeText, timeFont());
        var x = (width / 2) + (timeDims[0] / 2) + (width * _MERIDIEM_GAP);
        var lowerY = centerY + (timeDims[1] / 2) - (timeDims[1] * _MERIDIEM_RISE);

        dc.setColor(_theme.muted, Graphics.COLOR_TRANSPARENT);

        if (seconds != null) {
            dc.drawText(x, lowerY, Graphics.FONT_XTINY, seconds,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        if (meridiem != null) {
            var y = (seconds != null)
                ? lowerY - dc.getFontHeight(Graphics.FONT_XTINY)
                : lowerY;
            dc.drawText(x, y, Graphics.FONT_XTINY, meridiem,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    //! Draw the branding mark across the top of the face.
    //!
    //! Drawn in the accent colour, so it reads as belonging to the time rather
    //! than to the data. It is the one piece of the face that is neither a
    //! measurement nor a clock.
    //! @param dc The drawing context
    //! @param width Screen width
    //! @param height Screen height
    private function drawMark(dc as Dc, width as Number, height as Number) as Void {
        var text = Config.markText();
        var maxWidth = width * Layout.MARK_MAX_WIDTH;

        while ((text.length() > 1)
                && (dc.getTextWidthInPixels(text, Graphics.FONT_XTINY) > maxWidth)) {
            text = text.substring(0, text.length() - 1) as String;
        }

        dc.setColor(_theme.accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, (height * Layout.MARK_Y).toNumber(), Graphics.FONT_XTINY,
            text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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

    //! The device is leaving low-power mode, which means the user just raised the
    //! watch. Values normally arrive by push, but a slot whose subscription was
    //! refused never gets one, so this is where those catch up.
    function onExitSleep() as Void {
        _lowPower = false;
        refreshSlotValues();
        WatchUi.requestUpdate();
    }
}
