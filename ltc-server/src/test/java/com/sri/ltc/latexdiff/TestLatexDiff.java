/*
 * #%L
 * LaTeX Track Changes (LTC) allows collaborators on a version-controlled LaTeX writing project to view and query changes in the .tex documents.
 * %%
 * Copyright (C) 2009 - 2012 SRI International
 * %%
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, either version 3 of the 
 * License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public 
 * License along with this program.  If not, see
 * <http://www.gnu.org/licenses/gpl-3.0.html>.
 * #L%
 */
package com.sri.ltc.latexdiff;

import com.google.common.collect.Lists;
import org.junit.Test;

import java.util.EnumSet;
import java.util.List;

import static com.sri.ltc.latexdiff.Change.*;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

/**
 * @author linda
 */
public class TestLatexDiff {

    private static final LatexDiff latexDiff = new LatexDiff();
    protected List<Change> changes;

    protected static List<Change> getChanges(String text1, String text2) throws Exception {
        return latexDiff.getChanges(
                new StringReaderWrapper(text1),
                new StringReaderWrapper(text2));
    }

    protected void assertAddition(int index, int start_position, List<IndexFlagsPair<Integer>> flags) {
        assertTrue("at least "+(index+1)+" changes", changes.size() >= index+1);
        Change change = changes.get(index);
        assertTrue("change is addition", change instanceof Addition);
        assertTrue("start is at " + start_position, change.start_position == start_position);
        assertEquals("addition flags", flags, change.flags);
    }

    protected void assertDeletion(int index, int start_position, List<IndexFlagsPair<String>> flags) {
        assertTrue("at least "+(index+1)+" changes", changes.size() >= index+1);
        Change change = changes.get(index);
        assertTrue("change is deletion", change instanceof Deletion);
        assertEquals("start position", start_position, change.start_position);
        assertEquals("deletion flags", flags, change.flags);
    }

    @Test(expected = NullPointerException.class)
    public void nullReader() throws Exception {
        changes = getChanges("", null);
    }

    @Test
    public void whitespace() throws Exception {
        changes = getChanges("", " \n   \t");
        assertTrue("Changes is empty", changes.isEmpty());
        changes = getChanges(
                "   Lorem ipsum \n dolor sit amet. ",
                "Lorem ipsum dolor sit amet.");
        assertTrue("Changes is empty", changes.isEmpty());
        changes = getChanges("   \n ", " \t  ");
        assertTrue("Changes is empty", changes.isEmpty());
        changes = getChanges(
                "   Lorem ipsum \n \ndolor sit amet. \\begin{document}",
                "Lorem ipsum dolor sit amet. \n\\begin{document}");
        assertTrue("Changes is empty", changes.isEmpty());
        changes = getChanges(
                "Lorem ipsum dolor sit amet. \n \\begin{document}",
                "   Lorem ipsum \n \ndolor sit amet.\\begin{document}");
        assertTrue("Changes is empty", changes.isEmpty());
        changes = getChanges("\nold\n", "\nnew\n");
        assertAddition(0, 0, Lists.newArrayList(new IndexFlagsPair<Integer>(5, EnumSet.noneOf(Flag.class))));
        assertDeletion(1, 0, Lists.newArrayList(new IndexFlagsPair<String>("\nold", EnumSet.of(Flag.DELETION))));
    }

    @Test
    public void inComment() throws Exception {
        changes = getChanges(
                " \nLorem ipsum %%%  HERE IS A COMMMENT WITH SPACE...\n dolor sit amet. \n ",
                "Lorem ipsum \n%%%  HERE IS A COMMENT WITH SPACE AND MORE %...\n dolor sit amet."
        );
        assertDeletion(0, 32, Lists.newArrayList(new IndexFlagsPair<String>(
                "M",
                EnumSet.of(Flag.DELETION, Flag.SMALL))));
        assertAddition(1, 46, Lists.newArrayList(new IndexFlagsPair<Integer>(
                57,
                EnumSet.noneOf(Flag.class))));
    }

    @Test
    public void inPreamble() throws Exception {
        changes = getChanges(
                " \n\n \\begin{document}  \n \nLorem ipsum \n dolor sit amet. \n ",
                " \n\\usepackage{lipsum}\n \\begin{document}  \n \nLorem ipsum \n dolor sit amet. \n "
        );
        assertAddition(0, 0,
                Lists.newArrayList(
                        new IndexFlagsPair<Integer>(13, EnumSet.of(Flag.COMMAND, Flag.PREAMBLE)),
                        new IndexFlagsPair<Integer>(23, EnumSet.of(Flag.PREAMBLE))));
        changes = getChanges(
                " \n\\usepackage{lipsum}\n \\begin{document}  \n \nLorem ipsum \n dolor sit amet. \n ",
                " \n\n \\begin{document}  \n \nLorem ipsum \n dolor sit amet. \n "
        );
        assertDeletion(0, 0, Lists.newArrayList(
                new IndexFlagsPair<String>(" \n\\usepackage", EnumSet.of(Flag.DELETION, Flag.COMMAND, Flag.PREAMBLE)),
                new IndexFlagsPair<String>("{lipsum}", EnumSet.of(Flag.DELETION, Flag.PREAMBLE))));
        changes = getChanges(
                " \n\\usepackage{lipsum}\n \\begin{document}  \n \nLorem ipsum \n dolor sit amet. \n ",
                " \n\n % start doc\n\n\\begin{document}  \n \nLorem ipsum \n dolor sit amet. \n "
        );
        assertAddition(0, 0,
                Lists.newArrayList(new IndexFlagsPair<Integer>(
                        17,
                        EnumSet.of(Flag.PREAMBLE))));
        assertDeletion(1, 0, Lists.newArrayList(
                new IndexFlagsPair<String>(" \n\\usepackage", EnumSet.of(Flag.DELETION, Flag.COMMAND, Flag.PREAMBLE)),
                new IndexFlagsPair<String>("{lipsum}", EnumSet.of(Flag.DELETION, Flag.PREAMBLE))));
    }

    @Test
    public void commentThenText() throws Exception {
        changes = getChanges(
                "% Need life\n",
                "% Need \nLife"
        );
        assertAddition(0, 8,
                Lists.newArrayList(new IndexFlagsPair<Integer>(
                        9,
                        EnumSet.of(Flag.SMALL)))
        );
        assertDeletion(1, 8,
                Lists.newArrayList(
                    new IndexFlagsPair<String>("l", EnumSet.of(Flag.DELETION, Flag.SMALL))
                )
         );
    }

    @Test
    public void test3Diff() throws Exception {
        MarkedUpDocument document = new MarkedUpDocument();
        document.insertString(0, "  Lorem ipsum   dolor sit. ", null);
        document.markupAddition(7, 16, EnumSet.noneOf(Flag.class));
        document.insertDeletion(25, "   amet", EnumSet.of(Flag.DELETION));
        changes = latexDiff.getChanges(
                new StringReaderWrapper(" Lorem    amet,  consectetur."),
                new DocumentReaderWrapper(document));
        assertEquals("Number of changes", 2, changes.size());
    }
}
