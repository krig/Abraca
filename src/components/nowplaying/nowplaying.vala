public class Abraca.NowPlaying : Gtk.DrawingArea
{
	public signal void hide_now_playing();

	private Gdk.Pixbuf coverart;

	private Client client;

	private string artist;
	private string album;
	private string title;

	private bool fullscreen = false;

	public NowPlaying(Client client)
	{
		this.client = client;

		this.client.playback_current_info.connect(on_playback_current_info);
		this.client.playback_current_coverart.connect(on_playback_current_coverart);
		this.client.playback_playtime.connect(on_playback_playtime);

		events |= Gdk.EventMask.BUTTON_RELEASE_MASK;
		events |= Gdk.EventMask.BUTTON_PRESS_MASK;
		events |= Gdk.EventMask.KEY_PRESS_MASK;
		events |= Gdk.EventMask.KEY_RELEASE_MASK;

		can_focus = true;
	}

	private void on_playback_playtime(Client client, int id)
	{
	}

	private void on_playback_current_info(Xmms.Value val)
	{
		val.dict_entry_get_string("artist", out artist);
		val.dict_entry_get_string("album", out album);
		val.dict_entry_get_string("title", out title);
		queue_draw();
	}

	private void on_playback_current_coverart (Gdk.Pixbuf? pixbuf)
	{
		coverart = pixbuf;
		queue_draw();
	}

	public override bool key_press_event (Gdk.EventKey ev)
	{
		var parent = get_ancestor(typeof(Gtk.ApplicationWindow)) as Gtk.ApplicationWindow;

		if (ev.keyval == Gdk.Key.F11) {
			if (fullscreen)
				parent.unfullscreen();
			else
				parent.fullscreen();

			fullscreen = !fullscreen;
		} else {
			hide_now_playing();
			parent.unfullscreen();
		}

		return true;
	}

	public override bool button_release_event (Gdk.EventButton ev)
	{
		var parent = get_ancestor(typeof(Gtk.ApplicationWindow)) as Gtk.ApplicationWindow;
		parent.unfullscreen();

		hide_now_playing();

		return true;
	}

	private Pango.Layout get_pango_layout (Cairo.Context cr, double text_size, int text_width = -1)
	{
		var settings = Gtk.Settings.get_default();
		var desc = Pango.FontDescription.from_string(settings.gtk_font_name);
		desc.set_size((int)(text_size * 1000));

		var layout = Pango.cairo_create_layout(cr);
		layout.set_font_description(desc);

		if (text_width > 0) {
			layout.set_ellipsize(Pango.EllipsizeMode.END);
			layout.set_width(text_width * 1000);
		}

		return layout;
	}

	private void draw_metadata (Cairo.Context cr, int width, int height)
	{
		var text_size = width * 0.025;
		var text_top = height * 0.37;
		var text_left = width * 0.45;

		var layout = get_pango_layout (cr, text_size, (int)(width - text_left));

		if (title != null) {
			cr.set_source_rgb(1.0, 1.0, 1.0);
			cr.move_to(text_left, text_top);
			layout.set_text(title, -1);
			Pango.cairo_show_layout(cr, layout);
		}

		if (artist != null) {
			cr.set_source_rgb(0.7, 0.7, 0.7);
			cr.move_to(text_left, text_top + 1 * (text_size + text_size / 2.0));
			layout.set_text(artist, -1);
			Pango.cairo_show_layout(cr, layout);
		}

		if (album != null) {
			cr.set_source_rgb(0.7, 0.7, 0.7);
			cr.move_to(text_left, text_top + 2 * (text_size + text_size / 2.0));
			layout.set_text(album, -1);
			Pango.cairo_show_layout(cr, layout);
		}
	}

	private void draw_coverart (Cairo.Context cr, int width, int height)
	{
		var text_size = width * 0.025;
		var text_top = height * 0.37;

		var art_size = (int)(width * 0.3);
		var art_top = text_top + (text_size + text_size / 2.0) * 3 - art_size;
		var art_left = width * 0.12;

		var scaled = coverart.scale_simple(art_size, art_size, Gdk.InterpType.BILINEAR);
		Gdk.cairo_set_source_pixbuf(cr, scaled, art_left, art_top);
		cr.paint();

		var flipped = scaled.flip(false);
		Gdk.cairo_set_source_pixbuf(cr, flipped, art_left, art_top + art_size);
		cr.paint();

		var linear = new Cairo.Pattern.linear(0, 0, 0, art_top + art_size * 2 + 10);
		linear.add_color_stop_rgba(0.0, 0.0, 0.0, 0.0, 0.0);
		linear.add_color_stop_rgba(0.9, 0.0, 0.0, 0.0, 1.0);

		cr.rectangle(art_left - 5, art_top + art_size, art_size + 10, art_size + 10);
		cr.set_source(linear);
		cr.fill();
	}

	private void draw_hints (Cairo.Context cr, int height, int width)
	{
		var text_size = width * 0.010;

		var layout = get_pango_layout (cr, text_size);

		cr.move_to (text_size / 4, height - text_size * 2);
		cr.set_source_rgb(0.25, 0.25, 0.25);
		layout.set_text ("Press [ESC] to close...", -1);
		Pango.cairo_show_layout(cr, layout);
	}

	public override bool draw (Cairo.Context cr)
	{
		var width = get_allocated_width();
		var height = get_allocated_height();

		cr.set_source_rgb(0, 0, 0);
		cr.rectangle(0, 0, width, height);
		cr.fill();

		draw_metadata (cr, width, height);

		if (coverart != null)
			draw_coverart (cr, width, height);

		draw_hints (cr, width, height);


		return false;
	}
}
