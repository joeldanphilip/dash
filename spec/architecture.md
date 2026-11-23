# DASH common architecture

## Clock and reset

One rising-edge `clk` is shared by both AXI-Lite slaves and the adapter. `rst_n`
is the trusted DASH reset and is active low. A C-port reset, if needed by an
integration wrapper, may only reset that frontend's local transport state; it
must request safe session termination and must not reset policy or E state.

Reset is fail closed: mode is `TRUSTED`, owner is `IDLE`, C access is disabled,
results are invalid, and the adapter is cleared before any new ownership grant.

## Ownership and operation

Ownership is `IDLE`, `C_ACTIVE`, `E_ACTIVE`, or `E_C_FEED`. `QUIESCE` and `CLEAR`
are internal transition phases. E requests and revocation have priority over a
new C request. Ownership cannot change while an operation is active. A transfer
blocks new work, completes or aborts the current bounded operation, invalidates
results, flushes controller buffers, requests adapter clear, waits for
`clear_done`, resets session metadata, then grants the next owner.

Modes are `TRUSTED` (E only), `UNTRUSTED` (C may operate under policy), and
`CONTROLLED_FEED` (E configures and authorizes; C supplies bounded input).

## Input/output security

Input is accepted only when the current owner/mode authorizes it, the operation
is active, and the adapter handshake succeeds. The length counter increments on
adapter-facing consumption, never merely on an AXI write. `input_limit` is
checked before acceptance; an excess word is rejected and sets an error.
Results are tagged by the current session and are invalidated on abort, clear,
revocation, and ownership transfer. C sees results only when `c_result_ok` is
enabled by E policy.

## Fault policy

Clear timeout, adapter error, input-length violation, and illegal protected
commands set a sticky fault/error bit. A clear timeout enters `FAULT`, disables
C, and blocks all new operations until E writes `RECOVER`. Recovery requests a
fresh adapter clear; ownership is not granted until the clear handshake succeeds.
