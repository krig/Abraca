/*
 * vim:noexpandtab:sw=4:sts=0:ts=4:syn=cs
 */
using GLib;

namespace Abraca {
	enum PlaylistColumn {
		ID = 0,
		CoverArt,
		Info,
		Total
	}

	enum PlaylistDrop {
		POS = 0,
		MID,
		PATH,
		URL
	}

	public class PlaylistTree : Gtk.TreeView {
		/** current playback status */
		private int _status;
		/** current playlist displayed */
		private string _playlist;
		/** allowed drag-n-drop variants */
		private Gtk.TargetEntry[] _target_entries;

		construct {
			Client c = Client.instance();

			enable_search = true;
			search_column = 1;
			headers_visible = false;
			show_expanders = false;
			rules_hint = true;
			fixed_height_mode = true;

			weak Gtk.TreeSelection sel = get_selection();
			sel.set_mode(Gtk.SelectionMode.MULTIPLE);

			create_columns ();

			model = new Gtk.ListStore(
				PlaylistColumn.Total,
				typeof(int), typeof(string), typeof(string)
			);
			row_activated += on_row_activated;

			c.playlist_loaded += on_playlist_loaded;

			c.playlist_add += on_playlist_add;
			c.playlist_move += on_playlist_move;
			c.playlist_insert += on_playlist_insert;
			c.playlist_remove += on_playlist_remove;

			c.playback_status += on_playback_status;

			create_dragndrop();

			show_all();

		}

		/**
		 * Create metadata and coverart columns.
		 */
		private void create_columns() {
 			insert_column_with_attributes(
				-1, null, new Gtk.CellRendererPixbuf(),
				"stock-id", PlaylistColumn.CoverArt, null
			);

 			insert_column_with_attributes(
				-1, null, new Gtk.CellRendererText(),
				"markup", PlaylistColumn.Info, null
			);
		}

		/**
		 * Setup dragndrop for the playlist.
		 */
		private void create_dragndrop() {
			_target_entries = new Gtk.TargetEntry[4];

			_target_entries[0].target = "application/x-xmms2poslist";
			_target_entries[0].flags = 0;
			_target_entries[0].info = (uint) PlaylistDrop.POS;

			_target_entries[1].target = "application/x-xmms2mlibid";
			_target_entries[1].flags = 0;
			_target_entries[1].info = (uint) PlaylistDrop.MID;

			_target_entries[2].target = "text/uri-list";
			_target_entries[2].flags = 0;
			_target_entries[2].info = (uint) PlaylistDrop.PATH;

			_target_entries[3].target = "_NETSCAPE_URL";
			_target_entries[3].flags = 0;
			_target_entries[3].info = (uint) PlaylistDrop.URL;


			enable_model_drag_dest(_target_entries, _target_entries.length,
			                       Gdk.DragAction.MOVE);

			enable_model_drag_source(Gdk.ModifierType.BUTTON1_MASK,
			                         _target_entries, _target_entries.length,
			                         Gdk.DragAction.MOVE);

			drag_data_received += on_drag_data_receive;
		}

		/**
		 * Take care of the various types of drops.
		 */
		[InstanceLast]
		private void on_drag_data_receive(Gtk.Widget w, Gdk.DragContext ctx, int x, int y,
		                              Gtk.SelectionData sel, uint info,
		                              uint time) {

			Gtk.TargetList target_list;
			bool success = false;

			if (info == (uint) PlaylistDrop.POS) {
				GLib.stdout.printf("Drop from playlist not implemented.\n");
			} else if (info == (uint) PlaylistDrop.MID) {
				success = on_drop_medialib_id(sel, x, y);
			} else if (info == (uint) PlaylistDrop.PATH) {
				GLib.stdout.printf("Drop from filesystem not implemented\n");
			} else if (info == (uint) PlaylistDrop.URL) {
				GLib.stdout.printf("Drop from intarweb not implemented\n");
			} else {
				GLib.stdout.printf("Nogle gange går der kuk i maskineriet\n");
			}

			/* success, but do not remove from source */
			Gtk.drag_finish(ctx, success, false, time);
		}

		/**
		 * Handle dropping of medialib ids.
		 * TODO: Should perform an xmms.playlist_add when drop is at end.
		 */
		private bool on_drop_medialib_id(Gtk.SelectionData sel, int x, int y) {
			Gtk.TreeViewDropPosition align;
			Gtk.TreePath path;

			Client c = Client.instance();

			weak uint[] ids = (uint[]) sel.data;

			if (get_dest_row_at_pos(x, y, out path, out align)) {
				int pos = path.get_indices()[0];

				for (int i; i < sel.length / 32; i++) {
					c.xmms.playlist_insert_id(_playlist, pos, ids[i]);
				}
			}


			return true;
		}

