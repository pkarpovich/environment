mod keycodes;
mod sse;

use std::ffi::c_void;
use std::net::TcpListener;
use std::os::raw::c_ulong;
use std::process::ExitCode;
use std::sync::mpsc::{Sender, channel};
use std::thread;

use core_foundation::runloop::{CFRunLoop, kCFRunLoopCommonModes};
use core_graphics::event::{
    CGEvent, CGEventFlags, CGEventTap, CGEventTapLocation, CGEventTapOptions, CGEventTapPlacement,
    CGEventType, CallbackResult, EventField,
};
use foreign_types::ForeignType;

const ADDR: &str = "0.0.0.0:50501";

const KEY_DOWN: u32 = CGEventType::KeyDown as u32;
const KEY_UP: u32 = CGEventType::KeyUp as u32;
const TAP_DISABLED_BY_TIMEOUT: u32 = CGEventType::TapDisabledByTimeout as u32;
const TAP_DISABLED_BY_USER_INPUT: u32 = CGEventType::TapDisabledByUserInput as u32;

unsafe extern "C" {
    fn CGEventKeyboardGetUnicodeString(
        event: *const c_void,
        max_length: c_ulong,
        actual_length: *mut c_ulong,
        unicode_string: *mut u16,
    );
    fn CGPreflightListenEventAccess() -> bool;
    fn CGRequestListenEventAccess() -> bool;
}

enum Edge {
    Down,
    Up,
}

impl Edge {
    fn as_str(&self) -> &'static str {
        match self {
            Edge::Down => "down",
            Edge::Up => "up",
        }
    }
}

fn main() -> ExitCode {
    if !unsafe { CGPreflightListenEventAccess() } {
        eprintln!("keytap: no Input Monitoring access, opening the system prompt");
        unsafe { CGRequestListenEventAccess() };
        eprintln!(
            "keytap: System Settings -> Privacy & Security -> Input Monitoring, enable keytap and run again"
        );
        return ExitCode::FAILURE;
    }

    let listener = match TcpListener::bind(ADDR) {
        Ok(listener) => listener,
        Err(err) => {
            eprintln!("keytap: cannot bind {ADDR}: {err}");
            return ExitCode::FAILURE;
        }
    };

    let broadcast = sse::Broadcast::new();
    broadcast.serve(listener);

    let (sender, receiver) = channel::<String>();
    thread::spawn(move || {
        for payload in receiver {
            broadcast.send(&payload);
        }
    });

    println!("keytap: listening to the keyboard, event stream on http://{ADDR}");

    let Ok(tap) = build_tap(sender) else {
        eprintln!("keytap: could not create the event tap");
        return ExitCode::FAILURE;
    };

    let Ok(source) = tap.mach_port().create_runloop_source(0) else {
        eprintln!("keytap: could not create the run loop source");
        return ExitCode::FAILURE;
    };

    let run_loop = CFRunLoop::get_current();
    unsafe { run_loop.add_source(&source, kCFRunLoopCommonModes) };
    tap.enable();
    CFRunLoop::run_current();
    ExitCode::SUCCESS
}

fn build_tap<'a>(sender: Sender<String>) -> Result<CGEventTap<'a>, ()> {
    CGEventTap::new(
        CGEventTapLocation::Session,
        CGEventTapPlacement::HeadInsertEventTap,
        CGEventTapOptions::ListenOnly,
        vec![CGEventType::KeyDown, CGEventType::KeyUp],
        move |_proxy, event_type, event| {
            let edge = match event_type as u32 {
                KEY_DOWN => Edge::Down,
                KEY_UP => Edge::Up,
                TAP_DISABLED_BY_TIMEOUT | TAP_DISABLED_BY_USER_INPUT => {
                    eprintln!("keytap: the system disabled the tap, restart keytap");
                    return CallbackResult::Keep;
                }
                _ => return CallbackResult::Keep,
            };

            let Some(payload) = encode(event, edge) else {
                return CallbackResult::Keep;
            };
            let Ok(()) = sender.send(payload) else {
                return CallbackResult::Keep;
            };
            CallbackResult::Keep
        },
    )
}

fn encode(event: &CGEvent, edge: Edge) -> Option<String> {
    let virtual_key = event.get_integer_value_field(EventField::KEYBOARD_EVENT_KEYCODE);
    let code = keycodes::dom_code(virtual_key)?;

    let flags = event.get_flags();
    let shift = flags.contains(CGEventFlags::CGEventFlagShift);
    let alt = flags.contains(CGEventFlags::CGEventFlagAlternate);

    let mut payload = String::from("{\"code\":\"");
    payload.push_str(code);
    payload.push_str("\",\"edge\":\"");
    payload.push_str(edge.as_str());
    payload.push_str("\",\"shift\":");
    payload.push_str(if shift { "true" } else { "false" });
    payload.push_str(",\"alt\":");
    payload.push_str(if alt { "true" } else { "false" });
    match typed_string(event) {
        Some(typed) => {
            payload.push_str(",\"char\":\"");
            payload.push_str(&escape(&typed));
            payload.push('"');
        }
        None => payload.push_str(",\"char\":null"),
    }
    payload.push('}');
    Some(payload)
}

fn typed_string(event: &CGEvent) -> Option<String> {
    let mut buffer = [0u16; 8];
    let mut length: c_ulong = 0;
    unsafe {
        CGEventKeyboardGetUnicodeString(
            event.as_ptr() as *const c_void,
            buffer.len() as c_ulong,
            &mut length,
            buffer.as_mut_ptr(),
        );
    }
    if length == 0 {
        return None;
    }

    let typed = String::from_utf16_lossy(&buffer[..length as usize]);
    let mut printable = false;
    for ch in typed.chars() {
        if !ch.is_control() {
            printable = true;
        }
    }
    if !printable {
        return None;
    }
    Some(typed)
}

fn escape(input: &str) -> String {
    let mut out = String::with_capacity(input.len());
    for ch in input.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            ch if (ch as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", ch as u32)),
            ch => out.push(ch),
        }
    }
    out
}
