"use strict";
/**
 * Shari Ashti Realesatate — printed on the company's own pre-printed
 * letterhead, not on blank paper.
 *
 * That is the whole design: the sheet already carries the branding, so the
 * document must ADD nothing to those areas and must KEEP OFF them. Only `css`
 * is exported — the layout itself is the shared one, so a fix to the base
 * document reaches this company like any other.
 *
 * What the sheet already has, measured off a scan of it:
 *
 *   left edge    a dark ASHTI strip, 3.07% of the page width  = 6.4mm on A4
 *   top          the ASHTI logo and two rules, down to 10.2%  = 30.3mm
 *   bottom       two rules, an arc, and the contact details,
 *                from 96.2% down                              = 11.3mm
 *
 * So: the band and the footer come off, and the page margins grow to clear
 * what is printed. The 6.4mm strip already sits inside the existing 16mm side
 * margin, so the sides are left alone.
 *
 * The margins carry a few mm of slack on purpose. A scan is approximate and
 * sheet feeding is not exact, so the numbers below are the measurement plus
 * room for both. If a test print still lands on the letterhead, these three
 * values are the only ones to change.
 */

const css = `
/* Clear the pre-printed letterhead. Sides keep the base 16mm, which already
   covers the 6.4mm strip. */
@page{margin:35mm 16mm 16mm;}

/* The sheet has the logo and the company name at the top already; printing
   them again would put two logos on one page. The title stays — that is the
   document speaking, not the letterhead. */
.band, .bandline{display:none !important;}

/* Same for the contact line: the sheet carries the phone numbers, the e-mail
   and the address along its foot. Removing the fixed footer means the space
   reserved for it goes too, or every page would end with a hole in it. */
.foot{display:none !important;}
.footspace{height:0 !important;}

/* The watermark is the company logo again, faintly, across the middle. On a
   sheet that is already branded top, bottom and side it reads as a printing
   fault rather than as branding. */
.watermark{display:none !important;}

/* With the band gone the title is the first thing on the page, and it sat
   tight under a band that is no longer there. */
.title{margin-top:0;}
`;

module.exports = {css};
