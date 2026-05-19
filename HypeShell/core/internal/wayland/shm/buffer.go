package shm

import (
	"fmt"

	"golang.org/x/sys/unix"
)

type PixelFormat uint32

const (
	FormatARGB8888 PixelFormat = 0
	FormatXRGB8888 PixelFormat = 1
	FormatABGR8888 PixelFormat = 0x34324241
	FormatXBGR8888 PixelFormat = 0x34324258
	FormatRGB888   PixelFormat = 0x34324752
	FormatBGR888   PixelFormat = 0x34324742
)

func (f PixelFormat) BytesPerPixel() int {
	switch f {
	case FormatRGB888, FormatBGR888:
		return 3
	default:
		return 4
	}
}

func (f PixelFormat) Is24Bit() bool {
	return f == FormatRGB888 || f == FormatBGR888
}

type Buffer struct {
	fd     int
	data   []byte
	size   int
	Width  int
	Height int
	Stride int
	Format PixelFormat
}

func CreateBuffer(width, height, stride int) (*Buffer, error) {
	size := stride * height

	fd, err := unix.MemfdCreate("hype-shm", 0)
	if err != nil {
		return nil, fmt.Errorf("memfd_create: %w", err)
	}

	if err := unix.Ftruncate(fd, int64(size)); err != nil {
		unix.Close(fd)
		return nil, fmt.Errorf("ftruncate: %w", err)
	}

	data, err := unix.Mmap(fd, 0, size, unix.PROT_READ|unix.PROT_WRITE, unix.MAP_SHARED)
	if err != nil {
		unix.Close(fd)
		return nil, fmt.Errorf("mmap: %w", err)
	}

	return &Buffer{
		fd:     fd,
		data:   data,
		size:   size,
		Width:  width,
		Height: height,
		Stride: stride,
	}, nil
}

func (b *Buffer) Fd() int      { return b.fd }
func (b *Buffer) Size() int    { return b.size }
func (b *Buffer) Data() []byte { return b.data }

func (b *Buffer) Close() error {
	var firstErr error

	if b.data != nil {
		if err := unix.Munmap(b.data); err != nil && firstErr == nil {
			firstErr = fmt.Errorf("munmap: %w", err)
		}
		b.data = nil
	}

	if b.fd >= 0 {
		if err := unix.Close(b.fd); err != nil && firstErr == nil {
			firstErr = fmt.Errorf("close: %w", err)
		}
		b.fd = -1
	}

	return firstErr
}

func (b *Buffer) ConvertTo32Bit(srcFormat PixelFormat) (*Buffer, PixelFormat, error) {
	if !srcFormat.Is24Bit() {
		return b, srcFormat, nil
	}

	dstFormat := FormatXRGB8888
	dstStride := b.Width * 4

	dst, err := CreateBuffer(b.Width, b.Height, dstStride)
	if err != nil {
		return nil, srcFormat, err
	}
	dst.Format = dstFormat

	srcData := b.data
	dstData := dst.data

	// DRM format names are counterintuitive on little-endian:
	// RGB888 memory layout: B, G, R (name is logical order, not memory)
	// BGR888 memory layout: R, G, B
	isBGRMemory := srcFormat == FormatRGB888

	for y := 0; y < b.Height; y++ {
		srcRow := y * b.Stride
		dstRow := y * dstStride
		for x := 0; x < b.Width; x++ {
			si := srcRow + x*3
			di := dstRow + x*4
			if isBGRMemory {
				// RGB888: src memory is B,G,R -> dst XRGB8888 memory B,G,R,X
				dstData[di+0] = srcData[si+0]
				dstData[di+1] = srcData[si+1]
				dstData[di+2] = srcData[si+2]
			} else {
				// BGR888: src memory is R,G,B -> dst XRGB8888 memory B,G,R,X
				dstData[di+0] = srcData[si+2]
				dstData[di+1] = srcData[si+1]
				dstData[di+2] = srcData[si+0]
			}
			dstData[di+3] = 0xFF
		}
	}

	return dst, dstFormat, nil
}

