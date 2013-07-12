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

public class Abraca.Resolver : GLib.Object {
	public delegate void ResolvedFunc(Xmms.Value value);

	private static Xmms.Value EMPTY_LIST = new Xmms.Value.from_list();
	private static uint LATENCY_MS = 5;

	private class Listener
	{
		public unowned ResolvedFunc func;
		public Xmms.Value attributes;

		public Listener(ResolvedFunc func)
		{
			this.func = func;
		}
	}

	private Gee.List<Listener> listeners = new Gee.ArrayList<Listener>();

	private Gee.List<int> pending = new Gee.ArrayList<uint>();
	private Gee.Map<int,Xmms.Collection> pending_mids = new Gee.HashMap<uint,Xmms.Collection>();

	private uint timeout_handle = 0;
	private bool in_flight = false;
	private int in_flight_token = -1;
	private int64 target = -1;

	private Client client;

	public Resolver(Client client)
	{
		this.client = client;
	}

	public int register(ResolvedFunc func)
	{
		listeners.add(new Listener(func));
		return listeners.size - 1;
	}

	public void set_attributes_va(int token, ...)
		requires(0 <= token < listeners.size)
	{
		var value = new Xmms.Value.from_list();
		value.list_append_string("id");

		var l = va_list();
		while (true) {
			string? attribute = l.arg();
			if (attribute == null)
				break;
			value.list_append_string(attribute);
		}

		listeners[token].attributes = value;
	}

	public void set_attributes(int token, string[] attrs)
		requires(0 <= token < listeners.size)
	{
		var value = new Xmms.Value.from_list();
		value.list_append_string("id");

		foreach (var attribute in attrs)
			value.list_append_string(attribute);

		listeners[token].attributes = value;
	}

	private void arm_timer()
		requires(!pending.is_empty)
		requires(!in_flight)
	{
		target = GLib.get_monotonic_time() + LATENCY_MS;
		if (timeout_handle == 0) {
			timeout_handle = GLib.Timeout.add(LATENCY_MS, on_timeout);
		}
	}

	public void resolve(int token, int mid)
		requires(0 <= token < listeners.size)
	{
		Xmms.Collection? list = pending_mids[token];
		if (list == null) {
			list = new Xmms.Collection(Xmms.CollectionType.IDLIST);
			pending_mids.set(token, list);
			pending.add(token);
		}
		list.idlist_append(mid);

		if (!in_flight)
			arm_timer();
	}

	private bool on_timeout()
	{
		Xmms.Collection list;

		if (in_flight || GLib.get_monotonic_time() < target)
			return true;

		var token = pending.remove_at(0);
		pending_mids.unset(token, out list);

		var listener = listeners[token];

		client.xmms.coll_query_infos(list, EMPTY_LIST, 0, 0, listener.attributes, EMPTY_LIST).notifier_set(
			on_coll_query_infos
		);

		in_flight = true;
		in_flight_token = token;

		timeout_handle = 0;

		return false;
	}

	private bool on_coll_query_infos(Xmms.Value value)
		requires(0 <= in_flight_token < listeners.size)
	{
		var listener = listeners[in_flight_token];

		in_flight = false;

		if (!pending.is_empty)
			arm_timer();

		/* dispatch callback later in mainloop so the next
		 * query can be dispatched while the result is being
		 * processed
		 */
		GLib.Idle.add(() => {
			listener.func(value);
			return false;
		});

		return true;
	}
}
