import Toybox.Lang;

//! Where things sit on the face.
//!
//! Provisional geometry. Phase 4 tunes it against both resolutions; Phase 2 needs
//! it now because the on-device editor cannot highlight a slot without a bounding
//! box to draw around.
//!
//! Everything is a fraction of the drawing context, so one set of numbers covers
//! 454x454 and 416x416. Positions differ per style: a style *is* a layout preset,
//! and Full has to fit two slot rows into the same screen, so its second-time line
//! and mark tighten up to make room. Minimal keeps the roomier spacing.
module Layout {

    //! Vertical centre of the main time readout. The same in both styles: it is
    //! the anchor everything else is arranged around.
    const TIME_Y = 0.44;

    // Minimal: one slot above the time, nothing below it but the second time and
    // the mark, both where they have always sat.
    const MINIMAL_ZULU_Y = 0.64;
    const MINIMAL_MARK_Y = 0.82;
    const MINIMAL_TOP_ROW_Y = 0.20;

    // Full: two rows of three. The bottom row has to fit between the second time
    // and the mark, so both of those move to clear it.
    const FULL_ZULU_Y = 0.60;
    const FULL_MARK_Y = 0.925;
    const FULL_TOP_ROW_Y = 0.20;
    const FULL_BOTTOM_ROW_Y = 0.775;

    //! Horizontal distance from the centre column to a side column. The top row is
    //! tighter because the round screen has less chord to work with up there.
    //!
    //! Both spreads must stay wider than `SLOT_WIDTH`. A spread narrower than a
    //! slot overlaps the boxes, and while centred text may still look fine, the
    //! editor picks the first box a tap falls inside and pulses the wrong slot.
    const TOP_SPREAD = 0.25;
    const BOTTOM_SPREAD = 0.27;

    //! Width of one slot. Three of these plus the gaps have to sit inside the
    //! chord at the top row, which is the narrowest line the slots use: at 454x454
    //! that chord is about 362 px against 313 px of slot.
    const SLOT_WIDTH = 0.23;

    //! Vertical centre of the second-time line
    //! @param style The layout style
    //! @return The centre as a fraction of screen height
    function zuluY(style as Styles.Id) as Float {
        return (style == Styles.FULL) ? FULL_ZULU_Y : MINIMAL_ZULU_Y;
    }

    //! Vertical centre of the RESCUE mark
    //! @param style The layout style
    //! @return The centre as a fraction of screen height
    function markY(style as Styles.Id) as Float {
        return (style == Styles.FULL) ? FULL_MARK_Y : MINIMAL_MARK_Y;
    }

    //! The bounding rect of a slot, as [x, y, width, height] with x,y at the top
    //! left corner. The editor requires the top left corner, not the centre.
    //!
    //! `contentHeight` is measured from the fonts rather than assumed: a slot draws
    //! a label above a value, and a box shorter than that overflows onto whatever
    //! sits below it.
    //! @param slot The slot id
    //! @param style The layout style
    //! @param width Screen width
    //! @param height Screen height
    //! @param contentHeight Height of a label stacked on a value
    //! @return The slot rect
    function slotRect(slot as Slots.Id, style as Styles.Id, width as Number,
                      height as Number, contentHeight as Number) as Array<Number> {
        var isTopRow = (slot <= Slots.THREE);
        var isFull = (style == Styles.FULL);

        var rowFraction;
        if (isTopRow) {
            rowFraction = isFull ? FULL_TOP_ROW_Y : MINIMAL_TOP_ROW_Y;
        } else {
            rowFraction = FULL_BOTTOM_ROW_Y;
        }

        var rowY = rowFraction * height;
        var spread = (isTopRow ? TOP_SPREAD : BOTTOM_SPREAD) * width;

        // 0 = left, 1 = centre, 2 = right
        var column = (slot - 1) % 3;
        var centerX = (width / 2.0) + ((column - 1) * spread);

        var slotWidth = SLOT_WIDTH * width;

        return [
            (centerX - (slotWidth / 2)).toNumber(),
            (rowY - (contentHeight / 2)).toNumber(),
            slotWidth.toNumber(),
            contentHeight
        ];
    }

    //! Which slots a style draws.
    //!
    //! Minimal shows the one centre slot above the time and nothing else, which is
    //! what keeps the bottom of the face clear. Full draws all six.
    //! @param style The layout style
    //! @return The slot ids that style draws
    function visibleSlots(style as Styles.Id) as Array<Slots.Id> {
        if (style == Styles.FULL) {
            return [ Slots.ONE, Slots.TWO, Slots.THREE, Slots.FOUR, Slots.FIVE, Slots.SIX ];
        }
        return [ Slots.TWO ];
    }
}