func (b *Buffer) GetPixelRGBA(x, y int) (r, g, b2, a uint8) {
	if x < 0 || x >= b.Width || y < 0 || y >= b.Height {
		return
	}

	off := y*b.Stride + x*4
	if off+3 >= len(b.data) {
		return
	}

	switch b.Format {
	case FormatXBGR8888, FormatABGR8888:
		return b.data[off], b.data[off+1], b.data[off+2], 0xFF
	default:
		return b.data[off+2], b.data[off+1], b.data[off], 0xFF
	}
}

func (b *Buffer) GetPixelBGRA(x, y int) (b2, g, r, a uint8) {
	if x < 0 || x >= b.Width || y < 0 || y >= b.Height {
		return
	}

	off := y*b.Stride + x*4
	if off+3 >= len(b.data) {
		return
	}

	return b.data[off], b.data[off+1], b.data[off+2], b.data[off+3]
}

func (b *Buffer) ConvertBGRAtoRGBA() {
	for y := 0; y < b.Height; y++ {
		rowOff := y * b.Stride
		for x := 0; x < b.Width; x++ {
			off := rowOff + x*4
			if off+3 >= len(b.data) {
				continue
			}
			b.data[off], b.data[off+2] = b.data[off+2], b.data[off]
		}
	}
}

func (b *Buffer) FlipVertical() {
	tmp := make([]byte, b.Stride)
	for y := 0; y < b.Height/2; y++ {
		topOff := y * b.Stride
		botOff := (b.Height - 1 - y) * b.Stride
		copy(tmp, b.data[topOff:topOff+b.Stride])
		copy(b.data[topOff:topOff+b.Stride], b.data[botOff:botOff+b.Stride])
		copy(b.data[botOff:botOff+b.Stride], tmp)
	}
}

func (b *Buffer) Clear() {
	for i := range b.data {
		b.data[i] = 0
	}
}

func (b *Buffer) CopyFrom(src *Buffer) {
	copy(b.data, src.data)
}

const (
	TransformNormal     = 0
	Transform90         = 1
	Transform180        = 2
	Transform270        = 3
	TransformFlipped    = 4
	TransformFlipped90  = 5
	TransformFlipped180 = 6
	TransformFlipped270 = 7
)

func (b *Buffer) ApplyTransform(transform int32) (*Buffer, error) {
	if transform == TransformNormal {
		return b, nil
	}

	var newW, newH int
	switch transform {
	case Transform90, Transform270, TransformFlipped90, TransformFlipped270:
		newW, newH = b.Height, b.Width
	default:
		newW, newH = b.Width, b.Height
	}

	newBuf, err := CreateBuffer(newW, newH, newW*4)
	if err != nil {
		return nil, err
	}
	newBuf.Format = b.Format

	srcData := b.data
	dstData := newBuf.data

	for sy := 0; sy < b.Height; sy++ {
		for sx := 0; sx < b.Width; sx++ {
			var dx, dy int

			switch transform {
			case Transform90: // 90° CCW
				dx = sy
				dy = b.Width - 1 - sx
			case Transform180:
				dx = b.Width - 1 - sx
				dy = b.Height - 1 - sy
			case Transform270: // 270° CCW = 90° CW
				dx = b.Height - 1 - sy
				dy = sx
			case TransformFlipped:
				dx = b.Width - 1 - sx
				dy = sy
			case TransformFlipped90:
				dx = sy
				dy = sx
			case TransformFlipped180:
				dx = sx
				dy = b.Height - 1 - sy
			case TransformFlipped270:
				dx = b.Height - 1 - sy
				dy = b.Width - 1 - sx
			default:
				dx, dy = sx, sy
			}

			si := sy*b.Stride + sx*4
			di := dy*newBuf.Stride + dx*4

			if si+3 < len(srcData) && di+3 < len(dstData) {
				dstData[di+0] = srcData[si+0]
				dstData[di+1] = srcData[si+1]
				dstData[di+2] = srcData[si+2]
				dstData[di+3] = srcData[si+3]
			}
		}
	}

	return newBuf, nil
}

func InverseTransform(transform int32) int32 {
	switch transform {
	case Transform90:
		return Transform270
	case Transform270:
		return Transform90
	case TransformFlipped90:
		return TransformFlipped270
	case TransformFlipped270:
		return TransformFlipped90
	default:
		return transform
	}
}
