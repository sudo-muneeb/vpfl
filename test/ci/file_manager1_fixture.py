#!/usr/bin/env python3
"""Minimal FileManager1 service for the isolated native bridge test."""

from gi.repository import Gio, GLib


INTERFACE = Gio.DBusNodeInfo.new_for_xml(
    """<node><interface name="org.freedesktop.FileManager1">
      <method name="ShowFolders">
        <arg type="as" direction="in"/>
        <arg type="s" direction="in"/>
      </method>
    </interface></node>"""
).interfaces[0]


def handle_call(connection, sender, object_path, interface_name, method_name,
                parameters, invocation):
    uris, _startup_id = parameters.unpack()
    if method_name != "ShowFolders" or len(uris) != 1:
        invocation.return_dbus_error("org.freedesktop.DBus.Error.InvalidArgs",
                                     "Expected one folder URI")
        return
    print(f"URI {uris[0]}", flush=True)
    invocation.return_value(GLib.Variant("()", ()))


def bus_acquired(connection, _name):
    connection.register_object(
        "/org/freedesktop/FileManager1", INTERFACE, handle_call, None, None
    )


def name_acquired(_connection, _name):
    print("READY", flush=True)


Gio.bus_own_name(
    Gio.BusType.SESSION,
    "org.freedesktop.FileManager1",
    Gio.BusNameOwnerFlags.NONE,
    bus_acquired,
    name_acquired,
    lambda _connection, _name: print("NAME_LOST", flush=True),
)
GLib.MainLoop().run()
