package com.sri.ltc.editor;

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

import javax.swing.*;
import java.awt.*;

/**
 * @author linda
 */
@SuppressWarnings("serial")
public final class AuthorCellRenderer extends JLabel implements ListCellRenderer{

    public AuthorCellRenderer() {
        setOpaque(true);
    }

    public Component getListCellRendererComponent(JList list,
                                                  Object value,
                                                  int index,
                                                  boolean isSelected,
                                                  boolean cellHasFocus) {
        if (value instanceof AuthorCell) {
            AuthorCell author = (AuthorCell) value;
            setText(author.label);
            setForeground(author.getColor());
            setEnabled(author.limited);
        } else {
            setText(value.toString());
            setForeground(list.getForeground());
        }
        setIcon(null);
        setBackground(list.getBackground());

        // handle selection
        if (isSelected)
            setBorder(BorderFactory.createLineBorder(list.getSelectionBackground()));
        else
            setBorder(BorderFactory.createEmptyBorder());

        return this;
    }
}