// Synthetic vectors for the AGPL-3.0 HE-Music Go executor.
// Source hashes and regeneration instructions: lib/core/audio/decrypt/README.md.
package main

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"io"
	"os"
	t "vectors/transform"
)

func box(k string, body ...[]byte) []byte {
	b := bytes.Join(body, nil)
	v := make([]byte, len(b)+8)
	binary.BigEndian.PutUint32(v, uint32(len(v)))
	copy(v[4:], k)
	copy(v[8:], b)
	return v
}
func main() {
	rows := []map[string]any{}
	keys := []t.Parameters{{Version: 1, Kind: 1, Key: []byte{1, 7, 255}}, {Version: 1, Kind: 2, Key: []byte{1, 9, 23, 87, 255, 32, 19}, Period: 17, Bias: 3}, {Version: 1, Kind: 3, Key: []byte{1, 9, 23, 87, 255, 32, 19}, Box: []byte{6, 1, 5, 2, 4, 0, 3}, Hash: 0xfedcba98, First: 5, Segment: 17}}
	for _, p := range keys {
		enc, _ := t.Encode(p)
		for _, off := range []int64{0, 4, 5, 16, 17, 18, 65530, 1<<40 - 257} {
			src := make([]byte, 257)
			for i := range src {
				src[i] = byte(i*13 + 7)
			}
			r, _ := t.NewReader(bytes.NewReader(src), p, off)
			out, e := io.ReadAll(r)
			if e != nil {
				panic(e)
			}
			rows = append(rows, map[string]any{"parameters": enc, "offset": off, "input": hex.EncodeToString(src), "output": hex.EncodeToString(out)})
		}
	}
	for _, ivSize := range []int{8, 16} {
		for _, subs := range []bool{false, true} {
			for _, format := range []string{"mp4a", "alac", "fLaC"} {
				key := []byte("0123456789abcdef")
				iv := make([]byte, 16)
				for i := range ivSize {
					iv[i] = byte(i + 1)
				}
				plain := []byte("clear encrypted audio payload spanning multiple AES blocks!")
				encrypted := bytes.Clone(plain)
				block, _ := aes.NewCipher(key)
				stream := cipher.NewCTR(block, iv)
				senc := make([]byte, 8)
				binary.BigEndian.PutUint32(senc[4:], 1)
				senc = append(senc, iv[:ivSize]...)
				if subs {
					senc[3] = 2
					senc = append(senc, 0, 2, 0, 6, 0, 0, 0, 9, 0, 3, 0, 0, 0, 19)
					stream.XORKeyStream(encrypted[6:15], plain[6:15])
					stream.XORKeyStream(encrypted[18:37], plain[18:37])
				} else {
					stream.XORKeyStream(encrypted, plain)
				}
				sz := make([]byte, 12)
				binary.BigEndian.PutUint32(sz[4:], uint32(len(plain)))
				binary.BigEndian.PutUint32(sz[8:], 1)
				te := make([]byte, 8)
				te[7] = byte(ivSize)
				stsd := box("stsd", make([]byte, 8), box("enca", make([]byte, 28), box("sinf", box("frma", []byte(format)), box("schi", box("tenc", te)))))
				src := bytes.Join([][]byte{box("ftyp", []byte("M4A ")), box("moov", box("trak", box("mdia", box("minf", box("stbl", stsd, box("stsz", sz), box("senc", senc)))))), box("mdat", encrypted)}, nil)
				p := t.Parameters{Version: 1, Kind: 4, Key: key}
				enc, _ := t.Encode(p)
				out, e := t.DecryptSamples(src, p, false)
				if e != nil {
					panic(e)
				}
				rows = append(rows, map[string]any{"parameters": enc, "ivSize": ivSize, "subsamples": subs, "format": format, "input": hex.EncodeToString(src), "output": hex.EncodeToString(out)})
			}
		}
	}
	json.NewEncoder(os.Stdout).Encode(rows)
}
