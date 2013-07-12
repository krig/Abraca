/**
 * Abraca, an XMMS2 client.
 * Copyright (C) 2008-2013 Abraca Team
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

private class Abraca.FadingContainer : Gtk.Bin
{
	public double alpha { get; set; default = 1.0f; }

	public FadingContainer (Gtk.Widget child)
	{
		add(child);
	}

	private static void get_surface_size (Cairo.Surface surface, out int width, out int height)
	{
		double x1, y1, x2, y2;

		var cr = new Cairo.Context(surface);
		cr.clip_extents(out x1, out y1, out x2, out y2);

		width = (int)(x2 - x1);
		height = (int)(y2 - y1);
	}

	public override bool draw (Cairo.Context p)
	{
		int width, height;

		GLib.print ("drawing a: %.2f\n", alpha);

		var template = p.get_target();

		get_surface_size(template, out width, out height);

		var target = new Cairo.Surface.similar(template, template.get_content(), width, height);

		var cr = new Cairo.Context(target);

		base.draw(cr);

		p.set_source_surface(cr.get_target(), 0, 0);
		p.paint_with_alpha(alpha);

		return true;
	}
}

public class Abraca.FadingRow : Gtk.EventBox
{
	public Gtk.Grid hbox = new Gtk.Grid();

	private uint animation_event_source;
	private uint fadeout_event_source;

	private uint frame_count = 0;
	private uint current_frame = 0;

	private double current_opacity = 1.0f;
	private double target_opacity = 1.0f;
	private double start_opacity = 0.0f;

	public int fps { get; set; default = 20; }
	public int duration { get; set; default = 1250; }
	public bool enabled { get; set; }

	public double normal_opacity { get; set; default = 0.0f; }
	public double hover_opacity { get; set; default = 1.0f; }

	public FadingRow()
	{
		above_child = false;
		visible_window = true;

		events |= Gdk.EventMask.ENTER_NOTIFY_MASK;
		events |= Gdk.EventMask.LEAVE_NOTIFY_MASK;

		vexpand = false;

		notify["fps"].connect((s, p) => recalc_frame_count());
		notify["duration"].connect((s, p) => recalc_frame_count());

		recalc_frame_count();

		//hbox.margin = 5;

		hbox.vexpand = false;

		add(hbox);
	}

	private void recalc_frame_count()
	{
		frame_count = (uint)(fps * duration * 1.0 / 1000.0);
	}

	private bool on_update_opacity ()
	{
		if (target_opacity == hover_opacity) {
			current_opacity = Math.pow(current_frame++ * 1.0f / frame_count, 2) * frame_count;
		} else {
			current_opacity = 1.0f - Math.pow(-1.0 * (current_frame++ * 1.0f / frame_count), 2) * frame_count;
		}

		foreach (weak Gtk.Widget child in hbox.get_children()) {
			if (child is FadingContainer)
				(child as Abraca.FadingContainer).alpha = current_opacity;
		}

		queue_draw();

		if (current_opacity == target_opacity || current_opacity < 0.0f || current_opacity > 1.0f) {
			animation_event_source = 0;
			return false;
		}

		return true;
	}

	private void set_target_opacity(double opacity)
	{
		if (opacity != target_opacity) {
			target_opacity = opacity;
			if (animation_event_source == 0) {
				current_frame = 0;
				animation_event_source = GLib.Timeout.add ((uint)(fps * duration / 1000.0f), on_update_opacity);
			}
		}
	}

	public override bool enter_notify_event (Gdk.EventCrossing ev)
	{
		set_target_opacity(hover_opacity);
		if (fadeout_event_source != 0) {
			GLib.Source.remove(fadeout_event_source);
		}
		return true;
	}

	private bool on_fadeout ()
	{
		set_target_opacity(normal_opacity);
		fadeout_event_source = 0;
		return false;
	}

	public override bool leave_notify_event (Gdk.EventCrossing ev)
	{
		/* TODO: lägg till en delay här så vi inte fadar ner direkt */
		if (ev.x <= 0 || ev.y <= 0 || ev.x >= hbox.get_window().get_width() || ev.y >= hbox.get_window().get_height()) {
			//GLib.print("evX: %.2f, evY: %.2f, w: %d, h: %d\n", ev.x, ev.y, hbox.get_window().get_width(), hbox.get_window().get_height());
			fadeout_event_source = GLib.Timeout.add(500, on_fadeout);
		} else {
			GLib.print("NOT LEAVING: evX: %.2f, evY: %.2f, w: %d, h: %d\n", ev.x, ev.y, hbox.get_window().get_width(), hbox.get_window().get_height());
		}
		return true;
	}
}
