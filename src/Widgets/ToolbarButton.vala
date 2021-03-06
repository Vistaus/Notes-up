/*
* Copyright (c) 2016 Felipe Escoto (https://github.com/Philip-Scott/Notes-up)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 59 Temple Place - Suite 330,
* Boston, MA 02111-1307, USA.
*
* Authored by: Felipe Escoto <felescoto95@hotmail.com>
*/


public class ENotes.ToolbarButton : Gtk.Button {
    private Gtk.SourceBuffer code_buffer;
    private Plugin plugin;

    private int type = 0; // 1 = Image Button, 2 = Plugin Button

    private string first_half;
    private string second_half;

    construct {
        can_focus = false;
        get_style_context ().add_class ("flat");
    }

    public ToolbarButton (string icon, string first_half, string second_half, string description = "", Gtk.SourceBuffer code_buffer) {
        var image = new Gtk.Image.from_icon_name (icon, Gtk.IconSize.SMALL_TOOLBAR);
        this.add (image);

        this.code_buffer = code_buffer;
        this.first_half = first_half;
        this.second_half = second_half;

        set_tooltip_markup (description);

        connect_signal ();
    }

    public ToolbarButton.is_image_button (string icon, string first_half, string second_half, string description = "", Gtk.SourceBuffer code_buffer) {
        this (icon, first_half, second_half, description, code_buffer);
        type = 1;
    }

    public ToolbarButton.from_plugin (Plugin plugin, Gtk.Widget widget, Gtk.SourceBuffer code_buffer) {
        this.plugin = plugin;
        this.code_buffer = code_buffer;
        add (widget);
        set_tooltip_text (plugin.get_button_desctiption ());

        type = 2;

        connect_signal ();
        plugin.string_cooked.connect ((t) => {
            if (code_buffer.has_selection) {
                Gtk.TextIter start, end;
                code_buffer.get_selection_bounds (out start, out end);
                code_buffer.@delete (ref start, ref end);
                code_buffer.insert_at_cursor (t, -1);
            } else {
                code_buffer.insert_at_cursor (t, -1);
            }
        });
    }

    private void connect_signal () {
        clicked.connect (() => {
            Gtk.TextIter start, end;
            code_buffer.get_selection_bounds (out start, out end);

            if (code_buffer.has_selection) {
                var text = start.get_text (end);
                if (this.type == 2) {
                    plugin.request_string (text);
                } else {
                    var wrapped_text = WordWrapper.wrap_string (text, first_half, second_half);
                    this.change_text (start, end, wrapped_text);
                }
            } else {
                if (this.type == 1) {
                    var file = FileManager.get_file_from_user ("image", Gtk.FileChooserAction.OPEN);

                    if (file != null) {
                        var image_id = ImageTable.get_instance ().save (ViewEditStack.get_instance ().current_page.id, file);

                        code_buffer.insert (ref end, "<image %lld>".printf (image_id), -1);
                        code_buffer.place_cursor (end);
                    }
                } else if (type == 2) {
                    plugin.request_string ("");
                } else {
                    Gtk.TextIter cursor_position;
                    code_buffer.get_iter_at_offset (out cursor_position, code_buffer.cursor_position);

                    if (is_cursor_inside_word (cursor_position, first_half, second_half)) {
                        // gets word the cursor is currently on and modify it
                        start = end = cursor_position;
                        var word = WordWrapper.identify_word (ref start, ref end, first_half, second_half);
                        var wrapped_text = WordWrapper.wrap_string (word, first_half, second_half);
                        this.change_text (start, end, wrapped_text);
                    } else {
                        // prints the wrapping text and put cursor in the middle
                        code_buffer.insert_at_cursor (first_half + second_half, -1);
                        code_buffer.get_iter_at_offset (out cursor_position, code_buffer.cursor_position);
                        cursor_position.backward_chars (second_half.length);
                        code_buffer.place_cursor (cursor_position);
                    }
                }
            }
        });
    }

    /**
     * Detects if cursor is inside a word
     */
    private bool is_cursor_inside_word (Gtk.TextIter cursor_position, string first_half, string second_half) {
        return cursor_position.inside_word () ||
                cursor_position.get_char ().isspace () ||
                cursor_position.get_char ().to_string () in first_half ||
                cursor_position.get_char ().to_string () in second_half;
    }

    /**
     * Replaces the content from  iter start to iter end with the informed text
     */
    private void change_text (Gtk.TextIter start, Gtk.TextIter end, string text) {
        code_buffer.@delete (ref start, ref end);
        code_buffer.insert_at_cursor (text, -1);
    }
}