		/**
		 * Insert a row when a new entry has been inserted in the playlist.
		 * TODO: Insert mid here and schedule a resolve operation.
		 */
		private void on_playlist_insert(Client c, string playlist, uint mid, int pos) {
			Gtk.ListStore store = (Gtk.ListStore) model;
			Gtk.TreePath path;
			Gtk.TreeIter iter;

			if (playlist != _playlist) {
				return;
			}

			path = new Gtk.TreePath.from_indices(pos, -1);
			if (model.get_iter(out iter, path)) {
				Gtk.TreeIter added;

				store.insert_before (out added, ref iter);

				/* fixme */
			}
		}

		/**
		 * Removes the row when an entry has been removed from the playlist.
		 */
		private void on_playlist_remove(Client c, string playlist, int pos) {
			Gtk.ListStore store = (Gtk.ListStore) model;
			Gtk.TreePath path;
			Gtk.TreeIter iter;

			if (playlist != _playlist) {
				return;
			}

			path = new Gtk.TreePath.from_indices(pos, -1);
			if (model.get_iter(out iter, path)) {
				store.remove(ref iter);
			}
		}

		/**
		 * TODO: Move row x to pos y.
		 */
		private void on_playlist_move(Client c, string playlist, int pos, int npos) {
			GLib.stdout.printf("Move Not Implemented!\n");
		}


		/**
		 * When clicking a row, perform a jump to that song and start
		 * playback if not already playing.
		 */
		[InstanceLast]
		private void on_row_activated(Gtk.TreeView tree, Gtk.TreePath path,
		                              Gtk.TreeViewColumn column) {
			Client c = Client.instance();
			int pos = path.get_indices()[0];

			c.xmms.playlist_set_next(pos);
			c.xmms.playback_tickle();

			if (_status != Xmms.PlaybackStatus.PLAY) {
				c.xmms.playback_start();
			}
		}

		/**
		 * Keep track of status so we know what to do when an item has been clicked.
		 */
		private void on_playback_status(Client c, int status) {
			_status = status;
		}

		/**
		 * Called when xmms2 has loaded a new playlist, simply requests
		 * the mids of that playlist.
		 */
		private void on_playlist_loaded(Client c, string name) {
			_playlist = name;

			c.xmms.playlist_list_entries(name).notifier_set(
				on_playlist_list_entries, this
			);
		}

		/**
		 * TODO: This should simply append a mid to the playlist and
		 *       schedule resolve operation.
		 */
		private void on_playlist_add(Client c, string playlist, uint mid) {
			c.xmms.medialib_get_info(mid).notifier_set(
				on_medialib_get_info, this
			);
		}

		/**
		 * Refresh the whole playlist.
		 * TODO: This should only insert mids, and schedule resolve operation.
		 */
		[InstanceLast]
		private void on_playlist_list_entries(Xmms.Result res) {
			Client c = Client.instance();
			Gtk.ListStore store = (Gtk.ListStore) model;

			store.clear();

			for (res.list_first(); res.list_valid(); res.list_next()) {
				uint id;

				if (!res.get_uint(out id))
					continue;

				c.xmms.medialib_get_info(id).notifier_set(
					on_medialib_get_info, this
				);
			}
		}

		/**
		 * TODO: Should check the future hash[mid] = [row1, row2, row3] and
		 *       update the rows accordingly.
		 */
		[InstanceLast]
		private void on_medialib_get_info(Xmms.Result res) {
			Gtk.ListStore store = (Gtk.ListStore) model;
			Gtk.TreeIter iter;
			weak string artist, title, album;
			string info;
			uint id;
			int duration, dur_min, dur_sec, pos;

			res.get_dict_entry_int("id", out id);
			res.get_dict_entry_int("duration", out duration);

			if (!res.get_dict_entry_string("artist", out artist))
				artist = "Unknown";

			if (!res.get_dict_entry_string("title", out title))
				title = "Unknown";

			if (!res.get_dict_entry_string("album", out album))
				album = "Unknown";

			dur_min = duration / 60000;
			dur_sec = (duration % 60000) / 1000;

			info = Markup.printf_escaped(
				"<b>%s</b> - <small>%d:%02d</small>\n" +
				"<small>by</small> %s <small>from</small> %s",
				title, dur_min, dur_sec, artist, album
			);

			pos = store.iter_n_children(null);

			store.insert_with_values(
				ref iter, pos,
				PlaylistColumn.ID, id,
				PlaylistColumn.CoverArt, null,
				PlaylistColumn.Info, info
			);
		}
	}
}
