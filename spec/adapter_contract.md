# Generic accelerator adapter contract

The adapter has `start`, `abort`, `clear`, `busy`, `done`, `clear_done`, `error`,
configuration valid/ready, input valid/ready/strb/last, and output valid/ready/last.
All handshakes are sampled on the common rising edge. A configuration is accepted
only on `config_valid && config_ready`; input is consumed only on
`data_valid && data_ready`; output is retired only on `out_valid && out_ready`.

`start` is a one-cycle request after configuration is accepted and while the
adapter is idle. `abort` terminates the current operation and suppresses future
outputs. `clear` is a level/request pulse that eventually produces `clear_done`.
`clear_done` guarantees all operation state, pending output, and input buffering
are cleared and no output from the old session can appear afterward. An adapter
must not accept a new start until the old operation is retired or aborted and
cleared.

DASH guarantees authorization, bounded input, output visibility, session tagging,
and clear-before-transfer. The adapter guarantees handshake correctness,
termination, and complete isolation after `clear_done`; those guarantees cannot
be inferred by DASH from reset alone.
