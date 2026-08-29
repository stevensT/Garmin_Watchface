import Toybox.Graphics;
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

    //! Font of the main readout.
    //!
    //! Not the largest one available. FONT_NUMBER_THAI_HOT draws "17:49" at
    //! 363x210 on a 454 px screen, which leaves nothing either side of it: the
    //! seconds ended up pinned against the bezel and the second-time line had to
    //! start before the numerals' box had finished. FONT_NUMBER_HOT is 297x173 and
    //! still reads as the largest thing on the face by a distance.
    const TIME_FONT = Graphics.FONT_NUMBER_HOT;

    //! Font of the second-time line. Larger than a slot value, so it still reads
    //! as a headline, but no longer competing with the main readout.
    const SECOND_TIME_FONT = Graphics.FONT_SMALL;

    //! Vertical centre of the branding mark, at the top rim above the slots.
    //!
    //! The same in both styles, and high enough that it reads as a header rather
    //! than a seventh data point. It clears the top row by more than it looks: a
    //! FONT_XTINY box is 37 px but its ink is nearer 22, so the mark's glyphs stop
    //! around y 41 against a row whose own glyphs start around 56.
    const MARK_Y = 0.065;

    //! Vertical centre of the bottom arc's value, inside the arc's sweep. Not
    //! style-dependent: the arc sits on the rim, which does not move.
    const ARC_VALUE_Y = 0.925;

    //! How wide the mark may be. The screen is only about 181 px across at the
    //! mark's line, and a custom wording can be anything the user types: "MOUNT UP"
    //! is already 157 px. Past this the mark is trimmed rather than allowed to run
    //! off the side of a round screen.
    const MARK_MAX_WIDTH = 0.39;

    // Minimal: one slot above the time, nothing below it but the second time.
    // Nothing competes for the lower half, so the second time gets to sit where it
    // falls naturally rather than where it fits.
    const MINIMAL_ZULU_Y = 0.645;
    const MINIMAL_TOP_ROW_Y = 0.20;

    // Full: two rows of three. Every line below the numerals is placed against the
    // one under it. At 454 px the numerals' baseline lands at 238, the second time
    // then occupies 252-305, and the bottom row starts at 312 — the gaps are single
    // digits, so these four numbers are not as free as they look.
    const FULL_ZULU_Y = 0.615;
    const FULL_TOP_ROW_Y = 0.20;
    const FULL_BOTTOM_ROW_Y = 0.785;

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
