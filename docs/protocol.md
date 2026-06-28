# smART Sketcher 2.0 — BLE Protocol Specification

Reverse-engineered protocol for the smART Sketcher Projector 2.0.

## BLE Characteristic

All interaction with the device (commands, image data, and notifications) uses a single characteristic:

```
0000FFE3-0000-1000-8000-00805F9B34FB
```

The characteristic supports write-without-response on the hardware seen so far. Detect at runtime via `CBCharacteristicProperties` rather than hardcoding the write type.

---

## Command Format

All commands are 8 bytes:

```
| Bytes | Description                |
|-------|----------------------------|
|  0–1  | Command ID (little-endian) |
|  2–7  | Command parameters         |
```

Parameters not listed for a command are set to `0x00`.

### Command IDs

| ID     | Decimal | Name                  | Notes                          |
|--------|---------|-----------------------|--------------------------------|
| `0x01` | 1       | Send Image            | See image transfer section     |
| `0x02` | 2       | Exercise              | `cmd[6..7]` = exercise ID (LE) |
| `0x05` | 5       | Next Step             |                                |
| `0x06` | 6       | Previous Step         |                                |
| `0x07` | 7       | Replay Steps          |                                |
| `0x08` | 8       | Get SD ID             |                                |
| `0x09` | 9       | Get System Version    |                                |
| `0x0A` | 10      | Animation Speed Toggle|                                |
| `0x0B` | 11      | Get Animation Speed   |                                |
| `0x0C` | 12      | Get "Where Am I"      | Responds `OK_12_00_00_00_00_00`|
| `0x0F` | 15      | Update Brightness     | `cmd[6..7]` = brightness (LE)  |
| `0x10` | 16      | Get Brightness        |                                |
| `0x15` | 21      | Reset SD Card         | **Not tested — clone SD first**|
| `0x17` | 23      | Send Partial Image    | `cmd[2..3]` = `0x0002`, `cmd[4..7]` = x, y, w, h |
| `0x20` | 32      | Get LCD Version       |                                |

---

## Responses

Responses arrive as GATT notifications on the same characteristic, encoded as ASCII.

Most commands reply with `OK_nn` on success, where `nn` is the decimal command ID.

---

## Image Transfer

### Format

Images must be **160 × 128 pixels**, **RGB565** encoding — 2 bytes per pixel:

```
Byte 0: RRRRRGGG
Byte 1: GGGBBBBB
```

Pixel encoding:
```
byte0 = (r & 0xF8) | (g >> 5)
byte1 = ((g & 0x1C) << 3) | (b >> 3)
```

### Transfer Sequence

1. Send the **Send Image** command:
   ```
   [0x01, 0x00, 0x00, 0x00, 0x50, 0x00, 0x01, 0x00]
   ```

   > `cmd[4]` has device-side logic: `i >= 160 ? (byte) -96 : (byte) 80`. The value `0x50` (80) works in practice.
   > `cmd[6]` controls image compression mode. `0x01` works reliably; other values depend on chipset and app settings.

2. Send each of the **128 horizontal lines** as a raw RGB565 byte sequence (160 pixels × 2 bytes = **320 bytes per line**).

3. After each line the device sends a notification:
   ```
   [0x4F, 0x4B]  →  'OK' in ASCII
   ```
   Wait for this before sending the next line.

### Partial Image

Send partial updates with the Send Partial Image command:

```
[0x17, 0x00, 0x02, 0x00, x, y, w, h]
```

`x`, `y` — destination origin; `w`, `h` — region dimensions. The `0x0002` at bytes 2–3 is hardcoded; its meaning is undetermined.
