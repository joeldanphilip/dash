# Register map

All addresses are byte addresses, 32-bit data, little-endian. Unmapped addresses
return `SLVERR`. Writes honor `WSTRB`; security-sensitive command registers act
only when all four bytes are strobed. C reads/writes to E-only locations return
`SLVERR` and have no protected side effect.

| Offset | Name | C | E | Description |
|---:|---|---|---|---|
| 0x00 | STATUS | R | R | bit0 busy, bit1 done, bit2 C-access, bit3 fault, bit4 input-error, bits7:5 owner, bits9:8 mode |
| 0x04 | REQUEST | W | R/W | C bit0=request/release; E bit0=grant C, bit1=grant E |
| 0x08 | CONFIG | R/W policy | R/W | dummy config; C may write only in C-owned UNTRUSTED mode |
| 0x0c | INPUT | W | W | stream word; bit31 is `last`; accepted only when authorized |
| 0x10 | RESULT | R policy | R | result word; C requires `c_result_ok` |
| 0x14 | CONTROL | W | W | bit0=start, bit1=finish, bit2=abort; only E bit3=clear result |
| 0x18 | LENGTH | R | R/W | input length limit in bytes; E-only write |
| 0x1c | POLICY | R | R/W | E: bits1:0 mode, bit2 C result visibility, bit3 graceful revoke |
| 0x20 | TIMEOUT | R | R/W | clear/revocation timeout in cycles |
| 0x24 | ERROR | R | R/W | sticky error/fault; E write bit0 clears recoverable error |
| 0x28 | RECOVER | - | W | E full-word write bit0 requests fault recovery |

`CONFIG` writes are atomic 32-bit values in the reference implementation. A
partial write is rejected, avoiding partially changed security-relevant config.
`INPUT` writes use the low `DATA_W/8` bytes and bit31 as last.
