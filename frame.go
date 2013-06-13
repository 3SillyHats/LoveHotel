package main

type Block struct {
	Id   uint
	Data uint
}

const ncx, ncy, ncz = 16, 16, 16

type chunk [ncx][ncy][ncz]Block

type pos struct {
	x, y, z int
}

type Frame struct {
	Transform SQT
	chunks    map[pos]chunk
}

func (f Frame) Block(x, y, z int) Block {
	p := pos{x / ncx, y / ncy, z / ncz}
	c := f.chunks[p]
	return c[x%ncx][y%ncy][z%ncz]
}

func (f Frame) SetBlock(x, y, z int, b Block) {
	p := pos{x / ncx, y / ncy, z / ncz}
	c := f.chunks[p]
	c[x%ncx][y%ncy][z%ncz] = b
	if b.IsEmpty() && c.IsEmpty() {
		delete(f.chunks, p)
	} else {
		f.chunks[p] = c
	}
}

func (b Block) IsEmpty() bool {
	return b.Id == 0
}

func (c chunk) IsEmpty() bool {
	for _, p := range c {
		for _, r := range p {
			for _, b := range r {
				if !b.IsEmpty() {
					return false
				}
			}
		}
	}
	return true
}
